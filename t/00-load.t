#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'Array::Align' );
}

diag( "Testing Array::Align $Array::Align::VERSION, Perl $], $^X" );
