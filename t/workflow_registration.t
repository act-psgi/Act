#!perl -w
use 5.020;
package main; # Make Devel::PerlySense happy
use warnings;

## Test environment
use Test::More 0.98;

use Test::Lib;
use Test::Act::Environment;

use Act::Store::Database;

my $testenv     = Test::Act::Environment->new;
my $smtp_server = $testenv->smtp_server;
my $base        = $testenv->base;
my $mech        = $testenv->mech;

my $conference = 'testing';
my $register_url = "$base/$conference/register";

my $attendee = {
    login       =>  'mur',
    first_name  =>  'Mustrum',
    last_name   =>  'Ridcully',
    email       =>  'archchancellor@example.com',
    country     =>  'am', # Ankh-Morpork, of course
    tshirt      =>  'XXXL',
};

# This is used for cleanup
my $numerical_user_id = '';

SKIP:
{
    # Step 0: Sanity
    {
        $mech->get_ok("$base/$conference",
                      "Testing conference is available at '$base/$conference'")
            or skip "*** Giving up: No access to the conference";
    }

    # Step 1: A new user requests registration
    {
        $mech->get_ok($register_url)
            or skip "*** Giving up: Can't access registration page";
        # Is that the correct page?
        # From: templates/user/twostep_add; assumes english
        my $title = $mech->title;
        is($title,"Confirmation required",
           "Registration page has the correct template")
            or skip "*** Giving up: unexpected template with title '$title'";
        # Check the form
        my @forms = $mech->forms;
        is(scalar @forms, 1,
           "Confirmation request has just one form")
            or skip "*** Giving up: Bad / customized confirmation template?";
        my $form = $forms[0];
        is($form->method,'POST',
           "Second step needs a POST request")
            and
            is ($form->action,$register_url,
                "Registration calls back to itself")
            or skip "*** Giving up: Bad registration confirmation form";
    }

    # Step 2: Submit the form to request the mail
    {
        $mech->submit_form_ok( { form_number => 1,
                                 fields => { email => $attendee->{email} },
                                 button => 'twostepsubmit',
                               },
                               "Registration code request accepted"
                             );
        # From: templates/user/twostep_add_ok
        is ($mech->title,'Confirmation email sent',
            "Confirmation email sent")
            or skip "*** Giving up: No confirmation email sent";
        $mech->content_like(qr/\b$attendee->{email}\b/,
                            "Attendee mail found in body");
    }

    # Step 3: Check the mailbox and extract the registration code,
    # which is carried over to the next step
    my $register_code_url;
    {
        my $mail = $smtp_server->next_mail();
        is($mail->{to}[0],$attendee->{email},
           "Attendee is mail recipient");
        my $mailtext = $mail->{message};
        ($register_code_url) = $mailtext =~ m!($register_url/\S+)!s;
        like($register_code_url,qr!/[0-9a-f]{32}$!,
             "Registration URL '$register_code_url' extracted")
            or skip "*** Giving up: Can't extract a registration code";
    }

    # Step 4: Visit the site again, using a fresh client to avoid
    # cookie / attribute memory.  The password is carried over to the
    # next step
    my $initial_password;
    {
        $mech = $testenv->build_mech;
        # Now use the registration code from the previous step
        $mech->get_ok($register_code_url,
                      "Register data form accessible")
            or skip "*** Giving up: Register form unavailable";

        # Step 8: We expect the form to enter information about the user
        $mech->title_is('Registration',
                        "Registration asks for user information");
        my ($user_form) = grep { $_->action eq $register_code_url }
            $mech->forms;
        ok($user_form,
           "Found a form to enter user input");
        $mech->post_ok($register_code_url,
                       { %$attendee,
                         join => 'Join!',
                        },
                       "Registration finished.  Or is it?")
            or skip "*** Giving up: Registration submission failed";

        $mech->title_is('Registered!',
                        "Registration is accepted")
            or skip "*** Giving up: Registration wasn't accepted";
        my $content = $mech->content;
        ($initial_password) = $content =~ m!Your password is <b>(\w+)</b>!;
        ok($initial_password,"We got a password: '$initial_password'")
               or skip "*** Giving up: No initial password";
        my $user_page = $mech->find_link
            ( text => "Logged as: $attendee->{login}");
        ok ($user_page,
            "Link to user page found");
        ($numerical_user_id) = $user_page->url =~ /(\d+)$/;
        ok($numerical_user_id,
           "Numerical user id available '$numerical_user_id'");
    }

    # Step 5: Unregister from the conference
    {
        $mech->get_ok("$base/$conference/unregister");
        $mech->title_is("Un-Registration",
                        "Unregister page loaded");
        $mech->submit_form_ok( { form_number => 1,
                                 button => 'leave',
                             },
                               'Clicked "unregister" button'
                           );
        $mech->title_is("Main private page",
                        "Unregistered drops to main private page");
        my $register_again = $mech->find_link
            ( text => "Register" );
        is($register_again->url_abs,$register_url,
           "Re-registration is available");
    }
    # Step 6: Log out
    {
        $mech->get_ok("$base/$conference/logout");
        $mech->title_is("Logout");
        $mech->content_like(qr/You have been logged out/);
    }

    # Tests for error handling

    # Bad registration code
    {
        $mech->get("$register_url/12345678901234567890123456789012");
        is($mech->status,404,
           "Error handling: Bad registration code -> status 404");
    }
    # Duplicate registration
    {
        $mech = $testenv->build_mech;
        $mech->get_ok($register_url,
                      'Error handling: Start registering yet again');
        $mech->submit_form_ok( { form_number => 1,
                                 fields => { email => $attendee->{email} },
                                 button => 'twostepsubmit',
                               },
                               "Error handling: Fetch registration code"
                             );
        my $mail = $smtp_server->next_mail();
        my $mailtext = $mail->{message};
        my ($register_code_url) = $mailtext =~ m!($register_url/\S+)!s;
        like($register_code_url,qr!/[0-9a-f]{32}$!,
             "Error handling: Evaluate registration code");
        $mech->post_ok($register_code_url,
                       { %$attendee,
                         login => 'archchancellor', # name conflict only
                         join => 'Join!',
                        },
                       "Error handling: Registration finished.  Or is it?");
        $mech->title_is("Registration",
                        "Error handling: Duplicate registration rejected");
        $mech->content_like(qr/Accounts with similar information already exist\./,
                        "Error handling: Appropriate message found");
    }
}

done_testing;


CLEANUP: {
    my $schema = Act::Store::Database->instance->schema;
    my $users = $schema->resultset('User');
    eval {
        $users->find( { login => $attendee->{login} } )->delete;
    };
}
