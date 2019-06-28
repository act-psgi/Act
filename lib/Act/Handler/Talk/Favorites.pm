package Act::Handler::Talk::Favorites;
use strict;
use parent 'Act::Handler';

use Act::Config;
use Act::Template::HTML;
use Act::Talk;
use Act::User;

sub handler
{
    # retrieve tracks
    my %tracks = map { $_->track_id => $_ }
            @{ Act::Track->get_tracks(conf_id => $Request{conference}) };

    my $favourite_talks = Act::Data::favourite_talks($Request{conference});
    my @favs;
    for my $fav (@$favourite_talks) {
        my ($talk_id, $count) = @$fav;
        my $talk = Act::Talk->new(talk_id => $talk_id);
        if ($Config->talks_show_all
         || $talk->accepted
         || ($Request{user} && (   $Request{user}->is_talks_admin
                                || $Request{user}->user_id == $talk->user_id)))
        {
            push @favs, { talk  => $talk,
                          count => $count,
                          user  => Act::User->new(user_id => $talk->user_id),
                        };
        }
    }
    # link the talks to their tracks (keeping the talks ordered)
    # process the template
    my $template = Act::Template::HTML->new();
    $template->variables(
        favs   => \@favs,
        tracks => \%tracks,
    );
    $template->process('talk/favorites');
    return;
}

1;
__END__

=head1 NAME

Act::Handler::Talk::Favorites - show users' favorites talks

=head1 DESCRIPTION

See F<DEVDOC> for a complete discussion on handlers.

=cut
