# ABSTRACT: Collect user credentials and have them checked
package Act::Handler::User::CheckLogin;
use strict;

use Plack::Request;
use Plack::Response;
use Try::Tiny;

use parent 'Act::Handler';
use Act::Store::Database;
use Act::Auth::Password;

use Plack::Session;

sub handler {
    my ($env) = @_;
    my $request = Plack::Request->new($env);

    my $parameters  = $request->parameters;
    my $login       = $parameters->{credential_0};
    my $sent_pw     = $parameters->{credential_1};
    my $remember_me = $parameters->{credential_2};
    my $destination = $parameters->{destination};

    for ($login,$sent_pw) {
        s/^\s*//; s/\s*$//; # kill surrounding spaces
    }

    my $continue = try {
        # login and password must be provided
        $login
            or die ["No login name"];
        $sent_pw
            or die ["No password"];

        try {
            Act::Auth::Password->check_password($login,$sent_pw);
        }
            catch {
                die ["Bad password. (Error: $_)"];
            };

        # user is authenticated - create a session
        my $user = Act::User->new( login => lc $login );
        my $session = Plack::Session->new($env);
        $session->set(login => lc $login);

        my $resp = Plack::Response->new;
        $resp->redirect($destination);
        $resp->finalize;
    }
    catch {
        my $error = ref $_ eq 'ARRAY' ? $_->[0] : $_;
        my $full_error = join ' ', map { "[$_]" }
            $env->{HTTP_HOST},
            $request->address,
            $login,
            $error;

        $request->logger->({ level => 'error', message => $full_error });
        $env->{'act.login.destination'} = $destination;
        $env->{'act.login.error'} = 1;
        0;
    };
    return $continue || Act::Handler::Login->new->call($env);
}

1;

__END__

=encoding utf8

=head1 NAME

Act::Handler::User::CheckLogin -  Collect user credentials and have them checked

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 DIAGNOSTICS

=head1 EXAMPLES

=head1 ENVIRONMENT

=head1 FILES

=head1 CAVEATS

=head1 BUGS

=head1 RESTRICTIONS

=head1 NOTES

=head1 AUTHOR

Harald Jörg, haj@posteo.de

=head1 COPYRIGHT AND LICENSE

Copyright 2019 Harald Jörg

This library is free software; you may redistribute it and/or
modify it under the same terms as Perl itself.

