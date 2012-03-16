package EnVec::Card::Util;
use warnings;
use strict;
use EnVec::Util;
use Exporter 'import';
our @EXPORT = ('joinCards', 'unmungFlip');

sub joinCards($$$) {
 my($format, $part1, $part2) = @_;
 return new EnVec::Card
  cardClass => $format,
  content   => [ @{$part1->content}, @{$part2->content} ],
  printings => [ joinPrintings $part1->name . ' // ' . $part2->name,
			       $part1->printings,
			       $part2->printings ],
  rulings   => [ joinRulings($part1->rulings, $part2->rulings) ];
}

sub unmungFlip($) {
 my $flip = shift;
 return $flip if $flip->isMultipart;
 # Should a warning be given if $flip isn't actually a munged flip card?
 my $topText = $flip->text || '';
 $topText =~ s/\n----\n(.+)\z//s or return $flip;
 my($name, $type, $pt, @text) = split /\n/, $1;
 my($supers, $types, $subs) = parseTypes $type;
 my($pow, $tough) = map { simplify $_ } split m:/:, $pt, 2;
 my $bottom = new EnVec::Card::Content name => $name, supertypes => $supers,
  types => $types, subtypes => $subs, pow => $pow, tough => $tough,
  text => join("\n", @text);
 my $top = $flip->part1;
 $top->text($topText);
 $flip->content([ $top, $bottom ]);
 $flip->cardClass(FLIP_CARD);
 return $flip;
}
