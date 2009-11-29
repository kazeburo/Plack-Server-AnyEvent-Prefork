use inc::Module::Install;
name 'Plack-Server-AnyEvent-Prefork';
all_from 'lib/Plack/Server/AnyEvent/Prefork.pm';

# requires '';

tests 't/*.t';
author_tests 'xt';

build_requires 'Test::More';
use_test_base;
auto_include;
WriteAll;
