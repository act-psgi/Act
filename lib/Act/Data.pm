package Act::Data;
# ABSTRACT: Interface between Act and the database

use 5.020;
use feature qw(signatures);
no warnings qw(experimental::signatures);

use DateTime::Format::HTTP;

# ----------------------------------------------------------------------
# From Act::Config::get_config
sub current_attendee_count ($conference,$is_free) {
    # TODO: The data base handler is supposed to be stored somewhere else
    my $dbh = $Act::Config::Request{dbh};
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
    my $sth = $dbh->prepare_cached($sql);
    $sth->execute(@values);
    my ($count) = $sth->fetchrow_array();
    $sth->finish;
    warn "Count: $count";
    return $count;
}

1;

__END__

=encoding utf8

=head1 NAME

Act::Data - Interface between Act and the database

=head1 SYNOPSIS

use Act::Data;
my $count = Act::Data::current_attendee_count($conference,$is_free);

=head1 DESCRIPTION

This module is an intermediate step to refactoring Act's use of config
files and the database as its sources of persistent data.  This is not
a class (yet), just a collection of subroutines to get an overview
which interfaces are used.

=head1 SUBROUTINES

=head2 $count = current_attendee_count($conference,$is_free)

Returns the number of registered users.  For a conference which isn't
free of charge, only users which have either submitted a talk which
was accepted, or have some rights, or have paid, are counted towards
the maximum number of attendees from the configuration.


=head1 CAVEATS

There are no automated tests for these functions yet.  This is bad.

=head1 AUTHOR

Harald Jörg, haj@posteo.de

=head1 COPYRIGHT AND LICENSE

Copyright 2019 Harald Jörg

This library is free software; you may redistribute it and/or
modify it under the same terms as Perl itself.

=cut
