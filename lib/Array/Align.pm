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
our $VERBOSE = 1;  # while building

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
  my $init =
    Array::Align::Step->new(lidx => -1, ridx => -1,
			    owner => $self, parent => undef,
			    anchor => 1, # don't return this alignment
			    cost => 0,
			    );

  my %best_costs;

  use Heap::Simple;
  my $heap = Heap::Simple->new(elements =>[Method => 'heuristic_cost'],
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
	  sprintf ("%3f (%3f)", $best->cost, $heuristic ). "\n";
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

#     if (not @next) {
#       # must be finished
#       push @solutions, $best;
#     }
#     else {
#       $heap->insert(@next);
#     }
  }
  return @solutions;
}

=back

=head1 INSTANCE METHODS

=over

=item pairwise()

=cut

sub pairwise {
  my ($self, %args) = @_;
  my $best = $self->{best};
  return $best->pairs();
}

=item cost()

=cut

sub cost {
  my ($self, %args) = @_;
  return $self->{best}->cost;
}

=back

=head1 CONTRACT PROGRAMMING

Methods that must be implemented by the subclass

=over

=item weighter

=item admissible_heuristic

Given arguments:

=over

=item lidx

=item ridx

positions in the two streams

=back

must returns an underestimate of the remaining run-cost. the closer
the estimate to truth, the faster.  (the method can use at C<<
$self->{left} >> and C<< $self->{right} >> arrays if needed, though
modifying those arrays would break things, so don't.)

By default, the admissible heuristic is the number of non-diagonal
cells remaining, minus 1 for safety.  This estimate assumes that as
many zero-cost matches as possible are created, and the remainder is
insertions/deletions of cost 1.

The default may not work if there are many insertions/deletions that
get cost of less than 1.

=cut

sub admissible_heuristic {
  my ($self, %args) = @_;

  my $l_remaining = $#{$self->{left}}  - $args{lidx};
  my $r_remaining = $#{$self->{right}} - $args{ridx};

  my $estimate = abs($l_remaining - $r_remaining);
  return 0 if $estimate < 0;
  return $estimate;
}

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

package Array::Align::Step;
use strict;
use warnings;
use Carp;

sub new {
  my ($class, %args) = @_;
  my $self = bless \%args, $class;
  # TO DO: check for existence of lidx, ridx, owner, parent, cost keys
  return $self;
}

sub grow {
  my ($self, %args) = @_;

  my $lidx = $self->{lidx};
  my $ridx = $self->{ridx};
  my @out;
  push @out,
    $self->take_step(left => 1, right => 1);
  push @out,
    $self->take_step(left => 1, right => 0);
  push @out,
    $self->take_step(left => 0, right => 1);
  return @out;
}

sub pairs {
  my ($self, %args) = @_;

  return () if $self->{anchor};

  my $pair =
    [
     ($self->{left} ? $self->{owner}{left}[$self->{lidx}] : undef),
     ($self->{right} ? $self->{owner}{right}[$self->{ridx}] : undef)
    ];
  if (defined $self->{parent}) {
    return ($self->{parent}->pairs(), $pair);
  }
  return ($pair);
}

sub heuristic_cost {
  my ($self, %args) = @_;
  return $self->{cost} +
    $self->{owner}->admissible_heuristic(lidx => $self->{lidx},
					 ridx => $self->{ridx});
}

sub cost {
  my ($self, %args) = @_;
  return $self->{cost};
}

sub is_finished {
  my ($self, %args) = @_;
  return ($self->{lidx} == $#{$self->{owner}{left}}
	  and $self->{ridx} == $#{$self->{owner}{right}});
}

sub take_step {
  my ($self, %args) = @_;
  my $class = ref $self;


  my $lidx = $self->{lidx} + $args{left};
  my $ridx = $self->{ridx} + $args{right};

  # no step possible if we're off the end of the lists
  return () if ($#{$self->{owner}{left}}  < $lidx);
  return () if ($#{$self->{owner}{right}} < $ridx);

  # only include a token if taking a step in that side
  my $left_tok  = $self->{owner}{left}[$lidx] if $args{left};
  my $right_tok = $self->{owner}{right}[$ridx] if $args{right};

  my $incr_cost = $self->{owner}->weighter($left_tok, $right_tok);

  my $cost = $self->cost() + $incr_cost;

  return $class->new(lidx => $lidx, ridx => $ridx,
		     owner => $self->{owner},
		     left => $args{left},
		     right => $args{right},
		     cost => $cost,
		     parent => $self);
}


1; # End of Array::Align
