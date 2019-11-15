package Test::Act::SMTP::Server;
# ABSTRACT: A minimal SMTP server for automated Act tests

use Moo;
with 'MooX::Singleton';
use Types::Standard qw(Ref Int);

use Data::Dump qw(dump);
use IO::Socket::INET;
use Time::HiRes;
use Try::Tiny;

# This is almost the same as using the modules, but just skips tests
# instead of dying of the modules are not available, and the modules
# are not picked up as required by dzil's [AutoPrereqs] plugin.
use Test::Needs 'Net::Server::Mail::SMTP', 'Time::Out';

use feature qw(signatures);
no warnings qw(experimental::signatures);

########################################################################

has pid => (
    is => 'rwp', isa => Int,
    documentation =>
        'The child pid, for cleanup purposes',
);

has port => (
    is => 'rwp', isa => Int,
    documentation =>
        'The local port of the SMTP server',
);

has pipe => (
    is => 'rwp', isa => Ref,
    documentation =>
        'The handle for interprocess communication',
);

# ----------------------------------------------------------------------
# BUILD - Moo infrastructure - "finish" creating the object
# This routine forks our SMTP server by reading from a safe pipe.
# The child starts listening on the server port and will continue until
# it receives a QUIT signal from the parent, which sends it when the
# object goes out of scope.
sub BUILD ($self,$) {
    my $pipe;
    my $pid = open ($pipe, '-|');
    defined $pid or die "Failed to fork: '$!'";

    if ($pid) {
        Time::Out::timeout(
            0.01,
            sub {
                if (defined (my $port = <$pipe>)) {
                    # Child sent the port
                    chomp $port;
                    $port !~ /\D/  or  die $port;
                    $self->_set_pid($pid);
                    $self->_set_pipe($pipe);
                    $self->_set_port($port);
                }
                else {
                    _terminate_smtp_server($pid);
                    die __PACKAGE__, ": SMTP server closed connection\n";
                }
            });
        if ($@) {
            _terminate_smtp_server($pid);
            die __PACKAGE__, ": SMTP server not responding\n";
        }
    }
    else {
        # child - Start the server
        my $server = IO::Socket::INET->new( Listen => 1,
                                            LocalPort => 0,
                                            ReuseAddr => 1,
                                          );
        if (! $server) {
            print __PACKAGE__, ": Could not create a socket: '$!'\n";
            exit(126);
        }
        my $port = $server->sockport;
        # Tell parent that all is fine and provide the port
        print "$port\n";

        # Loop forever... or until parent gives us a signal
        my $continue = 1;
        $SIG{QUIT} = sub { $server->close; exit(0); };
        my $conn;
        while($continue and $conn = $server->accept) {
            my $smtp = Net::Server::Mail::SMTP->new( socket => $conn )
                or croak("Unable to create the server: $!\n");
            $smtp->set_callback(DATA => \&queue_message);
            $smtp->process;
            $conn->close;
        }
        exit (0);
    }
}


# ######################################################################
# _terminate_smtp_server - Terminate the child (SMTP server) peacefully
# and reap the child
sub _terminate_smtp_server ($pid) {
    kill 'QUIT',$pid;
    waitpid $pid,0;
}

# ----------------------------------------------------------------------
# DEMOLISH - Moo infrastructure - called when the object is destroyed
# This routine signals the child process to terminate.
sub DEMOLISH ($self,$) {
    if (my $pid = $self->pid) {
        kill 'QUIT',$pid;
        waitpid $pid,0;
    }
}

# ----------------------------------------------------------------------

sub next_mail ($self) {
    my $pipe = $self->pipe;
    my $data = Time::Out::timeout(
        0.01,
        sub {
            my $data;
            while (defined (my $line = <$pipe>)) {
                last if $line =~ /^# Done!/;
                $data .= $line;
            }
            return $data;
        }
    );
    if ($@) {
        warn "No mail yet\n";
        return;
    }
    return eval $data;
}


# ======================================================================
# Child / SMTP server routines (not user servicable)

