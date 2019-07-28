package Act::Middleware::Auth;
use strict;
use warnings;

use parent qw(Plack::Middleware);
use Plack::Request;
use Try::Tiny;
use Plack::Util::Accessor qw(private);
use Encode qw(decode);

sub call {
    my $self = shift;
    my $env = shift;

    my $req = Plack::Request->new($env);

    my $session_id = $req->cookies->{'Act_session_id'};

    $env->{'act.auth.login'} = \&_login;
    $env->{'act.auth.logout'} = \&_logout;
    $env->{'act.auth.set_session'} = \&_set_session;

    my $user;
    if(defined $session_id) {
        $user = Act::User->new( session_id => $session_id );
    }

    if ($user) {
        $env->{'act.user'} = $user;
    }
    elsif ($self->private) {
        $env->{'act.login.destination'} = $env->{REQUEST_URI};
        return Act::Handler::Login->new->call($env);
    }
    $self->app->($env);
}

sub _login {
    my $resp = shift;
    my $user = shift;
    my $sid = Act::Util::create_session($user);
    $resp->cookies->{'Act_session_id'} = {
        value => $sid,
        path => '/',
    };
}
sub _logout {
    my $resp = shift;
    $resp->cookies->{'Act_session_id'} = {
        value => '',
        expires => 1,
    };
}
sub _set_session {
    my $resp = shift;
    my $sid = shift;
    my $remember_me = shift;
    $resp->cookies->{Act_session_id} = {
        value => $sid,
        path => '/',
        $remember_me ? ( expires => time + 6*30*24*60*60 ) : (),
    };
}

1;

