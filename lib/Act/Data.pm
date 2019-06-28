package Act::Data;
# ABSTRACT: Interface between Act and the database

use 5.020;
use feature qw(signatures);
no warnings qw(experimental::signatures);

# ----------------------------------------------------------------------
# From Act::Config::get_config
sub current_attendee_count ($conference,$is_free) {
    my $sql = 'SELECT COUNT(*) FROM participations p WHERE p.conf_id=?';
    my @values = ($conference);
    if (! $is_free) {
        $sql .= <<EOF;
 AND (
     EXISTS(SELECT 1 FROM talks t WHERE t.user_id=p.user_id AND t.conf_id=? AND t.accepted IS TRUE)
  OR EXISTS(SELECT 1 FROM rights r WHERE r.user_id=p.user_id AND r.conf_id=? AND r.right_id IN (?,?,?))
  OR EXISTS(SELECT 1 FROM orders o, order_items i WHERE o.user_id=p.user_id AND o.conf_id=? AND o.status=?
                                                    AND o.order_id = i.order_id AND i.registration)
)
EOF
        push @values, $conference,
            $conference, 'admin_users', 'admin_talks', 'staff',
            $conference, 'paid';
    }
    my $sth = dbh()->prepare_cached($sql);
    $sth->execute(@values);
    my ($count) = $sth->fetchrow_array();
    $sth->finish;
    return $count;
}

# ----------------------------------------------------------------------
# From Act::Country::TopTen
sub top_ten_countries ($conference) {
    my $sth = dbh()->prepare_cached(
        'SELECT u.country FROM users u, PARTICIPATIONS p'
            . ' WHERE u.user_id = p.user_id AND p.conf_id = ?'
            . ' GROUP BY u.country ORDER BY COUNT(u.country) DESC LIMIT 10'
        );
    $sth->execute( $conference );
    my @top_ten_iso = map { $_->[0] } @{ $sth->fetchall_arrayref([]) };
    $sth->finish;
    return \@top_ten_iso;
}


# ----------------------------------------------------------------------
# From Act::Handler::Payment::Unregister
# From Act::Handler::User::Unregister
sub unregister_user ($conference,$user_id) {
    my $dbh = dbh();
    my $sth = $dbh->prepare_cached(
        "DELETE FROM participations WHERE user_id=? AND conf_id=?"
    );
    $sth->execute($user_id,$conference);
    $sth->finish();
    $dbh->commit;
}


# ----------------------------------------------------------------------
# From Act::Handler::Talk::Favorites
sub favourite_talks ($conference) {
    my $dbh = dbh();
    # retrieve user_talks, most popular first
    my $sth = $dbh->prepare_cached(
        'SELECT talk_id, COUNT(talk_id) FROM user_talks'
      . ' WHERE conf_id = ? GROUP BY talk_id ORDER BY count DESC');
    $sth->execute($conference);
    return $sth->fetchall_arrayref;
}


# ----------------------------------------------------------------------
# From Act::Handler::User::Create::handler
sub register_user ($conference,$user_id) {
    my $dbh = dbh();
    my $sth = $dbh->prepare_cached(
        "INSERT INTO participations (user_id, conf_id) VALUES (?,?)"
    );
    $sth->execute($user_id, $conference);
    $sth->finish();
    $dbh->commit;
}


# ----------------------------------------------------------------------
# From Act::Handler::User::Rights::handler
sub all_rights ($conference) {
    my $dbh = dbh();
    my $sth = $dbh->prepare_cached(
        'SELECT right_id, user_id FROM rights'
      . ' WHERE conf_id=? ORDER BY right_id, user_id');
    $sth->execute($conference);
    return $sth->fetchall_arrayref({});
}

sub add_right ($conference,$user_id,$right_id) {
    my $dbh = dbh();
    $dbh->prepare_cached(
        'INSERT INTO rights (right_id, user_id, conf_id) VALUES (?,?,?)'
    )
    ->execute( $right_id, $user_id, $conference );
    $dbh->commit;
}

sub remove_right ($conference,$user_id,$right_id) {
    my $dbh = dbh();
    $dbh->prepare_cached(
        'DELETE FROM rights WHERE right_id=? AND user_id=? AND conf_id=?'
    )
    ->execute( $right_id, $user_id, $conference );
    $dbh->commit;
}


# ----------------------------------------------------------------------
# From Act::Handler::User::Search
sub countries ($conference) {
    my $dbh = dbh();
    my $sql = 'SELECT DISTINCT u.country FROM users u, participations p'
            . ' WHERE u.user_id=p.user_id AND p.conf_id=? ORDER BY u.country';
    my $sth = $dbh->prepare_cached( $sql );
    $sth->execute( $conference );
    return [ map { $_->[0] } @{$sth->fetchall_arrayref()} ];
}

