# ABSTRACT: Data about user registration for an Act conference
use 5.24.0;
package Act::Conference::Registration;

use Moo;
use Types::Standard qw(Bool Int);
use namespace::clean;

use feature qw(signatures);
no warnings qw(experimental::signatures);

has open => (
    is => 'ro', isa => Bool,
);

has max_attendees => (
    is => 'ro', isa => Int,
);

has gratis => (
    is => 'ro', isa => Bool,
);

########################################################################

sub from_config ($class,$config) {
    $class->new(
        open   => !!($config->registration_open),
        gratis => !!($config->registration_gratis),
        ($config->registration_max_attendees ?
             (max_attendees => $config->registration_max_attendees) :
             ()
        ),
    )
}

1;

__END__

=encoding utf8

=head1 NAME

Act::Conference::Registration - Data about user registration

=head1 SYNOPSIS

  use Act::Conference::Registration;
  $registration = Act::Conference::Registration->from_config($config);

=head1 DESCRIPTION

This class contains metadata about user registration.

=head2 Attributes for constructing with C<new>

Attributes are passed as a hash with attribute names as keys.

=head3 C<open>

A boolean indicating whether users can register for the conference.

=head3 C<max_attendees>

An integer defining the maximum number of permitted attendees.
Leave undefined for unlimited access.

=head3 C<gratis>

A boolean indicating whether the conference is free of charge.

=head2 Class method C<< $class->from_config($config) >>

Returns a C<$class> object containing the registration data from the
Act configuration given in C<$config>.

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
