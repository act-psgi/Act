package Act::Middleware::Auth;
use strict;
use warnings;

use Act::User;

use parent qw(Plack::Middleware);
use Plack::Session;
use Plack::Util::Accessor qw(private);

sub call {
    my $self = shift;
    my $env = shift;

    my $session = Plack::Session->new($env);
    my $login   = $session->get('login');
    $env->{'act.loginuser'} = $login;

    if (! $login  && $self->private) {
        $env->{'act.login.destination'} = $env->{REQUEST_URI};
        return Act::Handler::Login->new->call($env);
    }

    $env->{'act.user'} = Act::User->new( login => $login );
    $self->app->($env);
}

1;
