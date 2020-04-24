# ABSTRACT: One product for a conference which can be purchased
use 5.24.0;
package Act::Conference::Product;

use Moo;
with 'Act::Conference::Label';

use Types::Standard qw(ArrayRef InstanceOf Str);
use namespace::clean;

use feature qw(signatures);
no warnings qw(experimental::signatures);

use Act::Conference::Product::Price;

has prices => (
    is => 'ro', isa => ArrayRef[InstanceOf['Act::Conference::Product::Price']],
);

########################################################################

sub from_config ($class,$config,$product_id) {
    my $n_prices = $config->get($product_id . '_prices');
    my @prices = map {
        my $price_id = $product_id . '_price' . $_;
        Act::Conference::Product::Price->from_config($config,$price_id);
    } (1..$n_prices);
    $class->new(
        name   => label_from_config($config,$product_id . '_name'),
        prices => \@prices,
    );
}

1;

__END__

=encoding utf8

=head1 NAME

Act::Conference::Product - One product for a conference

=head1 SYNOPSIS

  use Act::Conference::Product;
  Act::Conference::Product->from_config($config,'registration');

=head1 DESCRIPTION

This class describes one product sold by organisers of an Act
conference.

=head2 Attributes for constructing a product with C<new>

=head3 C<name>

A hash reference mapping language ids to the product's name in that
language

=head3 C<prices>

An array reference of Act::Conference::Product::Price objects, each
describing one price option for the product.

=head2 Class method C<from_config($class,$config,$product_id)>

This method returns a C<$class> object from an Act configuration
$config for the product with an internal name C<$product_id>.

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
