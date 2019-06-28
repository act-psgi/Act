package Act::Handler::User::Search;
use strict;
use parent 'Act::Handler';

use Act::Config;
use Act::Data;
use Act::Template::HTML;
use Act::User;
use Act::Country;
use Act::Util;

sub handler {

    # search the users
    my $offset = $Request{args}{prev}
               ? $Request{args}{oprev}
               : $Request{args}{next}
               ? $Request{args}{onext}
               : undef;
    my $limit = $Config->general_searchlimit;
    my $users = %{$Request{args}}
              ? Act::User->get_users( %{$Request{args}},
                  $Request{conference} ? ( conf_id => $Request{conference} ) : (),
                  limit => $limit + 1, offset => $offset  )
              : [];

    # offsets for potential previous/next pages
    my ($oprev, $onext);
    $oprev = $offset - $limit if $offset;
    if (@$users > $limit) {
       pop @$users;
       $onext = $offset + $limit;
    }

    my %seen;

    # fetch the countries
    my $countries = Act::Country::CountryNames();
    %seen = ( map { $_ => 1 } @{Act::Data::countries($Request{conference})});
    $countries = [ grep { $seen{$_->{iso} } } @$countries ];
    my %by_iso = map { $_->{iso} => $_->{name} } @$countries;

    # fetch the monger groups
    %seen = ();
    my $pm_groups = [ Act::Util::usort { $_ }
                   grep !$seen{lc $_}++,
                   map { split /\s*[^\w. -]\s*/, $_ }
                   @{Act::Data::pm_groups($Request{conference})}
                 ];

    # process the search template
    my $template = Act::Template::HTML->new();
    $template->variables(
        pm_groups     => $pm_groups,
        countries_iso => \%by_iso,
        countries     => $countries,
        users         => $users,
        oprev         => $oprev,
        prev          => defined($oprev),   # $oprev can be zero
        onext         => $onext,
        next          => defined($onext), 
    );
    $template->process('user/search_form');
    return;
}

1;

=head1 NAME

Act::Handler::User::Search - search for users

=head1 DESCRIPTION

See F<DEVDOC> for a complete discussion on handlers.

=cut
