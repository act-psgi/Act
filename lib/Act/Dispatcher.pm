use strict;
package Act::Dispatcher;

use Act::Config;
use Act::Handler::Static;
use Act::Util;

use File::Spec::Functions qw(catfile rel2abs);
use List::Util qw(first);
use Module::Pluggable::Object;
use Plack::App::Cascade;
use Plack::App::File;
use Plack::Builder;
use Plack::Middleware::Debug;
use Plack::Request;

# main dispatch table
my %public_handlers = (
    api             => 'Act::Handler::WebAPI',
    atom            => 'Act::Handler::News::Atom',
    changepwd       => 'Act::Handler::User::ChangePassword',
    event           => 'Act::Handler::Event::Show',
    events          => 'Act::Handler::Event::List',
    faces           => 'Act::Handler::User::Faces',
    favtalks        => 'Act::Handler::Talk::Favorites',
    login           => 'Act::Handler::Login',
    news            => 'Act::Handler::News::List',
    openid          => 'Act::Handler::OpenID',
    proceedings     => 'Act::Handler::Talk::Proceedings',
    slides          => 'Act::Handler::Talk::Slides',
    register        => 'Act::Handler::User::Register',
    schedule        => 'Act::Handler::Talk::Schedule',
    search          => 'Act::Handler::User::Search',
    stats           => 'Act::Handler::User::Stats',
    talk            => 'Act::Handler::Talk::Show',
    talks           => 'Act::Handler::Talk::List',
    'timetable.ics' => 'Act::Handler::Talk::ExportIcal',
    user            => 'Act::Handler::User::Show',
    wiki            => 'Act::Handler::Wiki',
);

my %private_handlers = (
    change          => 'Act::Handler::User::Change',
    create          => 'Act::Handler::User::Create',
    csv             => 'Act::Handler::CSV',
    confirm_attend  => 'Act::Handler::User::ConfirmAttendance',
    editevent       => 'Act::Handler::Event::Edit',
    edittalk        => 'Act::Handler::Talk::Edit',
    export          => 'Act::Handler::User::Export',
    export_talks    => 'Act::Handler::Talk::ExportCSV',
    ical_import     => 'Act::Handler::Talk::Import',
    invoice         => 'Act::Handler::Payment::Invoice',
    logout          => 'Act::Handler::Logout',
    main            => 'Act::Handler::User::Main',
    myschedule      => 'Act::Handler::Talk::MySchedule',
    'myschedule.ics'=> 'Act::Handler::Talk::ExportMyIcal',
    newevent        => 'Act::Handler::Event::Edit',
    newsadmin       => 'Act::Handler::News::Admin',
    newsedit        => 'Act::Handler::News::Edit',
    newtalk         => 'Act::Handler::Talk::Edit',
    orders          => 'Act::Handler::User::Orders',
    openid_trust    => 'Act::Handler::OpenID::Trust',
    payment         => 'Act::Handler::Payment::Edit',
    payments        => 'Act::Handler::Payment::List',
    photo           => 'Act::Handler::User::Photo',
    punregister     => 'Act::Handler::Payment::Unregister',
    purchase        => 'Act::Handler::User::Purchase',
    rights          => 'Act::Handler::User::Rights',
    trackedit       => 'Act::Handler::Track::Edit',
    tracks          => 'Act::Handler::Track::List',
    updatemytalks   => 'Act::Handler::User::UpdateMyTalks',
    updatemytalks_a => 'Act::Handler::User::UpdateMyTalks::ajax_handler',
    unregister      => 'Act::Handler::User::Unregister',
    wikiedit        => 'Act::Handler::WikiEdit',
);

sub to_app {
    Act::Config::reload_configs();
    my $app            = builder {
        enable 'Debug', panels => [split(/\s+/, $ENV{ACT_DEBUG})]
            if $ENV{ACT_DEBUG};

        enable sub {
            my $app = shift;
            sub {
                my $env = shift;
                my $req = Plack::Request->new($env);

                # Make sure there is no trailing slash in base_url
                my $base_url = $req->base->as_string;
                $base_url =~ s{/$}{};
                $env->{'act.base_url'} = $base_url;
                $env->{'act.dbh'}      = Act::Util::db_connect();
                $app->($env);
            };
        };

        mount "/photos" => root_file_app($Config->general_dir_photos);
        my %confr = %{ $Config->uris },
            map { $_ => $_ } %{ $Config->conferences };
        for my $uri (keys %confr) {
            my $conference = $confr{$uri};
            my $conference_app = conference_app($conference);
            mount "/$uri/" => sub {
                my $env = shift;
                $env->{'act.conference'} = $conference;
                $env->{'act.config'} = Act::Config::get_config($conference);
                $conference_app->($env);
            };
        }
        mount "/" => root_file_app('wwwdocs');
    };
    return $app;
}

