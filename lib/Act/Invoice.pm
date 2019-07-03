package Act::Invoice;
use strict;
use Carp qw(croak);
use Act::Config;
use Act::Object;
use base qw( Act::Object );

# class data used by Act::Object
our $table       = 'invoices';
our $primary_key = 'invoice_id';

our %sql_stub    = (
    select => "i.*",
    from   => "invoices i",
);
our %sql_mapping = (
    # standard stuff
    map( { ($_, "(i.$_=?)") }
         qw( order_id invoice_id ) )
);
our %sql_opts;

sub create {
    my ($class, %args ) = @_;

    $args{datetime} = DateTime->now();

    # get next invoice number for this conference
    $args{invoice_no} = Act::Data::next_invoice_num($Request{conference});
    return $class->SUPER::create(%args);
}
sub update {
    croak "invoices can't be updated";
}

=head1 NAME

Act::Invoice - An Act object representing an invoice.

=head1 DESCRIPTION

This is a standard Act::Object class. See Act::Object for details.

=cut

1;
