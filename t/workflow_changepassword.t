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

use Act::Store::Database;

my $attendee = {
    login       =>  'pos',
    first_name  =>  'Ponder',
    last_name   =>  'Stibbons',
    email       =>  'pos@example.com',
    country     =>  'am', # Ankh-Morpork, of course
    tshirt      =>  'S',
};

# This is used for cleanup
my $numerical_user_id = '';

sub _url {
    my $conference = 'testing';
    return "$base/$conference/$_[0]";
}

SKIP:
{
    # Step 1: Preparation - register user
    my $initial_password;
    {
        # Preparations - register user
        my $register_url = _url("register");
        $mech->post($register_url,{ email => $attendee->{email},
                                    twostepsubmit => 1,
                                } );
        is ($mech->title,'Confirmation email sent',
            "Confirmation email sent")
            or skip "*** Giving up: No confirmation email sent";
        my $register_code_url;
        my $mail = $smtp_server->next_mail();
        my $mailtext = $mail->{message};
        ($register_code_url) = $mailtext =~ m!($register_url/\S+)!s;
        like($register_code_url,qr!/[0-9a-f]{32}$!,
             "Registration URL '$register_code_url' extracted")
            or skip "*** Giving up: Can't extract a registration code";

        $mech->post($register_code_url,
                    { %$attendee,
                      join => 'Join!',
                     });
        my $content = $mech->content;
        ($initial_password) = $content =~ m!Your password is <b>(\w+)</b>!;
        ok($initial_password,"We got a password: '$initial_password'")
               or skip "*** Giving up: No initial password";
        my $user_page = $mech->find_link
            ( text => "Logged as: $attendee->{login}");
        ($numerical_user_id) = $user_page->url =~ /(\d+)$/;
        ok($numerical_user_id,
           "Numerical user id available '$numerical_user_id'");
    }

    # Step 2: Change the initial password
    {
        $mech->get_ok(_url("changepwd"));
        my $pw_form = $mech->form_with_fields(
            qw(oldpassword newpassword1 newpassword2));
        ok($pw_form,
           "Found the form to change the password");
        my $new_password = $attendee->{login} x 2;
        $mech->set_fields(
            oldpassword  => $initial_password,
            newpassword1 => $new_password,
            newpassword2 => $new_password,
        );
        $mech->click('ok');
        is($mech->uri,_url("main"),
           "Successful password change redirects to main");
        $mech->title_is('Main private page',
                        "Template 'main' is used");
    }

    # Step 3: Error handling: Wrong old password, bad new password
    {
        $mech->post_ok(_url("changepwd"),
                       { oldpassword  => 'oldpassword', # actually, no
                         newpassword1 => 'newpassword1',
                         newpassword2 => 'newpassword2',
                         ok           => 1,
                       },
                       "Error handling: Form with bad old password submitted"
                      );
        $mech->title_is("Change Password");
        $mech->content_like(qr"Incorrect login or password");
        $mech->post_ok(_url("changepwd"),
                       { oldpassword  => $attendee->{login} x 2,
                         newpassword1 => 'newpassword1',
                         newpassword2 => 'newpassword2',
                         ok           => 1,
                       },
                       "Error handling: New passwords don't match"
                      );
        $mech->title_is("Change Password");
        $mech->content_like(qr"Passwords don't match");
    }

    # Step 4: Forgot the password!  Start unauthenticated
    {
        my $url = _url("changepwd");
        $mech = $testenv->new_mech;
        $mech->get(_url("main"));
        ok($mech->find_link( url_abs => $url),
           "Link to password recovery found");
        $mech->get_ok($url);
        $mech->title_is("Reset Password",
                        "twostep_change_password template processed");
        $mech->post_ok($url,
                       { login         => $attendee->{login},
                         twostepsubmit => "Reset password",
                       },
                   );
        $mech->content_like(qr/An email has been sent to you/,
                            "We may expect a mail");

        my $mail = $smtp_server->next_mail;
        ok($mail,"Mail received!");
        my ($reset_url) = $mail->{message} =~ m!($url/[0-9a-f]+)!;
        like($reset_url,qr!\Q$url\E/[0-9a-f]{32}$!,
             "Registration code found");

        $mech->get_ok($reset_url);
        $mech->title_is('Change Password',
                        "Password change template processed");
        $mech->post_ok($reset_url,
                       { newpassword1 => $attendee->{login} x 2,
                         newpassword2 => $attendee->{login} x 2,
                         ok           => 'Change Password',
                       }
                   );
    }

    # Step 4: Unregister from the conference
    {
        $mech->get(_url("unregister"));
        $mech->submit_form_ok( { form_number => 1,
                                 button => 'leave',
                             },
                               'Unregistered from the conference'
                           );
        is($mech->uri,_url("main"),
           "Successful password reset redirects to main");
        $mech->title_is('Main private page',
                        "Template 'main' is used");
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