sub conference_app {
    my $conference = shift;
    my $path = catfile($Config->home, $conference, 'wwwdocs');
    my $static_app = builder {
        enable '+Act::Middleware::Auth';
        Act::Handler::Static->new->to_app;
    };
    builder {
        enable '+Act::Middleware::Language';
        enable sub {
            my $app = shift;
            sub {
                for ( $_[0]->{'PATH_INFO'} ) {
                    if ( s{^/?$}{index.html} || /\.html$/ || m!/LOGIN!) {
                        return $static_app->(@_);
                    }
                    else {
                        return $app->(@_);
                    }
                }
            };
        };
        Plack::App::Cascade->new( catch => [99], apps => [
            builder {
                for my $uri ( keys %public_handlers ) {
                    mount "/$uri" => _handler_app($public_handlers{$uri});
                }
                for my $uri ( keys %private_handlers ) {
                    mount "/$uri" => _handler_app($private_handlers{$uri},
                                                  private => 1);
                }
                mount '/' => sub { [99, [], []] };
            },
            Plack::App::File->new(root => $path)->to_app,
        ] );
    };
}

sub root_file_app {
    my ($rel_path) = @_;
    my $abs_path = rel2abs($rel_path,$Config->general_root);
    warn "Rel path = $rel_path;\n abs_path = $abs_path\n";
    Plack::App::File->new(root => $abs_path)->to_app;
}

{
    my @HANDLERS;
    my $search_path = 'Act::Handler';
    sub _load_handler_plugins {
        if (!@HANDLERS) {
            my $finder = Module::Pluggable::Object->new(
                search_path => $search_path,
                require     => 1,
            );
            @HANDLERS = $finder->plugins;
        }
    }

    sub _get_handler_plugin {
        my ($handler) = @_;

        my $subhandler;
        if ($handler =~ s/::(\w+_handler)$//) {
            $subhandler = $1;
        }

        _load_handler_plugins;
        if (my $plugin = first { $handler eq $_ } @HANDLERS) {
            return $handler->new(subhandler => $subhandler) if defined $subhandler;
            return $handler->new();
        }
        die sprintf("Unable to load '%s', not found in search path: '%s'!\n",
            $handler, $search_path);
    }
}


sub _handler_app {
    my ($handler, %attrs) = @_;
    builder {
        enable '+Act::Middleware::Auth', %attrs;
        return _get_handler_plugin($handler)->to_app;
    }
}

1;
__END__

=head1 NAME

Act::Dispatcher - Dispatch web request

=head1 SYNOPSIS

  # Fire up the dispatcher as a PSGI application
  use Act::Dispatcher;
  Act::Dispatcher->to_app;

=head1 The URL hierarchy

On top level, the dispatcher serves 1) user photos, 2) the
conferences, and 3) static files coming with the distributions.

The conferences themselves have their own dispatcher in
C<conference_app>, which handles 1) HTML files provided by organizers,
2) "action" handlers from the list of public and private handlers, and
3) static files provided by organizers.

The handlers themselves in the C<Act::Handler::*> namespace are still
using the traditional Apache/mod_perl approach: They communicate with
other components through global variables C<$Config> and
C<%Request>. The translation between PSGI style C<env> and Apache
style C<Request> is done in L<Act::Handler>, and L<Act::Config> takes
care to export them as globals to all modules using it.

=head1 Maintainer's Introduction to PSGI and Plack

From bottom to top, the PSGI stack looks like this:

=over

=item The I<Application>

The application does the work to convert data from the HTTP request to
a response.  It receives the data as a hash reference C<$env> and
returns the response as a hashref C<[$code,[@headers],[@body]]>.

=item Middleware

Middleware is a bit of a misnomer since it is rather I<aroundware>.
A middleware component looks like this:

    sub middleware {
        my ($app,$env) = @_;
        # Do something with $env
        my $response = $app($env);
        # Do something with $response
        return $response;
    }

Middleware is extremely powerful and versatile.  As long as it returns
a C<$response>, nobody knows whether it got this response from calling
C<$app>, from calling any other application, or from making it up
itself.

=item Builder

The builders compose an application by distributing URLs between
different applications (that's what C<mount> is for), and wrap them in
middleware components (with C<enable>).

As we see in this module, this can be used hierarchically: An
application C<mount>-ed for some part of URLspace can itself be
constructed by a C<builder> which wraps it into another set of
middleware components.

=back

=cut
