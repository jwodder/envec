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
our @EXPORT = qw< joinSplit addCard joinFlip unmungFlip >;

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

sub joinFlip($$) {
 my($top, $bottom) = @_;
 my $topName = $top->name;
 $bottom->name =~ /^\Q$topName\E \(([^)]+)\)$/
  or croak "joinFlip: invalid arguments: $topName vs. " . $bottom->name;
 $bottom->name($1);
 $bottom->cost(undef);
 my $printings = mergePrintings "$topName // $1", $top->printings,
  $bottom->printings;
 $top->printings({});
 $bottom->printings({});
 return new EnVec::Card::Split cardType => 'flip', part1 => $top,
  part2 => $bottom, printings => $printings;
}

sub unmungFlip($) {
 my $flip = shift;
 my $topText = $flip->text || '';
 $topText =~ s/\n----\n(.*)$//s or return $flip;
  # Should a warning be given if $flip isn't actually a munged flip card?
 my($name, $type, $pt, @text) = split /\n/, $1;
 my($supers, $types, $subs) = parseType $type;
 my($pow, $tough) = map { simplify $_ } split m:/:, $pt, 2;
 my $bottom = new EnVec::Card name => $name, supertypes => $supers,
  types => $types, subtypes => $subs, pow => $pow, tough => $tough,
  text => join("\n", @text);
  # Should the bottom half store the mana cost and color indicator of the top
  # half?  It would be in accordance with the rules for flipped cards.
 $flip->text($topText);
 my $printings = $flip->printings;
 $flip->printings({});
 return new EnVec::Card::Split cardType => 'flip', part1 => $flip,
  part2 => $bottom, printings => $printings;
}
