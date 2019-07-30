package Act::Middleware::Auth;
use strict;
use warnings;

use parent qw(Plack::Middleware);
use Plack::Request;
use Plack::Session;
use Try::Tiny;
use Plack::Util::Accessor qw(private);
use Encode qw(decode);

sub call {
    my $self = shift;
    my $env = shift;

    my $req = Plack::Request->new($env);

    my $session_id = $req->cookies->{'Act_session_id'};

    $env->{'act.auth.login'} = \&_login;

    my $user;
    my $session = Plack::Session->new($env);
    if (my $login = $session->get('login')) {
        # Using the traditional interface
        $user = Act::User->new( login => $login );
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

1;

