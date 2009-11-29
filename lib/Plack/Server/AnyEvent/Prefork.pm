package Plack::Server::AnyEvent::Prefork;

use strict;
use warnings;
use parent qw(Plack::Server::AnyEvent);
use Parallel::Prefork;
use Guard;
use Try::Tiny;
use Time::HiRes;

our $VERSION = '0.01';

sub new {
    my($class, %args) = @_;
    my $self = $class->SUPER::new(%args);
    $self->{max_workers} = $args{max_workers} || 10;
    $self->{max_reqs_per_child} = $args{max_reqs_per_child} || 100;
    $self->{header_read_timeout} = $args{header_read_timeout} || 180;
    $self;
}

sub _create_req_parsing_watcher {
    my ( $self, $sock, $try_parse, $app ) = @_;

    my $headers_io_watcher;
    my $io_failed = guard {
        #warn "$$ I/O failed";
        undef $headers_io_watcher;
        try { $self->{exit_guard}->end; $sock->close };
    };

    my $header_timeout = $self->{header_read_timeout} || 5;
    my $timeout = AE::timer $header_timeout, 0, sub {
        #warn "I/O timeout";
        undef $io_failed; # fire the guard
    };

    # called repeatedly until undef'd:
    $headers_io_watcher = AE::io $sock, 0, sub {
        try {
            if ( my $env = $try_parse->() ) {
                undef $headers_io_watcher;
                undef $timeout;
                $io_failed->cancel();
                $self->_run_app($app, $env, $sock);
            }
        } catch {
            undef $headers_io_watcher;
            undef $timeout;
            $io_failed->cancel();
            $self->_bad_request($sock);
        }
    };
}

sub _accept_handler {
    my $self   = shift;
    my $app    = shift;
    
    my $cb = $self->SUPER::_accept_handler( $app );

    return sub {
        my ( $sock, $peer_host, $peer_port ) = @_;
        $self->{reqs_per_child}++;
        $cb->( $sock, $peer_host, $peer_port );

        if ( $self->{reqs_per_child} > $self->{max_reqs_per_child} ) {
            #warn "[$$] reach max reqs per child";
            my $listen_guard = delete $self->{listen_guard};
            undef $listen_guard;    #block new accept
            $self->{exit_guard}->end;
        }
    };
}

sub run {
    my($self, $app) = @_;
    $self->register_service($app);
    my $pm = Parallel::Prefork->new({
        max_workers => $self->{max_workers},
        trap_signals => {
            TERM => 'TERM',
            HUP  => 'TERM',
        },
    });
    while ($pm->signal_received ne 'TERM') {
        $pm->start and next;
        #warn "[$$] start";
        my $exit = $self->{exit_guard} = AnyEvent->condvar;
        $exit->begin;
        my $w; $w = AE::signal TERM => sub { $exit->end; undef $w };
        $exit->recv;
        #warn "[$$] finish";
        $pm->finish;
    }
    $pm->wait_all_children;
}


1;
__END__

=head1 NAME

Plack::Server::AnyEvent::Prefork - Prefork AnyEvent based HTTP Server

=head1 SYNOPSIS

  use Plack::Server::AnyEvent::Prefork;

  my $server = Plack::Server::AnyEvent::Prefork->new(
      host => $host,
      port => $port,
      max_workers => $n,
      max_reqs_per_child => $n,
  );
  $server->run($app);

=head1 AUTHOR

kazeburo E<lt>kazeburo {at} gmail.comE<gt>

=head1 SEE ALSO

L<Plack>, L<Plack::Server::AnyEvent>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
