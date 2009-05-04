package Array::Align;

use warnings;
use strict;

use Carp;

=head1 NAME

Array::Align - best-first search for good alignments between arrays,
built from a search across small operations (zero or one steps on each
array).

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';
our $VERBOSE = 0;  # while building

=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    package Aligner;
    use base 'Array::Align';
    sub weighter {
      # implement this
    }

elsewhere

    my $aligner = Aligner->new(left => \@left, right => \@right);
    for my $pair ($aligner->pairwise) {
      my ($left, $right) = @$pair;
    }
    ...

=head1 CLASS METHODS

=over

=item new()

=cut

sub new {
  my ($class, %args) = @_;
  # check args
  my $left = $args{left};
  croak "no left arg defined to $class->new"
    unless defined $left;
  croak "left arg to $class->new not an arrayref"
    unless ref $left eq 'ARRAY';

  my $right = $args{right};
  croak "no right arg defined to $class->new"
    unless defined $right;
  croak "right arg to $class->new not an arrayref"
    unless ref $right eq 'ARRAY';

  warn scalar (@$right) . " items in right\n" if $VERBOSE;
  warn scalar (@$left) . " items in left\n" if $VERBOSE;

  my $self = bless \%args, $class;
  if ($self->can('init')) {
    $self->init();
  }

  my ($best) = $self->_search(nbest => 1);
  $self->{best} = $best;
  return $self;
}

sub _search {
  my ($self, %args) = @_;
  my $nbest = $args{nbest};
  if (not defined $nbest) {
    croak "_search method needs nbest";
  }
  my $init = Array::Align::Step->anchor (owner => $self);

  my %best_costs;

  use Heap::Simple;
  my $heap = Heap::Simple->new(elements =>[Object => 'heuristic_cost'],
			       order => '<');
  $heap->insert($init);

  my @solutions;

  while (@solutions < $nbest) {
    my $best = $heap->extract_first();
    last if (not defined $best);  # no more candidates

    my $heuristic = $best->heuristic_cost();

    if (defined $best_costs{$best->{lidx}}{$best->{ridx}} and
	$best_costs{$best->{lidx}}{$best->{ridx}} <= $heuristic) {
      next;
    }


    $best_costs{$best->{lidx}}{$best->{ridx}} = $heuristic;
    if ($VERBOSE > 1) {
      warn "left: $best->{lidx}/$#{$self->{left}} " .
	"right: $best->{ridx}/$#{$self->{right}} : " .
	  sprintf ("%3f (%3f)", $best->penalty(), $heuristic ). "\n";
    }

    if ($best->is_finished()) {
      push @solutions, $best;
      next;
    }

    my @next = $best->grow();

    for my $cand (@next) {
      if (defined $best_costs{$cand->{lidx}}{$cand->{ridx}} and
	  $cand->heuristic_cost > $best_costs{$cand->{lidx}}{$cand->{ridx}}) {
	next;
      }
      $heap->insert($cand);
    }
  }
  return @solutions;
}

=back

=head1 INSTANCE METHODS

=over

=item pairwise()

returns the pairs ([l,r])*

=cut

sub pairwise {
  my ($self, %args) = @_;
  my $best = $self->{best};
  return $best->pairs();
}

=item costs()

returns the costs corresponding to the pairs

=cut

sub costs {
  my ($self, %args) = @_;
  my $best = $self->{best};
  return $best->costs();
}

=item penalty()

=item weight()

two alternative names for the same method.  returns the cumulative
cost (beyond the shortest-path search) for the best path.

=cut

sub penalty {
  my ($self, %args) = @_;
  return $self->{best}->penalty() / $self->weight_scale() ;
}

sub weight { shift->penalty(@_) }

=back

=head1 CONTRACT PROGRAMMING

Methods that must be implemented by the subclass

=over

=item weighter

Provide an additional penalty for a given step. This penalty should be
scaled according to the cost of a single step (a sub, delete, or
insert).

If this method returns a uniform value, you have roughly the behavior
of C<paste>, which is not very interesting.  If it returns a large
value when both C<left> and C<right> are defined, then you will get a
manhattan walk (no diagonals).

Levenshtein behavior:

  sub weighter {
    my ($self, $left, $right) = @_;
    return 1 if not defined $left;
    return 1 if not defined $right;
    return 1.5 if $left ne $right;
    return 0;
  }

Note that this is an B<additional> penalty. Every step (diagonal or
not) has cost 1 plus the penalty returned by the C<weighter> method,
in order to find the shortest alignment first.

Because the number of steps is included (as mentioned above), the
approach will strongly prefer substitutions to singleton steps on
either direction.  If you have a pair that should receive a left-step
and right-step (insertion and deletion) rather than a diagonal
(substitution), make sure that:

  weighter(left, right) >
      weighter(left, undef) + weighter(undef, right) + 1/WEIGHT_SCALE

