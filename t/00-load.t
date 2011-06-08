#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'Bot::BasicBot::Pluggable::Module::BeerAccountancy' ) || print "Bail out!\n";
}

diag( "Testing Bot::BasicBot::Pluggable::Module::BeerAccountancy $Bot::BasicBot::Pluggable::Module::BeerAccountancy::VERSION, Perl $], $^X" );
