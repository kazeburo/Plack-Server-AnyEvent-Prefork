use inc::Module::Install;
name 'Plack-Server-AnyEvent-Prefork';
all_from 'lib/Plack/Server/AnyEvent/Prefork.pm';

# requires '';

tests 't/*.t';
author_tests 'xt';

requires 'Plack::Server::AnyEvent' => 0.03;
requires 'Parallel::Prefork';
requires 'Guard';
requires 'Try::Tiny';
requires 'Time::HiRes';
build_requires 'Test::More';
use_test_base;
auto_include;
WriteAll;
