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

my $new_conference = 'Toastconference';
my $new_id         = 'toasting';

# Step 1: Fetch and examine the homepage, verify that the new
# conference isn't available right now.
{
    $mech->get_ok("$base/$conference/");
    $mech->content_lacks($new_conference,
                         "The new conference isn't visible yet");

    $mech->get("$base/$new_id/");
    is($mech->status, 404,
       "The new conference's page returns 404");
}

# Step 2: Add the conference in the global act.ini, and provide a
# conference act.ini (untested, done using the test environment)
{
    $testenv->add_conference($new_id,$new_conference);
}


# Step 3: Now the old conference should present a link to the new one
# (thanks to the act_confs template), and the new conference should be
# available.
{
    $mech->get_ok("$base/$conference/");
    $mech->content_contains($new_conference,
                            "A request after adding it shows the conference");
    $mech->get_ok("$base/$new_id/");
}

done_testing;
