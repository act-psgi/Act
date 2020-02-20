#!perl -w
use 5.020;
package main; # Make Devel::PerlySense happy
use warnings;

## Test environment
use Test::More 0.98;

use Test::Lib;
use Test::Act::Environment;

my $testenv     = Test::Act::Environment->new;
my $smtp_server = $testenv->smtp_server;
my $base        = $testenv->base;
my $mech        = $testenv->new_mech;

# Test whether changes in config files will take effect on the next
# request

# These come with the test fixture
my $conference      = 'testing';
my $conference_name = 'Testconference';

sub _url {
    return "$base/$conference/$_[0]";
}

my $new_conference = 'Toastconference';

# Step 1: Fetch the conference home page
{
    my $url = _url("");

    $mech->get($url);
    $mech->content_lacks($new_conference,
                         "The new conference isn't visible yet");

    $testenv->add_conference("toasting",$new_conference);

    $mech->get($url);
    $mech->content_contains($new_conference,
                            "A request after adding it shows the conference");
}

done_testing;
