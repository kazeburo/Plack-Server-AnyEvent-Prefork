use strict;
use Test::More tests => 2;

BEGIN { 
    use_ok 'Plack::Server::AnyEvent::Prefork';
    use_ok 'Plack::Server::AnyEvent::Prefork::SS';
 }