sub pm_groups ($conference) {
    my $dbh = dbh();
    my $sql = 'SELECT DISTINCT u.pm_group FROM users u, participations p'
         . ' WHERE u.user_id=p.user_id AND p.conf_id=? AND u.pm_group IS NOT NULL';
    my $sth = $dbh->prepare_cached( $sql );
    $sth->execute( $conference );
    my $pm_groups = [ map { $_->[0] } @{$sth->fetchall_arrayref()} ];
    $sth->finish;
    return $pm_groups;
}


# ----------------------------------------------------------------------
# From Act::TwoStep
sub store_token ($token,$email,$data) {
    my $dbh = dbh();
    my $sth = $dbh->prepare_cached(
        'INSERT INTO twostep (token, email, datetime, data)'
      . ' VALUES (?, ?, NOW(), ?)');
    $sth->execute($token, $email, $data);
    $dbh->commit;
}

sub delete_token ($token) {
    my $dbh = dbh();
    my $sth = $dbh->prepare_cached('DELETE FROM twostep WHERE token = ?');
    $sth->execute($token);
    $dbh->commit;
}

sub token_data ($token) {
    my $dbh = dbh();
    my $sth = $dbh->prepare_cached('SELECT token, data FROM twostep'
                                  . ' WHERE token = ?');
    $sth->execute($token);
    my ($found, $data) = $sth->fetchrow_array();
    $sth->finish;
    return $found ? \$data : undef;
}

# ----------------------------------------------------------------------
# Utility: Fetch the database handler
sub dbh {
    # TODO: The data base handler is supposed to be stored somewhere else
    return $Act::Config::Request{dbh};
}

1;

__END__

=encoding utf8

=head1 NAME

Act::Data - Interface between Act and the database

=head1 SYNOPSIS

  use Act::Data;
  $count = Act::Data::current_attendee_count($conference,$is_free);
  $iso_ref = Act::Data::top_ten_countries($conference);

=head1 DESCRIPTION

This module is an intermediate step to refactoring Act's use of config
files and the database as its sources of persistent data.  This is not
a class (yet), just a collection of subroutines to get an overview
which interfaces are used.

=head1 SUBROUTINES

=head2 $count = Act::Data::current_attendee_count($conference,$is_free)

Returns the number of registered users.  For a conference which isn't
free of charge, only users which have either submitted a talk which
was accepted, or have some rights, or have paid, are counted towards
the maximum number of attendees from the configuration.

=head2 $iso_ref = Act::Data::top_ten_countries($conference);

Returns a reference to an array containing ISO country codes for the
ten countries where most attendees come from, ordered by decreasing
count.

Used by the template where a new user fills in his details.

=head2 Act::Data::unregister_user($conference,$user_id)

Unregisters the user with numerical user id C<$user_id> from the
conference C<$conference>.

=head2 Act::Data::favourite_talks($conference)

Returns an array reference to two-element array references containing
a numerical talk id and its user count, sorted by descending user count.

=head2 Act::Data::register_user($conference,$user_id)

Registers the user with numerical user id C<$user_id> for the
conference C<$conference>.

=head2 $ref = Act::Data::all_rights($conference)

Returns an array reference containing hash references with the keys
C<user_id> and C<right_id> and their corresponding values for all
rights of all users in <$conference>.

=head2 Act::Data::add_right($conference,$user_id,$right_id)

Adds the right C<$right_id> (a string) to the user with numerical user
id C<$user_id> for the conference C<$conference>.

=head2 Act::Data::remove_right($conference,$user_id,$right_id)

Removes the right C<$right_id> (a string) from the user with numerical
user id C<$user_id> for the conference C<$conference>.

=head2 $ref = Act::Data::countries($conference)

Returns a reference to an array of ISO country codes from where users
have registered for this conference.

=head2 $ref = Act::Data::pm_groups($conference)

Returns a reference to an array of Perl mongers group names from where
users have registered for this conference.

=head2 Act::Data::store_token(token,$email,$data)

Stores an email address and twostep data together with their
corresponding token.

=head2 Act::Data::delete_token($token)

Deletes the given token from the database.

=head2 Act::Data::token_data($token)

Returns a reference to the token data if the token C<$token> exists,
undef otherwise.

=head1 CAVEATS

There are no automated tests for these functions yet.  This is bad.

=head1 AUTHOR

Harald Jörg, haj@posteo.de

=head1 COPYRIGHT AND LICENSE

Copyright 2019 Harald Jörg

This library is free software; you may redistribute it and/or
modify it under the same terms as Perl itself.

=cut
