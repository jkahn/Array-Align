#!perl

use Test::More tests => 2;

use FindBin qw($Bin);
open my $lfh, "<", "$Bin/left.txt"
  or die "couldn't load $Bin/left.txt: $!\n";
open my $rfh, "<", "$Bin/right.txt"
  or die "couldn't load $Bin/right.txt: $!\n";

my @left = <$lfh>;
chomp @left;
my @right = <$rfh>;
chomp @right;

$StringMatch::weight_counts = 0;
my $aligner = StringMatch->new(left => \@left,
			       right => \@right);
ok(defined $aligner, "string match defined");
ok($aligner->penalty == 3, 'string cost correct');  # two substitutions
warn "used $StringMatch::weight_counts counts";


# $StringMatch::weight_counts = 0;
# $aligner = StringMatch->new(left => [ qw(a b c d e) ],
# 			       right => [ qw(a a b d e f) ]);
# ok(defined $aligner, "string match defined");
# ok($aligner->cost == 3, 'string cost correct');
# warn "used $StringMatch::weight_counts counts";


package StringMatch;
use base 'Array::Align';

our $weight_counts;

# sub admissible_heuristic {
#   return 0;
# }

sub weighter {
  my ($self, $left, $right) = @_;
  $weight_counts++;
  return 1 if not defined $left;
  return 1 if not defined $right;
  return 1.5 if $left ne $right;
  return 0;
}
