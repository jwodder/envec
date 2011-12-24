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
 return new EnVec::Card::Split cardType => $format, content => [$part1, $part2],
  printings => $printings;
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
 return new EnVec::Card::Split cardType => FLIP_CARD,
  content => [$flip, $bottom], printings => $printings;
}
