#!perl -w
package main; # Make Devel::PerlySense happy

## Test environment
use Test::More 0.98 tests => 20;
use Digest::MD5;

use Test::Lib;
use Test::Act::UserCrypto;

use utf8; # for our test passwords

## Test preparations ---------------------------------------------------
# Some test data
my %passwords = (
    ascii     => 'Only_ASCII_characters',
    iso_latin => 'Âccénted_chäràacters',
    unicode   => '€_₤_£',
);

# Load the module to be tested for the methods
use Act::User;
# ...and load the mock object
use Test::Act::UserCrypto;

## Tests start here ----------------------------------------------------
# Part 1: Using the current password encryption
my $user = Test::Act::UserCrypto->new;
while (my ($type,$password) = each %passwords) {
    $user->set_password($password);
    my $crypted = $user->passwd;
    like($crypted,qr/^\Q{CRYPT}\E/,
         "$type Password encryption is CRYPT-based");
    $user->set_password($password);
    isnt($user->passwd,$crypted,
         "$type Encryption is properly salted");
    ok($user->check_password($password),"$type Password is fine");
    eval { $user->check_password('bad password'); };
    like($@,qr'^Bad password',
       "$type Bad password is rejected");
}

# Part 2: Using MD5 hashes.  Wide characters weren't supported
# back then.
for my $type (qw(ascii iso_latin)) {
    my $password = $passwords{$type};
    my $digest = Digest::MD5->new;
    $digest->add($password);
    my $crypted = $digest->b64digest;
    $user->passwd($crypted);
    ok($user->check_password($password),
       "Legacy $type Password is fine");
    eval { $user->check_password('bad password'); };
    like($@,qr'^Bad password',
       "Legacy $type Bad password is rejected");
    $crypted = $user->passwd;
    like($crypted,qr/^\Q{CRYPT}\E/,
         "Legacy $type Password encryption upgraded");
    ok($user->check_password($password),
       "Legacy $type Password is fine after upgrade");
}
