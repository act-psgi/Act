# ABSTRACT: A representation of a conference hosted in Act
use 5.24.0;
use strict;
use warnings;
package Act::Conference;

use Moo;
with 'Act::Conference::Label';

use URI;
use Template;

use Act::Conference::Level;
use Act::Conference::Product;
use Act::Conference::Registration;
use Act::Conference::Room;
use Act::Conference::Talks;
use Act::Config;                    # for fetching the config object
use Act::Language;                  # for validating "known" languages
use Act::Payment;                   # for get_prices
use Act::Util;

# ----- Types ----------------------------------------------------------
use Types::Standard qw(ArrayRef Bool HashRef InstanceOf Int Str);
use namespace::clean;

# Just for showing off: Use custom types for language and country code
use Type::Tiny;
my $language_code = Type::Tiny->new(
    name => 'LanguageCode',
    parent => Types::Standard::Str,
    constraint => sub { Act::Language::name($_) },
    message    => sub {
        "'$_' is no two-letter language code. See ISO 639-1.\n"
    },
);

my $country_code = Type::Tiny->new(
    name => 'CountryCode',
    parent => Types::Standard::Str,
    constraint => sub { length == 2 },
    message    => sub {
        "'$_' is no two-letter country code. See ISO 3166-1.\n"
    },
);

use feature qw(signatures);
no warnings qw(experimental::signatures);

# ----- Attributes -----------------------------------------------------
# The conference name is available via the  Act::Conference::Label role

has full_uri => (
    is => 'ro', isa => InstanceOf['URI'],
    coerce => sub { return URI->new(@_); },
);

has languages => (
    is => 'ro', isa => ArrayRef[Str],
);

has language_variants => (
    is => 'ro', isa => ArrayRef[Str],
    default => sub { [] }
);

has default_language => (
    is => 'ro', isa => $language_code,
    message => 'bad',
);

has default_country => (
    is => 'ro', isa => $country_code,
);

has timezone => (
    is => 'ro', isa => Str,
);

has talks => (
    is => 'ro', isa => InstanceOf['Act::Conference::Talks'],
);

has rooms => (
    is => 'ro', isa => HashRef[InstanceOf['Act::Conference::Room']],
);

has email_sender_address => (
    is => 'ro', isa => Str,
);


has products => (
    is => 'ro', isa => HashRef[InstanceOf['Act::Conference::Product']],
);

has payment_open => (
    is => 'ro', isa => Bool,
);

has payment_type => (
    is => 'ro', isa => Str,
);

has payment_currency => (
    is => 'ro', isa => Str,
);


########################################################################

sub from_config ($class,$config) {
    my @languages         = sort keys %{$config->languages};
    my @language_variants = sort keys %{$config->language_variants};

    my %rooms             = map {
        $_ => Act::Conference::Room->from_config($config,$_)
    } keys %{$config->rooms_names};

    my %products = map {
        $_ => Act::Conference::Product->from_config($config,'product_' . $_)
    } split /\s+/, $config->payment_products;

    my $conference = $class->new(
        name              => label_from_config($config,'general_name'),
        full_uri          => $config->general_full_uri,
        default_language  => $config->general_default_language,
        languages         => \@languages,
        language_variants => \@language_variants,
        default_country   => $config->general_default_country,
        timezone          => $config->general_timezone,
        searchlimit       => $config->general_searchlimit,
        rooms             => \%rooms,
        products          => \%products,
        payment_type      => $config->payment_type,
        payment_currency  => $config->payment_currency,
        registration      => Act::Conference::Registration->from_config($config),
        email_sender_address => $config->email_sender_address,
        talks             => Act::Conference::Talks->from_config($config),
    );
}


sub write_config ($self,$path) {
    my $tt = Template->new({
        ENCODING     => 'UTF-8',
        INCLUDE_PATH => $Config->home . '/templates'
    });
    $tt->process('conference_ini.tt',{ conference => $self}, $path)
        or die $tt->error;
}
1;

__END__

