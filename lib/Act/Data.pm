package Act::Data;
# ABSTRACT: Interface between Act and the database

use 5.020;
use feature qw(signatures);
no warnings qw(experimental::signatures);

# ======================================================================
# The first bunch of queries all have the conference as a parameter.
# TODO: Consider making them part of a conference object

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
# From Act::User::create
sub register_user ($conference,$user_id ) {
    my $dbh = dbh();
    my $sth = $dbh->prepare_cached(
        "INSERT INTO participations (user_id, conf_id) VALUES (?,?)"
    );
    $sth->execute($user_id, $conference);
    $sth->finish();
    $dbh->commit;
}


# ----------------------------------------------------------------------
# From Act::User
sub register_participation ($conference,$user_id,$address,$tshirt_size) {
    my $dbh = dbh();
    # create a new participation to this conference
    my $sth = $dbh->prepare_cached(q{
        INSERT INTO participations
          (user_id, conf_id, datetime, ip, tshirt_size)
        VALUES  (?,?, NOW(), ?, ?)
    });
    $sth->execute($user_id, $conference,
    $address, $tshirt_size);
    $sth->finish();
    $dbh->commit;
}


# ----------------------------------------------------------------------
# From Act::User::participation
sub participation ($conference,$user_id) {
    my $sth = sql('SELECT * FROM participations p'
                . ' WHERE p.user_id=? AND p.conf_id=?',
                  $user_id, $conference );
    my $participation = $sth->fetchrow_hashref();
    $sth->finish();
    return $participation;
}


