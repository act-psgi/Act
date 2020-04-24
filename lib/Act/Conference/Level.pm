# ABSTRACT: A level of target audience for an Act conference
use 5.24.0;
package Act::Conference::Level;

use Moo;
with 'Act::Conference::Label';

use Types::Standard qw(Str);
use namespace::clean;

use feature qw(signatures);
no warnings qw(experimental::signatures);

########################################################################

sub from_config ($class,$config,$index) {
    my $id = 'levels_level' . $index . '_name';
    $class->new(name => label_from_config($config,$id));
}

1;

__END__

=encoding utf8

=head1 NAME

Act::Conference::Level - A level of target audience for an Act conference

=head1 DESCRIPTION

This class consists of multilingual names for the different levels of
the target audience.

=head2 Class method C<< $class->from_config($config,$index) >>

This method returns a C<$class> object from an Act configuration
$config, where the entries for different levels are named
like C<'levels_level' . $index . '_name'>.

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
