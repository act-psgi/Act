package Act::Store::Database;
# ABSTRACT: Use relational databases as store for Act data

use DBIx::Connector;
use Try::Tiny;

use Act::Config (); # Let's stick to that for the moment
                    # but do not use the exports
use Act::Database;  # Will at some point be merged into this module

use Moo;
use Types::Standard qw(InstanceOf);

# ======== Class Variables =============================================
my $db_singleton;


# ======== Attributes ==================================================
has connector => (
    is => 'ro', isa => InstanceOf['DBIx::Connector'],
    lazy => 1,
    builder => '_build_connector',
    documentation =>
        '',
);

# -------- Attribute helpers -------------------------------------------
sub _build_connector {
    my $self = shift;
    my $Config = $Act::Config::Config;
    my $dsn = $Config->database_dsn;
    if ($Config->database_host) {
        $dsn .= ";host=" . $Config->database_host;
    }

    my $connector = DBIx::Connector->new(
        $dsn,
        $Config->database_user,
        $Config->database_passwd,
        { AutoCommit => 0,
          PrintError => 0,
          RaiseError => 1,
          pg_enable_utf8 => 1,
        }
    );
    $connector->mode('fixup');

    return $connector;
}

=head1 METHODS

=cut


# ======== Singleton definition and helpers ============================

=head2 $db = instance(@args)

Returns the instance of the database store, or dies on failure.

=cut

sub instance {
    my $class = shift;
    return $db_singleton // $class->_init(@_);
}

# _init
#   Purpose: Initializes (or overwrites) the singleton.
sub _init {
    my $class = shift;
    $db_singleton = $class->new(@_);
    $db_singleton->_check_db_version();
    return $db_singleton;
}

# _clear_instance
#   Purpose: Deletes the singleton.  For testing purposes only.
sub _clear_instance {
    undef $db_singleton;
}

# _check_db_version
#   Purpose: Make sure that the code understands the database schema.
sub _check_db_version {
    my $self = shift;
    my $current_version = $self->get_schema_version();
    my $required_version = Act::Database::required_version;
    if ($current_version > $required_version) {
        die "database schema version $current_version is too recent: " .
            "this code runs version $required_version\n";
    }
    if ($current_version < $required_version) {
        die "database schema version $current_version is too old: " .
            "version $required_version is required. Run bin/dbupdate\n";
    }
}

# ======== Data Manipulation Methods ===================================

=head2 Database Metadata

=head3 $version = $db->get_schema_version()

Returns the schema version as provided by the database.  Dies if the
version can't be retrieved.

=cut

sub get_schema_version {
    my $self = shift;
    my $current_version = try {
        $self->connector->run(
            sub {
                $_->selectrow_array('SELECT current_version FROM schema');
            }
        );
    } catch {
        die "Failed to retrieve the schema version:\n",
            "DB error:   '", DBI->errstr, "'\n",
            "eval error: '$_'";
    };
}


=head2 Methods for the Authentication Service

=cut

# ----------------------------------------------------------------------

=head2 Method get_login_password

Obtains the (properly encrypted) login password of a user.

=cut

sub get_user_password {
    my $self = shift;
    my ($login) = @_;

    my $sql = 'SELECT passwd FROM users WHERE login = ?';
    my $pw_hash = $self->connector->run(
        sub {
            my $sth = $_->prepare_cached($sql);
            $sth->execute($login);
            my $pw_hash = $sth->fetchrow_array;
            $sth->finish;
            return $pw_hash;
        }
    );
    return $pw_hash;
}


# ----------------------------------------------------------------------

=head2 Method set_user_password

Stores a (properly encrypted) login password for a user.

=cut

sub set_user_password {
    my $self = shift;
    my ($pw_hash) = @_;

    my $sql = 'UPDATE users SET passwd WHERE login = ?';
    my $success = $self->connector->run(
        sub {
            my $sth = $_->prepare_cached($sql);
            $sth->execute($pw_hash);
        }
    )
}

1;

__END__

=encoding utf8

=head1 NAME

Act::Store::Database - Use relational databases as store for Act data

=head1 SYNOPSIS

  $db             = Act::Store::Database->instance;
  $schema_version = $db->get_schema_version;

=head1 DESCRIPTION

This class represents the database which stores Act data as a
singleton.  All operations Act needs to perform on a persistent store
are available as method calls against this singleton.

Or, to be precise: They I<will> be available, at some point in the
future.  During the course of refurbishment this singleton will live
happily together with the traditional C<$Request{dbh}> used by legacy
Act software.

=head1 DIAGNOSTICS

In case of error, methods of this class just die.

=head1 ENVIRONMENT

No environment variables are evaluated yet.  Sorry, dockers!

=head1 FILES

The code relies on the C<$Act::Config::Config> object which reads its
database connection parameters from the global F<act.ini> file.

=head1 CAVEATS

This code hasn't been seriously tested in real life and covers only a
tiny part of Act's database actions.

=cut

# =head1 RESTRICTIONS

# =head1 NOTES

=head1 AUTHOR

Harald Jörg, haj@posteo.de

=head1 COPYRIGHT AND LICENSE

Copyright 2019 Harald Jörg

This library is free software; you may redistribute it and/or
modify it under the same terms as Perl itself.
