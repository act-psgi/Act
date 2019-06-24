# ABSTRACT: Helper module to test crypto methods in Act::User
package Test::Act::UserCrypto;

use Moo;
use Types::Standard qw(Str);

has passwd => (
    is => 'rw', isa => Str,
    documentation =>
        'The encrypted password stored for the user',
);

# ----------------------------------------------------------------------

=head2 Method update

Mocks Act::Object::update so that we can examine the results without
storing them in the database.

=cut

sub update {
    my $self = shift;
    my %params = @_;
    $params{passwd}  &&  $self->passwd($params{passwd});
}

=head2 Methods delegeated to Act::User

The password handling methods set_password, check_password,
_crypt_password, _sha_pass, and _check_legacy_password are our methods
under test and therefore directly delegated to L<Act::User>.

=cut

sub set_password           { Act::User::set_password(@_) };
sub check_password         { Act::User::check_password(@_) };
sub _crypt_password        { Act::User::_crypt_password(@_) }
sub _sha_pass              { Act::User::_sha_pass(@_) }
sub _check_legacy_password { Act::User::_check_legacy_password(@_) }

1;
__END__

=head1 NAME

Test::Act::UserCrypto - Unit tests for password encryption

=head1 SYNOPSIS

   my $user = Test::Act::UserCrypto->new;
   $user->set_password('123456');
   ok($user->check_password('123456'),'good password');

=head1 DESCRIPTION

This module mocks L<Act::User> but avoids its parent L<Act::Object>
because that requires too much overhead (e.g. database tables).  I
consider this totally irrelevant for testing password encryption
including legacy handling.

=head2 AUTHOR

Harald Joerg, <haj@posteo.de>
