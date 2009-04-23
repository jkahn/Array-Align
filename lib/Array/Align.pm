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

  my $self = bless \%args, $class;
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
    Array::Align::Step->new(lidx => 0, ridx => 0,
			    owner => $self, parent => undef,
			    cost => 0);

  use Heap::Simple;
  my $heap = Heap::Simple->new(elements =>[Method => 'cost'],
			       order => '<');
  $heap->insert($init);

  my @solutions;

  while (@solutions < $nbest) {
    my $best = $heap->extract_first();
    last if (not defined $best);  # no more candidates

    my @next = $best->grow();

    if (not @next) {
      # must be finished
      push @solutions, $best;
    }
    else {
      $heap->insert(@next);
    }
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

=back

=head1 CONTRACT PROGRAMMING

Methods that must be implemented by the subclass

=over

=item weighter

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
  my @out;
  push @out, $self->take_step(left => 1, right => 1); # diag
  push @out, $self->take_step(left => 1, right => 0); # left
  push @out, $self->take_step(left => 0, right => 1); # right
  return @out;
}

sub pairs {
  my ($self, %args) = @_;

  my $pair = [$self->{owner}{left}[$self->{lidx}],
	      $self->{owner}{right}[$self->{ridx}] ];
  if (defined $self->{parent}) {
    return ($self->{parent}->pairs(), $pair);
  }
  return ($pair);
}

sub cost {
  my ($self, %args) = @_;
  return $self->{cost};
}

sub take_step {
  my ($self, %args) = @_;
  my $class = ref $self;

  my $lidx = $self->{lidx} + $args{left};
  my $ridx = $self->{ridx} + $args{right};

  # no step possible if we're off the end of the lists
  return () if ($#{$self->{owner}{left}}  < $lidx);
  return () if ($#{$self->{owner}{right}} < $ridx);

  my $left_tok  = $self->{owner}{left}[$lidx];
  my $right_tok = $self->{owner}{right}[$ridx];

  my $incr_cost = $self->{owner}->weighter($left_tok, $right_tok);

  my $cost = $self->cost() + $incr_cost;

  return $class->new(lidx => $lidx, ridx => $ridx,
		     owner => $self->{owner},
		     cost => $cost,
		     parent => $self);
}


1; # End of Array::Align