=encoding utf8

=head1 NAME

Act::Conference - A representation of a conference hosted in Act

=head1 SYNOPSIS

=head1 DESCRIPTION

A conference in Act combines data from its configuration file (date,
status of registration and submission, rooms, prices) with data from
the database (attendees, talks) and web content from the file system
(templates and "static" files).

This class combines these data.

=head2 Attributes for constructing a conference with C<new>

Attributes are passed as a hash with attribute names as keys.

=head3 C<name>

A hash reference where language identifiers are keys, and the
conference's names are values.  See L<Act::Conference::Label>.

=head3 C<full_uri>

The absolute URI under which this conference should be served.  Act is
using this for linking to "other conferences".  Links within pages for
this conference are (or should be) relative.

=head3 C<languages>

The languages supported in the web presentationfo the conference.

=head3 C<language_variants>

Language variants like C<en_US> are permitted here.

=head3 C<default_language>

A two-letter language code from
L<ISO 639-1|https://en.wikipedia.org/wiki/List_of_ISO_639-1_codes>.

=head3 C<default_country>

A two-letter country code from
L<ISO 3166-1|https://en.wikipedia.org/wiki/ISO_3166-1>.
This country is selected as a default when a new user registers.  The
value is not used by the code, just by a - customizable - template.

=head3 C<timezone>

The timezone for this conference from the TZ database, e.g. 'Europe/Paris'.

=head3 C<searchlimit>

Number of items in paged search.  The default is usually set by providers,
adjust to your template if desired.

=head3 C<registration>

An L<Act::Conference::Registration> object containing registration properties
for this conference.

=head3 C<talks>

An L<Act::Conference::Talks> object containing talks properties
for this conference.

=head3 C<levels>

An array reference of audience target levels with their multi-lingual
labels (see L<Act::Conference::Level>).

=head3 C<rooms>

A hash reference of conference rooms: Keys are the internal identifieers, values are their multi-lingual labels (see L<Act::Conference::Room>).

=head3 C<email_sender_address>

The address to be used by Act when sending mails on behalf of the
conference.

=head3 C<products>

A hash reference of L<Act::Conference::Product> objects with their
identifiers as keys.

=head3 C<payment_open>

Whether the payment system is available.

=head3 C<payment_type>

The method used to pay for this conference.  Must be supported by the
provider.

=head3 C<payment_currency>

The three-letter code of the currency for prices of this conference.

=head2 Class Method c<from_config($config)>

Returns a new Act::Conference object created from a conference
configuration.

=head2 Object method c<write_config($path)>

Writes a conference configuration file to the specified path.  Handles
and scalar references are also accepted (as by L<Template>).

=head1 DIAGNOSTICS

If you construct a conference with invalid attributes, the C<new>
method might die.  This is done using Moo validation with some custom
types.  Yes, most probably that's over-engineering, but I (haj) just
wanted to try that stuff here.  My apologies.

=head1 ENVIRONMENT

The template for writing configuration files is located relative to
C<< $Config->home >>, which in defined by the environment variable
C<ACT_HOME>.

=head1 FILES

=over

=item F<templates/conference_ini.tt>

The template for writing a conference F<act.ini>.

=back

=head1 CAVEATS

The C<from_config> class method does not (yet) read a raw
configuration file.  Insteadl it uses a conference slot from Act's
global configuration.  This configuration contains the global config
items set by the provider, which isn't bad inasmuch they can serve as
defaults for conferences, but it also munges some configuration items
from the file's "flat" entries into hashes.

This is supposed to change in the future, so that the method operates
on config files and does the data munging itself.

=head1 NOTES

The "payments" section should go to a separate object.  This is
postponed until the author understands the payment mechanisms.  He will
probably drop all those which are no longer supported.

=head1 AUTHOR

Harald Jörg, haj@posteo.de

=head1 COPYRIGHT AND LICENSE

Copyright 2020 Harald Jörg

This library is free software; you may redistribute it and/or
modify it under the same terms as Perl itself.
