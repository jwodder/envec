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
our @EXPORT = qw< insertCard joinCards unmungFlip >;

my $subname = qr:[^(/)]+:;

sub insertCard(\%$) {
 my($db, $card) = @_;
 my $name = $card->name;
 $db->{$name} = exists $db->{$name} ? $db->{$name}->merge($card) : $card;
}

sub joinCards($$$) {
 my($format, $part1, $part2) = @_;
 my $printings = mergePrintings $part1->name . ' // ' . $part2->name,
  $part1->printings, $part2->printings;
 $part1->printings({});
 $part2->printings({});
 return new EnVec::Card::Split cardType => $format, part1 => $part1,
  part2 => $part2, printings => $printings;
}

sub unmungFlip($) {
 my $flip = shift;
 my $topText = $flip->text || '';
 $topText =~ s/\n----\n(.*)$//s or return $flip;
  ### Should a warning be given if $flip isn't actually a munged flip card?
 my($name, $type, $pt, @text) = split /\n/, $1;
 my($supers, $types, $subs) = parseTypes $type;
 my($pow, $tough) = map { simplify $_ } split m:/:, $pt, 2;
 my $bottom = new EnVec::Card name => $name, supertypes => $supers,
  types => $types, subtypes => $subs, pow => $pow, tough => $tough,
  text => join("\n", @text);
 $flip->text($topText);
 my $printings = $flip->printings;
 $flip->printings({});
 return new EnVec::Card::Split cardType => 'flip', part1 => $flip,
  part2 => $bottom, printings => $printings;
}

#sub joinSplit($$) {
# my($a, $b) = @_;
# $a->name =~ m:^($subname) // ($subname) \(($subname)\)$:
#  or croak "joinSplit: non-split card: " . $a->name;
# my($leftN, $rightN, $aN) = ($1, $2, $3);
# my($left, $right, $bN);
# if ($leftN eq $aN) {
#  $left = $a;
#  $right = $b;
#  $bN = "$leftN // $rightN ($rightN)";
# } elsif ($rightN eq $aN) {
#  $left = $b;
#  $right = $a;
#  $bN = "$leftN // $rightN ($leftN)";
# } else { croak "joinSplit: bad card name: " . $a->name }
# croak "joinSplit: card " . $a->name . " does not match card " . $b->name
#  if $b->name ne $bN;
# $left->name($leftN);
# $right->name($rightN);
# return joinCards 'split', $left, $right;
#}
#
#sub joinFlip($$) {
# my($top, $bottom) = @_;
# my $topName = $top->name;
# $bottom->name =~ /^\Q$topName\E \(([^)]+)\)$/
#  or croak "joinFlip: invalid arguments: $topName vs. " . $bottom->name;
# $bottom->name($1);
# $bottom->cost(undef);
# return joinCards 'flip', $top, $bottom;
#}
