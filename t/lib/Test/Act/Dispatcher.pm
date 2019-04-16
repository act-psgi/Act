# ABSTRACT: Helper for Dispatcher tests
package Test::Act::Dispatcher;

use parent 'Exporter';
our @EXPORT = qw(mock_config     mock_file    mock_static
                 mock_middleware mock_handler
                 mock_config_value
            );

use Test::MockObject;
use Plack::Test;
use YAML::Tiny;


# Act::Middleware::*
sub mock_middleware {
    my $options = shift;
    return sub {
        my $self  = shift;
        my ($env) = @_;
        $env->{"act.test"}{middleware} //= [];
        push @{$env->{"act.test"}{middleware}},
            [ref $self => { map {$_ => $self->$_} @$options}];
        return $self->app->($env);
    };
}

# Act::Handler::*
sub mock_handler {
    return sub {
        my $self  = shift;
        my ($env) = @_;
        my $report = _report($self,$env);
        return _format_for_psgi($report);
    };
}

# Plack::App::File has an extra field 'root' to report
sub mock_file {
    return sub {
        my $self  = shift;
        my ($env) = @_;
        my $report = _report($self,$env,
                             root => $self->root);
        return _format_for_psgi($report);
    };
}

sub _report {
    my $self = shift;
    my $env  = shift;
    my $report = {
        app        => ref $self,
        path_info  => $env->{PATH_INFO},
        middleware => $env->{"act.test"}{middleware} // [],
        @_,
    };
}

sub _format_for_psgi {
    my ($report) = @_;
    return [200, # ignored
            [],  # ignored
            [YAML::Tiny->new($report)->write_string],
           ];
}

my %uris = (
    foo => 'foo',
    bar => 'bar',
    baz => 'foo',
);

my $cfg = Test::MockObject->new;
$cfg->set_always(uris => \%uris)
    ->set_always(home => 'testhome')
    ->set_always(general_root => 'testhome')
    ->set_always(email_sendmail => '/usr/sbin/sendmail')
    ->set_always(database_debug => 0)
    ->set_always(conferences => { map { $_ => 1 } values %uris })
    ->set_always(general_dir_photos => 'photos')
    ;


sub mock_config {
    return $cfg;
}

# This could be done with Test::MockModule as well,
# but as long as we don't need anything from them
# we can just overwrite them globally
{
    no warnings 'redefine';
    *Act::Config::get_config        = sub { $cfg };
    *Act::Config::finalize_config   = sub {};
    *Act::Util::db_connect          = sub {};
}

use Act::Config;
$Config = mock_config;
require Act::Dispatcher;
my $app    = Act::Dispatcher->to_app;
my $tester = Plack::Test->create($app);

sub driver {
    my $class = shift;
    bless {},$class;
}

sub request {
    my $self = shift;
    my ($request) = @_;
    my $response = $tester->request($request);
    my $yaml = YAML::Tiny->read_string($response->content);
    return %{$yaml->[0]};
}