# ----------------------------------------------------------------------
# From Act::User::update
sub update_participation ($conference,$user_id,%fields) {
    my $sql = sprintf 'UPDATE participations SET %s WHERE conf_id=? AND user_id=?',
        join(',', map "$_=?", keys %fields);
    my $sth = sql( $sql, values %fields, $conference, $user_id );
    dbh()->commit;
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
# From Act::User::my_talks
sub my_talk_ids ($conference,$user_id) {
    my $sth = sql(<<EOF, $user_id, $conference);
SELECT u.talk_id FROM user_talks u, talks t
WHERE u.user_id=? AND u.conf_id=?
AND   u.talk_id = t.talk_id
AND   t.accepted
EOF
    my $talk_ids = $sth->fetchall_arrayref();
    $sth->finish();
    return [ map { $_->[0] } @$talk_ids ];
}

# From Act::User::update_my_talks
sub update_my_talks ($conference,$user_id,$remove_list,$add_list) {
    if (@$remove_list) {
        sql(
            'DELETE FROM user_talks'
                . ' WHERE user_id = ? AND conf_id = ?'
                . ' AND talk_id IN ('
                .  join(',', map '?',@$remove_list)
                . ')',
            $user_id, $conference, @$remove_list
        );
    }

    if (@$add_list) {
        my $sql = "INSERT INTO user_talks VALUES (?,?,?)";
        my $sth = sql_prepare($sql);
        sql_exec($sth, $sql, $user_id, $conference, $_)
            for @$add_list;
    }

    dbh()->commit  if  @$remove_list || @$add_list;
}

# From Act::User::attendees
sub attendees ($conference,$talk_id) {
    my $sth = sql(<<EOF, $talk_id, $conference);
SELECT user_id FROM user_talks
WHERE talk_id=? AND conf_id=?
EOF
    my $user_ids = $sth->fetchall_arrayref();
    $sth->finish();
    return [ map { $_->[0] } @$user_ids ];
}


# ======================================================================
# Some queries consistently have a conference and a user id as
# parameters (TODO: Check the list from above for more of them).  This
# looks like there's enough motivation for a class "Act::Visitor" or
# something like that.

# ----------------------------------------------------------------------
# From Act::User
sub has_talk ($conference,$user_id) {
    my $sql = 'SELECT count(*) FROM talks t' .
              ' WHERE t.user_id=? AND t.conf_id=?';
    my $sth = sql($sql, $user_id, $conference);
    my $has_talk = $sth->fetchrow_arrayref()->[0];
    $sth->finish;
    return $has_talk;
}

sub has_accepted_talk ($conference,$user_id) {
    my $sql = 'SELECT count(*) FROM talks t' .
              ' WHERE t.user_id=? AND t.conf_id=? AND t.accepted';
    my $sth = sql($sql, $user_id, $conference);
    my $has_accepted_talk = $sth->fetchrow_arrayref()->[0];
    $sth->finish;
    return $has_accepted_talk;
}

sub has_paid ($conference,$user_id) {
    my $sql = "SELECT count(*) FROM orders o, order_items i
            WHERE o.user_id=? AND o.conf_id=?
              AND o.status = ?
              AND o.order_id = i.order_id
              AND i.registration";
    my $sth = sql($sql, $user_id, $conference, 'paid');
    my $has_paid = $sth->fetchrow_arrayref()->[0];
    $sth->finish;
    return $has_paid;
}

sub has_registered ($conference,$user_id) {
    my $sql = 'SELECT count(*) FROM participations p'
            . ' WHERE p.user_id=? AND p.conf_id=?';
    my $sth = sql($sql, $user_id, $conference);
    my $has_registered = $sth->fetchrow_arrayref()->[0];
    $sth->finish;
    return $has_registered;
}

sub has_attended ($conference,$user_id) {
    my $sql = 'SELECT count(*) FROM participations p'
            . ' WHERE p.user_id=? AND p.conf_id=? AND p.attended IS TRUE';
    my $sth = sql($sql, $user_id, $conference);
    my $has_attended = $sth->fetchrow_arrayref()->[0];
    $sth->finish;
    return $has_attended;
}


# ======================================================================
# Queries not bound to one user
sub next_invoice_num ($conference) {
    my $sth = sql("SELECT next_num FROM invoice_num WHERE conf_id=?", $conference);
    my ($invoice_no) =  $sth->fetchrow_array;
    $sth->finish;

    if ($invoice_no) {
        sql('UPDATE invoice_num SET next_num=next_num+1'
          . ' WHERE conf_id=?', $conference);
    }
    else {
        sql("INSERT INTO invoice_num (conf_id, next_num) VALUES (?,?)",
            $conference, 2);
        $invoice_no = 1;
    }
    return $invoice_no;
}

# ======================================================================
# The following queries are not bound to one conference.  There are
# two "global" services: The user service (including authentication
# and authorization) and the database ("infrastructure") service.

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
# From Act::User::register_participation
sub tshirt_size ($user_id) {
    my $dbh = dbh();
    my $sth = $dbh->prepare_cached(q{
        SELECT  tshirt_size
        FROM    participations
        WHERE   user_id = ?
        AND tshirt_size is not null
        ORDER BY datetime DESC
        LIMIT 1
    });
    $sth->execute( $user_id );
    my ($tshirt_size) = $sth->fetchrow_array;
    $sth->finish;
    return $tshirt_size;
}


# ----------------------------------------------------------------------
# From Act::User::update
sub update_bio ($user_id,$bio) {
    my @sql =
        (
            "SELECT 1 FROM bios WHERE user_id=? AND lang=?",
            "UPDATE bios SET bio=? WHERE user_id=? AND lang=?",
            "INSERT INTO bios ( bio, user_id, lang) VALUES (?, ?, ?)",
        );
    my @sth = map sql_prepare($_), @sql;
    for my $lang ( keys %$bio ) {
        sql_exec( $sth[0], $sql[0], $user_id, $lang );
        if( $sth[0]->fetchrow_arrayref ) {
            sql_exec(  $sth[1], $sql[1], $bio->{$lang}, $user_id, $lang );
        }
        else {
            sql_exec( $sth[2], $sql[2],  $bio->{$lang}, $user_id, $lang );
        }
        $sth[0]->finish;
        dbh()->commit;
    }
}


# ----------------------------------------------------------------------
# From Act::User
sub participations ($user_id) {
     my $sth = sql(
        "SELECT * FROM participations p WHERE p.user_id=?",
         $user_id );
     my $participations = [];
     while( my $p = $sth->fetchrow_hashref() ) {
         push @$participations, $p;
     }
     return $participations;
}


# ----------------------------------------------------------------------
# From Act::News
# The following queries doesn't technically pass a conference, but news
# (and their identifiers) are conference specific data.
sub fetch_news ($news_id) {
    my $sth = sql('SELECT lang, title, text FROM news_items'
                . ' WHERE news_id = ?', $news_id);
    my $ref = $sth->fetchall_arrayref;
    my $items = { map {
        my ($lang, $title, $text) = @$_;
        $lang => { title => $title, text => $text }
    } @$ref };
    $sth->finish;
    return $items;
}

sub update_news($news_id,$items) {
    sql('DELETE FROM news_items WHERE news_id=?', $news_id);
    for my $lang (keys %$items) {
        sql('INSERT INTO news_items ( title, text, news_id, lang )'
          . ' VALUES (?, ?, ?, ?)',
            $items->{$lang}{title}, $items->{$lang}{text}, $news_id, $lang );
    }
}


# ----------------------------------------------------------------------
# Fetch the database handler
sub dbh {
    # TODO: The data base handler is supposed to be stored somewhere else
    return $Act::Config::Request{dbh};
}

# ----------------------------------------------------------------------
# Adopted from Act::Object
sub sql_prepare
{
    my ($sql) = @_;
    return dbh()->prepare_cached($sql);
}

sub sql_exec
{
    my ($sth, $sql, @params) = @_;
    $sth->execute(@params);
}

sub sql
{
    my ($sql, @params) = @_;
    my $sth = sql_prepare($sql);
    sql_exec($sth, $sql, @params);
    return $sth;
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

As it turns out, there are three categories of subroutines:

=over

=item 1. Queries for one conference

=item 2. Queries about users, independent of conferences

=item 3. Infrastructure utilities (where's my database handle?)

=back

This seems to be the natural source to define the "layers" for Act, as
outlined by BooK in the Act-Voyager project (I'm too lazy to dig for
the URL, sorry).

=head1 SUBROUTINES

=head2 Queries for one conference

=head3 $count = Act::Data::current_attendee_count($conference,$is_free)

Returns the number of registered users.  For a conference which isn't
free of charge, only users which have either submitted a talk which
was accepted, or have some rights, or have paid, are counted towards
the maximum number of attendees from the configuration.

=head3 $iso_ref = Act::Data::top_ten_countries($conference);

Returns a reference to an array containing ISO country codes for the
ten countries where most attendees come from, ordered by decreasing
count.

Used by the template where a new user fills in his details.

=head3 Act::Data::unregister_user($conference,$user_id)

Unregisters the user with numerical user id C<$user_id> from the
conference C<$conference>.

=head3 Act::Data::favourite_talks($conference)

Returns an array reference to two-element array references containing
a numerical talk id and its user count, sorted by descending user count.

=head3 Act::Data::register_user($conference,$user_id)

Registers the user with numerical user id C<$user_id> for the
conference C<$conference>.

=head3 Act::Data::register_participation($conference,$user_id,$addr,$size)

Registers the user with numerical user id C<$user_id> for the
conference C<$conference>, supplying also the IP address of the caller
and the user's T-shirt size.

B<Note:> This is highly suspicious.

=head3 $participation = Act::Data::participation($conference,$user)

Returns a hash reference containing key/value pairs for the whatever
is in the database for that C<$conference> and that C<$user>:

=head3 Act::Data::update_participation($conference,$user_id,%fields)

Updates the participation data of the visitor with whatever is in
C<%fields>.

=over

=item * C<conf_id> - The conference id

=item * C<user_id> - The numerical user id

=item * C<tshirt_size> - The size for the user's T-Shirt

=item * C<nb_family> - How many additional people the user brings to the social event

=item * C<datetime> - Time of registration by the user

=item * C<IP> - The IP address of the user's registration

=item * C<attended> - User has confirmed his attendance

=back

=head3 $ref = Act::Data::all_rights($conference)

Returns an array reference containing hash references with the keys
C<user_id> and C<right_id> and their corresponding values for all
rights of all users in <$conference>.

=head3 Act::Data::add_right($conference,$user_id,$right_id)

Adds the right C<$right_id> (a string) to the user with numerical user
id C<$user_id> for the conference C<$conference>.

=head3 Act::Data::remove_right($conference,$user_id,$right_id)

Removes the right C<$right_id> (a string) from the user with numerical
user id C<$user_id> for the conference C<$conference>.

=head3 $ref = Act::Data::countries($conference)

Returns a reference to an array of ISO country codes from where users
have registered for this conference.

=head3 $ref = Act::Data::pm_groups($conference)

Returns a reference to an array of Perl mongers group names from where
users have registered for this conference.

=head3 $ref = Act::Data::my_talk_ids($conference,$user_id)

Returns a reference to an array which holds the numerical ids for
each accepted talk by the user with numeric user id C<user_id> for the
conference C<$conference>.

=head3 Act::Data::update_my_talks($conference,$user_id,$remove_list,$add_list)

The parameters C<$remove_list> and C<$add_list> are references to
lists of talk ids which are to be removed from the given
C<$conference> and numerical C<$user_id>.

=head3 User Flags: has_talk, has_accepted_talk, has_paid, has_registered, has_attended

All these functions accept a conference and a numeric user id as
parameters and return a boolean.

In legacy Act, the code for these functions was generated on-the-fly.
Here they are expanded, incurring some violation of
Don't-Repeat-Yourself.  Eventually they might end up as lazily
evaluated attributes of a yet-to-be-written class Act::Visitor.

=head3 Act::Data::attendees($conference,$talk_id)

Returns a reference to an array holding the numerical user ids of
users who announced to attend the talk C<$talk_id> at C<$conference>.

=head2 Queries about users

=head3 Act::Data::store_token(token,$email,$data)

Stores an email address and twostep data together with their
corresponding token.

=head3 Act::Data::delete_token($token)

Deletes the given token from the database.

=head3 $token = Act::Data::token_data($token)

Returns a reference to the token data if the token C<$token> exists,
undef otherwise.

=head3 $size = Act::Data::tshirt_size($user)

Returns the most recently T-shirt size entered by a user, regardless
of conference.

B<Note:> This routine needs to be checked closely.  It breaks the
segregation of duties between the provider and the organizers.

=head3 Act::Data::update_bio($user_id,$bio)

Updates a user's biography, or biographies.  C<$bio> is a reference to
a hash where the keys are the languages of the biography.

=head3 $pref = Act::Data::participations($user_id)

Returns a reference to a list of hash references, each containing
key/value pairs for whatever the database contains.  See
C<participation> for the keys.

B<Note:> This function has to be re-considered under GDPR.

=head3 $items = Act::Data::fetch_news($news_id)

Returns a hash reference where the keys are languages and the values
in turn are hash references with keys C<title> and C<text> for the
corresponding language.

This function isn't explicitly conference specific, but since news ids
are assigned per conference, every news item belongs to exactly one
conference.

=head3 Act::Data::update_news($news_id,$items)

Takes a hash reference C<$items> as defined in the previous section
and uses it to replace the news item with identifier C<$news_id>.

This function isn't explicitly conference specific, but since news ids
are assigned per conference, every news item belongs to exactly one
conference.

B<Note:> This function I<does not commit changes to the database.>

=head1 CAVEATS

There are no automated tests for these functions yet.  This is bad.

=head1 AUTHOR

Harald Jörg, haj@posteo.de

=head1 COPYRIGHT AND LICENSE

Copyright 2019 Harald Jörg

This library is free software; you may redistribute it and/or
modify it under the same terms as Perl itself.

=cut
