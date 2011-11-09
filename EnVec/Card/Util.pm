package EnVec::Card::Util;
# This was split apart from EnVec::Util in order to deal with some sort of
# circular-dependency issue.
use warnings;
use strict;
use Carp;
use EnVec::Card;
use EnVec::Card::Split;
use EnVec::Util;

use Exporter 'import';
our @EXPORT = qw< joinSplit addCard >;

my $subname = qr:[^(/)]+:;

sub joinSplit($$) {
 my($a, $b) = @_;
 $a->name =~ m:^($subname) // ($subname) \(($subname)\)$:
  or croak "joinSplit: non-split card: " . $a->name;
 my($leftN, $rightN, $aN) = ($1, $2, $3);
 my($left, $right, $bN);
 if ($leftN eq $aN) {
  $left = $a;
  $right = $b;
  $bN = "$leftN // $rightN ($rightN)";
 } elsif ($rightN eq $aN) {
  $left = $b;
  $right = $a;
  $bN = "$leftN // $rightN ($leftN)";
 } else { croak "joinSplit: bad card name: " . $a->name }
 croak "joinSplit: card " . $a->name . " does not match card " . $b->name
  if $b->name ne $bN;
 $left->name($leftN);
 $right->name($rightN);
 my $printings = mergePrintings "$leftN // $rightN", $left->printings,
  $right->printings;
 $left->printings({});
 $right->printings({});
 return new EnVec::Card::Split cardType => 'split', part1 => $left,
  part2 => $right, printings => $printings;
}

sub addCard(\%$$%) {
 my($db, $set, $id, %fields) = @_;
 my $card = new EnVec::Card %fields;
 if ($card->name =~ m:^($subname) // ($subname) \(($subname)\)$:) {
  my($left, $right, $this) = ($1, $2, $3);
  my $other = "$left // $right (" . ($left eq $this ? $right : $left) . ')';
  if (exists $db->{$other}) {
   $card = $db->{"$left // $right"} = joinSplit $card, delete $db->{$other};
   $card->addSetID($set, $id);
   return $card;
  }
 }
 ### Should this use merge or mergeCheck?
 $db->{$card->name} = $card if !exists $db->{$card->name};
 $db->{$card->name}->addSetID($set, $id);
 return $db->{$card->name};
}
