package Act::User;
use strict;
use base qw( Act::Object );

use Act::Config;
use Act::Country;
use Act::Data;
use Act::Object;
use Act::Talk;
use Act::Util;
use Encode qw(encode);
use Digest::MD5 qw(md5_hex);
use Digest::SHA qw(sha512);
use Carp;
use Authen::Passphrase::BlowfishCrypt;
use Authen::Passphrase;
use List::Util qw(first);
use Try::Tiny;

# rights
our @Rights = qw( admin users_admin talks_admin news_admin wiki_admin
    staff treasurer );

# class data used by Act::Object
our $table = 'users';
our $primary_key = 'user_id';

our %sql_stub    = (
    select     => "u.*",
    from       => "users u",
    from_opt   => [
        sub { exists $_[0]{conf_id} ? "participations p" : () },
    ],
);

our %sql_mapping = (
    conf_id    => "(p.conf_id=? AND u.user_id=p.user_id)",
    name       => "(u.nick_name~*? OR (u.pseudonymous IS FALSE AND (u.first_name~*? OR u.last_name~*? OR (u.first_name || ' ' || u.last_name)~*?)))",
    full_name  =>  "(u.first_name || ' ' || u.last_name ~* ?)",
    # text search
    map( { ($_, "(u.$_~*?)") }
      qw( town company address nick_name ) ),
    # text egality
    map( { ($_, "(lower(u.$_)=lower(?))") }
      qw( first_name last_name) ),
    # user can have multiple entries in pm_group
    pm_group => "position(lower(?) in lower(u.pm_group)) > 0",
    # standard stuff
    map( { ($_, "(u.$_=?)") }
      qw( user_id session_id login email country ) )
);
our %sql_opts = ( 'order by' => 'user_id' );

*get_users = \&get_items;

sub get_items {
    my ($class, %args) = @_;

    if( $args{name} ) {
        $args{name} = Act::Util::search_expression( quotemeta( $args{name} ) );
        $args{name} =~ s/\\\*/.*/g;
    }

    return Act::Object::get_items( $class, %args );
}

sub rights {
    my $self = shift;
    return $self->{rights} if exists $self->{rights};

    # get the user's rights
    $self->{rights} = {};

    my $sth = sql(
                       'SELECT right_id FROM rights WHERE conf_id=? AND user_id=?',
                       $Request{conference}, $self->user_id
                      );
    $self->{rights}{$_->[0]}++ for @{ $sth->fetchall_arrayref };
    $sth->finish;

    return $self->{rights};
}

# generate the is_right methods
for my $right (@Rights) {
    no strict 'refs';
    *{"is_$right"} = sub { $_[0]->rights()->{$right} };
}

# This are pseudo fields!
sub full_name {
    ( $_[0]->first_name || '' ) . ' ' . ( $_[0]->last_name || '' );
}

sub country_name { Act::Country::CountryName( $_[0]->country ) }

sub public_name {
    return $_[0]->pseudonymous ? $_[0]->nick_name
         : $_[0]->first_name." ".$_[0]->last_name;
}


sub bio {
    my $self = shift;
    return $self->{bio} if exists $self->{bio};

    # fill the cache if necessary
    my $sth = sql("SELECT lang, bio FROM bios WHERE user_id=?", $self->user_id );
    $self->{bio} = {};
    while( my $bio = $sth->fetchrow_arrayref() ) {
        $self->{bio}{$bio->[0]} = $bio->[1];
    }
    $sth->finish();
    return $self->{bio};
}

sub md5_email {
    my $self = shift;
    return $self->{md5_email} ||= md5_hex( lc $self->email );
}

sub talks {
    my ($self, %args) = @_;
    return Act::Talk->get_talks( %args, user_id => $self->user_id );
}

sub register_participation {
  my ( $self ) = @_;

  my $tshirt_size = Act::Data::tshirt_size( $self->user_id );
  # create a new participation to this conference
  Act::Data::register_participation(
      $Request{conference},$self->user_id,
      $Request{r}->address, $tshirt_size
  );
}

sub participation {
    my ( $self ) = @_;
    return Act::Data::participation($Request{conference},$self->user_id);
}

sub my_talks {
    my ($self) = @_;
    return $self->{my_talks} if $self->{my_talks};
    my $talk_ids = Act::Data::my_talk_ids($Request{conference},
                                       $self->user_id);
    my @my_talks = map { Act::Talk->new( talk_id => $_) } @$talk_ids;
    return $self->{my_talks} = \@my_talks;
}

sub update_my_talks {
    my ($self, @talks) = @_;

    my %ids     = map { $_->talk_id => 1 } @talks;
    my %current = map { $_->talk_id => 1 } @{ $self->my_talks };

    # remove talks
    my @remove = grep { !$ids{$_} }     keys %current;
    my @add    = grep { !$current{$_} } keys %ids;
    Act::Data::update_my_talks($Request{conference},$self->user_id,
                               \@remove,\@add);

    $self->{my_talks} = [ grep $_->accepted, @talks ];
}

