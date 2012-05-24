package Plack::Server::AnyEvent::Prefork::SS;

use strict;
use warnings;
use parent qw(Plack::Server::AnyEvent::Prefork);
use Server::Starter qw//;
use AnyEvent;
use AnyEvent::Util qw(fh_nonblocking guard);
use AnyEvent::Socket qw(format_address);
use IO::Socket::INET;

# This code is stolen from Plack::Server::AnyEvent::Server::Starter
sub _create_tcp_server {
    my ( $self, $app ) = @_;

    my ($hostport, $fd) = %{Server::Starter::server_ports()};
    if ($hostport =~ /(.*):(\d+)/) {
        $self->{host} = $1;
        $self->{port} = $2;
    } else {
        $self->{host} ||= '0.0.0.0';
        $self->{port} = $hostport;
    }

    $self->{prepared_host} = $self->{host};
    $self->{prepared_port} = $self->{port};

    # /WE/ don't care what the address family, type of socket we got, just    # create a new handle, and perform a fdopen on it. So that part of
    # AE::Socket::tcp_server is stripped out

    my %state;
    $state{fh} = IO::Socket::INET->new(
        Proto => 'tcp',
        Listen => 128, # parent class returns, zero, so set to AE::Socket's default
    );

    $state{fh}->fdopen( $fd, 'w' ) or
        Carp::croak "failed to bind to listening socket: $!";
    fh_nonblocking $state{fh}, 1;

    my $accept = $self->_accept_handler($app);
    $state{aw} = AE::io $state{fh}, 0, sub {
        # this closure keeps $state alive
        while ($state{fh} && (my $peer = accept my $fh, $state{fh})) {
            fh_nonblocking $fh, 1; # POSIX requires inheritance, the outside world does not

            my ($service, $host) = AnyEvent::Socket::unpack_sockaddr($peer);
            $accept->($fh, format_address $host, $service);
        }
    };

    warn "Accepting requests at http://$self->{host}:$self->{port}/\n";
    defined wantarray
        ? guard { %state = () } # clear fh and watcher, which breaks the circular dependency
        : ()
}

1;

__END__

=head1 NAME

Plack::Server::AnyEvent::Prefork::SS - Prefork AnyEvent based HTTP Server 

=head1 SYNOPSIS

   % start_server --port=80 -- plackup -s AnyEvent::Prefork::SS

=head1 AUTHOR

kazeburo E<lt>kazeburo {at} gmail.comE<gt>

=head1 SEE ALSO

L<Plack>, L<Plack::Server::AnyEvent>, L<Plack::Server::AnyEvent::Server::Starter>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

