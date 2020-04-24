# ABSTRACT: One named price option
use 5.24.0;
package Act::Conference::Product::Price;

use Moo;
with 'Act::Conference::Label';

use Types::Standard qw(InstanceOf Num Str);
use namespace::clean;

use feature qw(signatures);
no warnings qw(experimental::signatures);

has amount => (
    is => 'ro', isa => Num,
);

has promocode => (
    is => 'ro', isa => Str,
);

########################################################################

sub from_config ($class,$config,$id) {
    $class->new(
        name => label_from_config($config,$id . '_name'),
        amount => $config->get($id . '_amount'),
        ($config->_exists($id . '_promocode') ?
             (promocode => $config->get($id . '_promocode')) :
             ()
         ),
    );
}
1;

__END__

=encoding utf8

=head1 NAME

Act::Conference::Product::Price - One named price option

=head1 SYNOPSIS

  use Act::Conference::Product::Price;
  Act::Conference::Product::Price->from_config($config,'registration_price1');

=head1 DESCRIPTION

This class describes one price option for a product sold by organisers
of an Act conference.

=head2 Attributes for constructing a product with C<new>

=head3 C<name>

A hash reference mapping language ids to the product's name in that
language

=head3 C<amount>

The actual price (currency is provided elsewhere, for all prices)

=head3 C<promocode>

A string which needs to be provided by customers who want to select
this price option.

=head2 Class method C<from_config($class,$config,$price_id)>

This method returns a C<$class> object from an Act configuration
$config for the price option internal name C<$price_id>.

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