sub is_my_talk {
    my ($self, $talk_id) = @_;
    return first { $_->talk_id == $talk_id } @{ $self->my_talks };
}

sub attendees {
    my ($self, $talk_id) = @_;
    my $user_ids = Act::Data::attendees($Request{conference},$talk_id);
    return [ map Act::User->new( user_id => $_ ), @$user_ids ];
}

# some data related to the visited conference (if any)
sub has_talk {
    my $self = shift;
    return $self->{has_talk}  if  exists $self->{has_talk};
    my $has_talk = Act::Data::has_talk($Request{conference},$self->user_id);
    $self->{has_talk} = $has_talk;
    return $has_talk;
}

sub has_accepted_talk {
    my $self = shift;
    return $self->{has_accepted_talk}
        if  exists $self->{has_accepted_talk};
    my $has_accepted_talk = Act::Data::has_accepted_talk(
        $Request{conference},$self->user_id);
    $self->{has_accepted_talk} = $has_accepted_talk;
    return $has_accepted_talk;
}

sub has_paid {
    my $self = shift;
    return $self->{has_paid} if $self->{has_paid};
    my $has_paid = Act::Data::has_paid(
        $Request{conference},$self->user_id);
    $self->{has_paid} = $has_paid;
    return $has_paid;
}

sub has_registered {
    my $self = shift;
    return $self->{has_registered} if $self->{has_registered};
    my $has_registered = Act::Data::has_registered(
        $Request{conference},$self->user_id);
    $self->{has_registered} = $has_registered;
    return $has_registered;
}

sub has_attended {
    my $self = shift;
    return $self->{has_attended} if $self->{has_attended};
    my $has_attended = Act::Data::has_attended(
        $Request{conference},$self->user_id);
    $self->{has_attended} = $has_attended;
    return $has_attended;
}

sub committed {
    my $self = shift;
    return $self->has_paid
        || $self->has_attended
        || $self->has_accepted_talk
        || $self->is_staff
        || $self->is_users_admin
        || $self->is_talks_admin
        || $self->is_news_admin
        || $self->is_wiki_admin;
}

sub participations {
     return Act::Data::participations($_[0]->user_id);
}

sub conferences {
    my $self = shift;

    # all the Act conferences
    my %confs;
    for my $conf_id (keys %{ $Config->conferences }) {
        next if $conf_id eq $Request{conference};
        my $cfg = Act::Config::get_config($conf_id);
        $confs{$conf_id} = {
            conf_id => $conf_id,
            url     => $cfg->general_full_uri,
            name    => $cfg->name->{$Request{language}},
            begin   => format_datetime_string( $cfg->talks_start_date ),
            end     => format_datetime_string( $cfg->talks_end_date ),
            participation => 0,
            # opened => ?
        };
    }
    # add this guy's participations
    my $now = DateTime->now;
    for my $conf (grep { $_->{conf_id} ne $Request{conference} }
               @{$self->participations()} )
    {
        my $c = $confs{$conf->{conf_id}};
        my $p = \$c->{participation};
        if( $c->{end} < $now )       { $$p = 'past'; }
        elsif ( $c->{begin} > $now ) { $$p = 'future'; }
        else                         { $$p = 'now'; }
    }

    return [ sort { $b->{begin} <=> $a->{begin} } values %confs ]
}

sub create {
    my ($class, %args)  = @_;
    $class = ref $class || $class;
    $class->init();

    my $part = delete $args{participation};
    my $password = delete $args{password};
    $args{passwd} = $class->_crypt_password($password)
        if defined $password;
    my $user = $class->SUPER::create(%args);
    if ($user && $part && $Request{conference}) {
        Act::Data::register_user($Request{conference}, $user->{user_id});
    }
    return $user;
}

sub update {
    my ($self, %args) = @_;
    my $class = ref $self;

    my $part = delete $args{participation};
    my $bio  = delete $args{bio};
    $self->SUPER::update(%args) if %args;
    if ($part && $Request{conference}) {
        delete $part->{$_} for qw(conf_id user_id);
        my $SQL = sprintf 'UPDATE participations SET %s WHERE conf_id=? AND user_id=?',
                          join(',', map "$_=?", keys %$part);
        my $sth = sql( $SQL, values %$part, $Request{conference}, $self->{user_id} );
        $Request{dbh}->commit;
    }
    if( $bio ) {
        my @SQL =
        (
            "SELECT 1 FROM bios WHERE user_id=? AND lang=?",
            "UPDATE bios SET bio=? WHERE user_id=? AND lang=?",
            "INSERT INTO bios ( bio, user_id, lang) VALUES (?, ?, ?)",
        );
        my @sth = map sql_prepare($_), @SQL;
        for my $lang ( keys %$bio ) {
            sql_exec( $sth[0], $SQL[0], $self->user_id, $lang );
            if( $sth[0]->fetchrow_arrayref ) {
                sql_exec(  $sth[1], $SQL[1], $bio->{$lang}, $self->user_id, $lang );
            }
            else {
                sql_exec( $sth[2], $SQL[2],  $bio->{$lang}, $self->user_id, $lang );
            }
            $sth[0]->finish;
            $Request{dbh}->commit;
        }
    }
}