# ----------------------------------------------------------------------
# queue_message - callback for Net::Server::Mail::SMTP
# This is the "DATA" callback given to Net::Server::Mail::SMTP.
# It receives the session and a scalar reference containing the data.
# Our handler here simply prints a serialized hash reference to STDOUT,
# from where the parent process will pick it up by reading from its pipe.
# Serialization is done, quick and dirty, with Data::Dump.
sub queue_message ($session, $data) {
    my $sender     = $session->get_sender();
    my @recipients = $session->get_recipients();

    return(0, 554, 'Error: no valid recipients')
        unless(@recipients);

    my $dump = {
        from    => $sender,
        to      => [ @recipients ],
        message => $$data,
    };
    $| = 1;
    print dump $dump;
    print "\n# Done!\n";

    return(1, 250, "message queued");
}

1;

__END__

=encoding utf8

=head1 NAME

Test::Act::SMTP::Server - A primitive mock SMTP server

=head1 SYNOPSIS

  use Test::Lib;
  use Test::WhateverModuleYouNeed;
  use Act::Config;
  use Test::Act::SMTP::Server;
  my $server;
  BEGIN {
      $server = Test::Act::SMTP::Server->instance;
      $Config->set(email_hostname => 'localhost');
      $Config->set(email_port     => $server->port);
      # or, alternatively for the previous two lines:
      # $ENV{SMTP_HOST} = 'localhost';
      # $ENV{SMTP_PORT} = $server->port;
  }

  # run a test which sends a mail
  Act::Email::send( to => 'attendee@example.org',
                    from => 'me@home.net',
                    ....
                  );

  # fetch and examine the mail
  my $mail = $server->next_mail();
  is($mail->{from}, 'me@home.net');
  is($mail->{to}[0],'attendee@example.org');

=head1 DESCRIPTION

This module allows to run automated workflow tests where Act sends out
a mail and an Act user needs to react to this mail.  It is
non-intrusive with regard to any "real" SMTP service you might be
running on the test machine and has no risk of any delays by a mail
transport system.

The module does not actually send mails, regardless or recipient
address.  Instead it provides them, one by one, to test scripts via
the C<next_mail> method.

The SMTP service choses its own unique port which you need to query
with the C<port> method.  You can not set the port from the outside,
but you can safely run several tests using this module in parallel
since every invocation choses its own port.

The SMTP service runs as a separate process which talks back to the
test script using safe pipes.  The process is killed and reaped when
the server object goes out of scope.

=head1 METHODS

=head2 $server = Test::Act::SMTP::Server->instance;

Returns the server object, or dies if it can not be created.

=head2 $smtp_port = $server->port

Returns the port on which this server listens.  You must configure
your email client to use this port.

=head2 $hashref = $server->next_mail

Returns the next mail from the SMTP server as a hash reference, or
undef if no mail has been received yet.

The hash contains the following keys:

=over

=item from - the mail address of the sender

=item to - an array reference of mail addresses of recipients

=item message - the full message text, including headers.

=back

=cut

=head2 Internal Methods

=head3 $pid = $server->pid

Returns the process id of the SMTP server process.

=head1 DIAGNOSTICS

If the server fails to fork or to listen on its port, then it just
dies, providing the error given by the system.

=head1 ENVIRONMENT

The server does not evaluate Act's environment variables C<SMTP_HOST>
and C<SMTP_PORT>.  It always operates on localhost and choses its own
port.

If your environment sets these variables but you still want to use
this module to capture email then you need to change them to
C<'localhost'> and C<$server->port> in your test scripts because in
L<Act::Email> environment variables take precedence over configuration
variables.

=head1 CAVEATS

Creation of the mock server needs to be done in a BEGIN block because
L<Act::Email> creates its client (hence evaluates the port) during
compilation.

=head1 RESTRICTIONS

This module needs the CPAN modules L<Net::Server::Mail::SMTP> and
L<Time::Out>.  If they are not installed, then all tests in a script
using this modules will be skipped.

=head1 AUTHOR

Harald Jörg, haj@posteo.de

Thanks to the folks hanging out at #toolchain for valuable hints.

=head1 COPYRIGHT AND LICENSE

Copyright 2019 Harald Jörg

This library is free software; you may redistribute it and/or
modify it under the same terms as Perl itself.
