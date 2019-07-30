# ABSTRACT: Collect user credentials and have them checked
package Act::Handler::User::CheckLogin;
use strict;

use Authen::Passphrase::BlowfishCrypt;
use Authen::Passphrase;
use Digest::SHA qw(sha512);
use Digest::MD5 qw(md5_hex);
use Encode qw(encode);
use Plack::Request;
use Plack::Response;
use Try::Tiny;

use parent 'Act::Handler';
use Act::User::Authenticate;
use Act::Store::Database;

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

        my $db = Act::Store::Database->instance;
        my $pw_hash = $db->get_user_password($login)
            or die ["Unknown user"];
        try {
            check_password($login,$sent_pw,$pw_hash);
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


sub set_password {
    my ($login,$password) = @_;
    my $db = Act::Store::Database->instance;
    $db->set_user_password(_crypt_password($login,$password));
    return 1;
}

sub check_password {
    my ($login,$sent_pw,$pw_hash) = @_;

    my $ppr = eval { Authen::Passphrase->from_rfc2307($pw_hash); };
    return 1 if $ppr && $ppr->match(_sha_pass($sent_pw));
    return 1 if _check_legacy_password($login,$sent_pw,$pw_hash);
    die 'Bad password';
}


sub _sha_pass {
    my ($pass) = @_;
    return sha512(encode('UTF-8',$pass,Encode::FB_CROAK));
}

sub _check_legacy_password {
    my ($login,$check_pass,$pw_hash) = @_;
    my ($scheme, $hash) = $pw_hash =~ /^(?:{(\w+)})?(.*)$/;

    if (!$scheme || $scheme eq 'MD5') {
        my $ok = try {
            my $digest = Digest::MD5->new;
            $digest->add($check_pass); # this dies from wide characters
            $digest->b64digest eq $hash;
        } catch {
            0; # a failed digest can be safely mapped to "bad password"
        };
        $ok && set_password($login,$check_pass); # upgrade hash
        return $ok;
    }
    return 0;
}


1;

__END__

=encoding utf8

=head1 NAME

Act::Handler::User::Authenticate -  Collect user credentials and have them checked

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

