# ABSTRACT: Multilingual names for conference items
use 5.24.0;
package Act::Conference::Label;

use Moo::Role;
use strictures 2;
use Types::Standard qw(HashRef Str);
use namespace::clean;

use feature qw(signatures);
no warnings qw(experimental::signatures);

has name => (
    is => 'ro', isa => HashRef[Str],
    default => sub { { } },
);

########################################################################

sub label_from_config ($config,$item) {
    my %texts = map {
        my $localized = $item . '_' . $_;  # e.g. name_de
        $config->_exists($localized) ? ($_ => $config->$localized) : ()
    } keys %{$config->languages};
    return \%texts;
}

1;

__END__

=encoding utf8

=head1 NAME

Act::Conference::Label - Multilingual names for conference items

=head1 SYNOPSIS

  package Act::MyClass;
  use Moo;
  with 'Act::Conference::Label';

=head1 DESCRIPTION

This role provides an Act conference item with a multilingual name.
Traditionally, these are read from the conference's F<act.ini>,
and there's a static sub to convert configuation entries to labels.

=head2 Attributes for constructing classes which consume this role

=head3 C<name>

A hash reference where language identifiers are keys, and the
item's names are values.

=head2 Static subroutine C<label_from_config($config,$item>)

Returns a hashref which can be passed to the constructor of a class
which consumes this role.

=head1 CAVEATS

The C<from_config> sub will most likely be converted into a class
method, so that classes consuming this role can override it.

=head1 AUTHOR

Harald Jörg, haj@posteo.de

=head1 LICENSE AND COPYRIGHT

Copyright 2020 Harald Jörg. All rights reserved.

This library is free software; you may redistribute it and/or
modify it under the same terms as Perl itself.
See L<perlartistic>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