sub possible_duplicates {
    my ($self) = @_;
    my %seen = ( $self->user_id => 1 );
    my @twins;

    for my $attr (qw( login email nick_name full_name last_name )) {
        push @twins, grep { !$seen{ $_->user_id }++ }
            map {@$_}
            Act::User->get_items(
                $attr => map { s/([.*(){}^\$?])/\\$1/g; $_ } $self->$attr()
            )
            if $self->$attr();
    }
    $_->most_recent_participation() for @twins;

    @twins = sort { $a->user_id <=> $b->user_id } @twins;

    return \@twins;
}

sub most_recent_participation {
    my ($self) = @_;

    # get all participations
    my $participations = $self->participations;

    # prefer current conference
    my $chosen = first { $_->{conf_id} eq $Request{conference} } @$participations;
    unless ($chosen) {
        # if no participation date, use conference start date instead
        for my $p (@$participations) {
            $p->{datetime} ||= Act::Config::get_config($p->{conf_id})->talks_start_date;
        }
        # sort participations in reverse chronological order
        my @p = sort { $b->{datetime} cmp $a->{datetime} } @$participations;

        # choose most recent participation
        $chosen = $p[0];
    }
    # add url information
    $chosen->{url} = Act::Config::get_config($chosen->{conf_id})->general_full_uri
        if $chosen->{conf_id};
    $self->{most_recent_participation} = $chosen;
}

sub set_password {
    my ($self, $password) = @_;
    $self->update(passwd => $self->_crypt_password($password));
    return 1;
}

sub check_password {
    my ($self, $pass) = @_;

    my $ppr = eval { Authen::Passphrase->from_rfc2307($self->{passwd}); };
    return 1 if $ppr && $ppr->match($self->_sha_pass($pass));
    return 1 if $self->_check_legacy_password($pass);
    die 'Bad password';
}


sub _sha_pass {
    my ($self, $pass) = @_;
    return sha512(encode('UTF-8',$pass,Encode::FB_CROAK));
}

sub _crypt_password {
    my ($self, $pass) = @_;

    my $ppr = Authen::Passphrase::BlowfishCrypt->new(
        cost        => 8,
        salt_random => 1,
        passphrase  => $self->_sha_pass($pass),
    );
    return $ppr->as_rfc2307;
}

sub _check_legacy_password {
    my ($self, $check_pass) = @_;
    my $pw_hash = $self->{passwd};
    my ($scheme, $hash) = $pw_hash =~ /^(?:{(\w+)})?(.*)$/;

    if (!$scheme || $scheme eq 'MD5') {
        my $ok = try {
            my $digest = Digest::MD5->new;
            $digest->add($check_pass); # this dies from wide characters
            $digest->b64digest eq $hash;
        } catch {
            0; # a failed digest can be safely mapped to "bad password"
        };
        $ok && $self->set_password($check_pass); # upgrade hash
        return $ok;
    }
    else {
        my $check_hash;
        try {
            $check_hash = $self->_crypt_legacy_password($check_pass);
        } catch {
            # [bcrypt] config vars aren't defined, so no bcrypt legacy
            $check_hash = '';
        };
        return 0 if $check_hash ne $pw_hash;
        # upgrade hash
        $self->set_password($check_pass);
        return 1;
    }
    return 0;
}

sub _crypt_legacy_password {
    my $class = shift;
    my $pass  = shift;
    my $cost  = $Config->bcrypt_cost;
    my $salt  = $Config->bcrypt_salt;

    if (!$cost || !$salt) {
        die "Unable to continue, need cost and salt configured in [bcrypt]";
    }

    return '{BCRYPT}'
        . Crypt::Eksblowfish::Bcrypt::en_base64(
        Crypt::Eksblowfish::Bcrypt::bcrypt_hash(
            {
                key_nul => 1,
                cost    => $cost,
                salt    => $salt,
            },
            $pass
        )
        );
}

1;

__END__

=head1 NAME

Act::User - A user object for the Act framework

=head1 DESCRIPTION

This is a standard Act::Object class. See Act::Object for details.

A few methods have been added.

=head2 Methods

=over 4

=item rights()

Returns a hash reference which keys are the rights awarded to the
user. Lazy loading is used to fetch the data from the database only
if necessary. The data is then cached for the duration of the request.

=item is_I<right>()

Returns a boolean value indicating if the current user has the corresponding
I<right>. These convenience methods are autoloaded.

=back

=head2 Class methods

Act::User also defines the following class methods:

=over 4

=item get_users( %req )

Same as get_items(), except that C<conf_id> can be used to JOIN the users
on their participation to specific conferences.

=item talks( %req )

Return a reference to an array holding the user's talks that match
the request criterion.

=item participation

Return a hash reference holding the user data related to the current
conference.

=back

=cut