=item admissible_heuristic

Given two arguments:

=over

=item lidx

=item ridx

positions in the two streams

=back

must returns an underestimate of the remaining run-cost. the closer
the estimate to truth, the faster.  (the method can use at C<<
$self->{left} >> and C<< $self->{right} >> arrays if needed, though
modifying those arrays would break things, so don't.)

By default, the admissible heuristic is the max of number of right
cells remaining and number of left cells remaining -- this assumes
that the only cost to incur will be the step cost, that is, that
C<weighter> returns zero for every step, and the shortest path is
chosen.

If you implement this method, you should probably assume this as a
lower bound and then see if you can reliably increase this
underestimate.

=cut

sub admissible_heuristic {
  my $l_remaining = $#{$_[0]->{left}}  - $_[1];
  my $r_remaining = $#{$_[0]->{right}} - $_[2];

  if ($l_remaining > $r_remaining) {
    return $l_remaining;
  }
  return $r_remaining;
}

=item weight_scale

class value that moderates the relative weight of the C<penalty>
results to the steps.  Setting this to very large values will search
harder for better solutions rather than shorter ones. Setting it to
small values will tend to run faster but paths will prefer diagonals
and possibly miss longer, more optimal arrangements.

Default is

  sub weight_scale { return 1000; }

=cut

sub weight_scale { return 1000; }

=back

=head1 AUTHOR

Jeremy G. Kahn, C<< <kahn at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-array-align at
rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Array-Align>.  I will
be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Array::Align


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Array-Align>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Array-Align>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Array-Align>

=item * Search CPAN

L<http://search.cpan.org/dist/Array-Align>

=back


=head1 ACKNOWLEDGEMENTS


=head1 COPYRIGHT & LICENSE

Copyright 2009 Jeremy G. Kahn, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

#################################
# UTILITY CLASS Array::Align::Step
#
# represents a single step in the alignment.


package Array::Align::Step;
use strict;
use warnings;
use Carp;

sub new {
  my ($class) = shift;
  return bless {@_}, $class;
}
sub penalty { return $_[0]{penalty}; }

sub anchor {
  my $class = shift;
  my %args = @_;

  $args{lidx} = -1;
  $args{ridx} = -1;

  $args{parent} = undef;
  $args{anchor} = 1;
  $args{penalty} = 0;
  $args{num_step} = 0;
  return $class->new(%args);
}
sub grow {
  return (
	  $_[0]->take_step(1,1),
	  $_[0]->take_step(1,0),
	  $_[0]->take_step(0,1)
	 );
}

sub costs {
  my $self = shift;
  return map { $_->{incr_penalty} / $self->{owner}->weight_scale() } $self->path();
}

sub path {
  my $self = shift;
  my $cursor = $self;
  my @path;
  until ($cursor->{anchor}) {
    unshift @path, $cursor;
    $cursor = $cursor->{parent};
  }
  return @path;
}

sub pair {
  my $self = shift;
  return [
	  ($self->{left} ? $self->{owner}{left}[$self->{lidx}] : undef),
	  ($self->{right} ? $self->{owner}{right}[$self->{ridx}] : undef)
	 ];
}

sub pairs {
  my ($self, %args) = @_;

  return map {$_->pair()} $self->path();
}

sub heuristic_cost {
  if (not exists $_[0]->{_hcost}) {
    $_[0]->{_hcost} = $_[0]->{penalty} + $_[0]->{num_step} +
      $_[0]->{owner}->admissible_heuristic($_[0]->{lidx},
					   $_[0]->{ridx});
  }
  return $_[0]->{_hcost};
}

sub is_finished {
  return ($_[0]->{lidx} == $#{$_[0]->{owner}{left}}
	  and $_[0]->{ridx} == $#{$_[0]->{owner}{right}});
}

sub take_step {
  my ($self, $left, $right) = @_;
  my $class = ref $self;


  my $lidx = $self->{lidx} + $left;
  my $ridx = $self->{ridx} + $right;

  my $owner = $self->{owner};

  # no step possible if we're off the end of the lists
  return () if ($#{$owner->{left}}  < $lidx);
  return () if ($#{$owner->{right}} < $ridx);

  # only include a token if taking a step in that side
  my $left_tok  = $owner->{left}[$lidx] if $left;
  my $right_tok = $owner->{right}[$ridx] if $right;

  my $incr_penalty = $owner->weight_scale
    * $owner->weighter($left_tok, $right_tok);

  my $penalty = $self->{penalty} + $incr_penalty;

  return $class->new(lidx => $lidx, ridx => $ridx,
		     owner => $owner,
		     left => $left,
		     right => $right,
		     incr_penalty => $incr_penalty,
		     penalty => $penalty,
		     parent => $self,
		     num_step => ($self->{num_step} + 1));
}

1; # End of Array::Align
