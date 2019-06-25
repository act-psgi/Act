package Act::Data;
# ABSTRACT: Interface between ACT and the database

use 5.020;
use feature qw(signatures);
no warnings qw(experimental::signatures);

use DateTime::Format::HTTP;

# ----------------------------------------------------------------------
# From Act::Config::get_config
sub current_attendee_number ($conference,$config) {
    # TODO: The data base handler is supposed to be stored somewhere else
    my $dbh = $Act::Config::Request{dbh};
    my $sql = 'SELECT COUNT(*) FROM participations p WHERE p.conf_id=?';
    my @values = ($conference);
    if ($config->payment_type ne 'NONE') {
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

