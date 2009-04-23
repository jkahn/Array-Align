#!perl -T

use Test::More tests => 2;

BEGIN {
	use_ok( 'Array::Align' );
}

diag( "Testing Array::Align $Array::Align::VERSION, Perl $], $^X" );

my $aligner = StringMatch->new(left => [ qw(a b c d e) ],
			       right => [ qw( b d e ) ]);
ok(defined $aligner, "string match defined");
ok($aligner->cost == 3, 'string cost correct');

package StringMatch;
use base 'Array::Align';

sub weighter {
  my ($self, $left, $right) = @_;
  return 1 if not defined $left;
  return 1 if not defined $right;
  return 1 if $left ne $right;
  return 0;
}
