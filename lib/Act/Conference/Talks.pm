# ABSTRACT: Metadata for Act::Conference talks
use 5.24.0;
package Act::Conference::Talks;

use Moo;
use Types::Standard qw(ArrayRef Bool HashRef InstanceOf Int Maybe Str);
use namespace::clean;

use Act::Conference::Level;

use feature qw(signatures);
no warnings qw(experimental::signatures);

has submissions_open => (
    is => 'ro', isa => Bool,
);

has edition_open => (
    is => 'ro', isa => Bool,
);

has notify_accept => (
    is => 'ro', isa => Bool,
);

has ['start_date', 'end_date'] => (
    is => 'ro', isa => Str,
);

has durations => (
    is => 'ro', isa => HashRef[Bool],
);

has submissions_notify_address => (
    is => 'ro', isa => Str,
);

has submission_notify_language => (
    is => 'ro', isa => Str,
);

has ['show_schedule', 'show_all'] => (
    is => 'ro', isa => Bool,
);

has schedule_default => (
    is => 'ro', isa => Maybe[Str],
);

has languages => (
    is => 'ro', isa => HashRef[Str],
);

has levels => (
    is => 'ro', isa => ArrayRef[InstanceOf['Act::Conference::Level']],
);

########################################################################

sub from_config ($class,$config) {
    my @simple_attrs = qw/submissions_open edition_open
                          start_date      end_date
                          durations
                          submissions_notify_address
                          submissions_notify_language
                          notify_accept
                          show_schedule   show_all
                          schedule_default
                          languages
                         /;
    my %simple_attrs = map {
        $_ => $config->get("talks_$_")
    } @simple_attrs;

    my @levels = map {
        Act::Conference::Level->from_config($config,$_)
    }  (1 .. $config->talks_levels);

    $class->new(
        %simple_attrs,
        levels => \@levels,
    );
}


1;

__END__

=encoding utf8

=head1 NAME

Act::Conference::Talks -  Metadata for Act::Conference talks

=head1 SYNOPSIS

  use Act::Conference::Talks;
  $talks = Act::Conference::Talks->from_config($config);

=head1 DESCRIPTION

This class holds metadata about conference talks.

=head2 Attributes for constructing with C<new>

Attributes are passed as a hash with attribute names as keys.

=head3 C<submissions_open>

A boolean indicating whether new talks can be submitted.

=head3 C<edition_open>

A boolean indicating whether authors can edit their talks.

=head3 C<notify_accept>

A boolean indicating whether authors receive a mail when their talk is
accepted.

=head3 C<start_date> and C<end_date>

Parseable strings when the talk schedule begins and ends.  By
tradition, the format is C<YYYY-MM-DD HH:MM:SS>, so sort-of
ISO8601-ish without the C<T> separator between date and time.

=head3 C<durations>

A hash reference mapping valid durations (timeslots) for regular
talks, given in minutes, to 1.

=head3 C<submission_notify_address>

Mail address which will receive a message when a new talk is
submitted.

=head3 C<submission_notify_language>

The language used for messages about new talks.

=head3 C<show_schedule> and C<show_all>

Two booleans indicating whether the talk schedule is shown, and
whether also talks whoch aren't yet accepted are included.

=head3 C<schedule_default>

A default date for talk scheduling.  Used only in a template.

=head3 C<languages>

A hash reference of languages permitted for talks. It maps 2-char
language ids to their full names.

=head3 C<levels>

An array reference of L<Act::Conference::Level> objects, naming
different levels of target audience.

=head2 Class method C<< $class->from_config($config) >>

Returns a C<$class> object containing the talks data from the
Act configuration given in C<$config>.

=head1 CAVEATS

Some of the data are used after they've been munged by L<Act::Config>.

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
