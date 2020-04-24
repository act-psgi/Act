# ABSTRACT: One room for an Act conference
use 5.24.0;
package Act::Conference::Room;

use Moo;
with 'Act::Conference::Label';

use Types::Standard qw(Str);
use namespace::clean;

use feature qw(signatures);
no warnings qw(experimental::signatures);

########################################################################

sub from_config ($class,$config,$id) {
    $class->new(name => $config->rooms_names->{$id} )
}
1;

__END__

=encoding utf8

=head1 NAME

Act::Conference::Room - One room for an Act conference

=head1 SYNOPSIS

  use Act::Conference::Room;
  $registration = Act::Conference::Room($config);

=head1 DESCRIPTION

This class consists of multilingual names for the conference rooms.

=head2 Class method C<< $class->from_config($config,$id) >>

This method returns a C<$class> object from an Act configuration,
where entries are from L<Act::Config>'s C<rooms_names> hash.

=head1 CAVEATS

The method C<from_config> does not read "raw" values from a config
file.  Instead, it relies on L<Act::Config> to convert the list of
rooms and their names into a hash.

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
