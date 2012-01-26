package EnVec::Card::Util;
# This was split apart from EnVec::Util in order to break a circular dependency.
use warnings;
use strict;
use Carp;
use EnVec::Card;
use EnVec::SplitList ':all';
use EnVec::Util;
use Exporter 'import';
our @EXPORT = qw< insertCard joinCards unmungFlip joinParts >;

sub insertCard(\%$) {
 my($db, $card) = @_;
 my $name = $card->name;
 ### $db->{$name} = exists $db->{$name} ? $db->{$name}->merge($card) : $card;
 $db->{$name} = $card if !exists $db->{$name};
}

sub joinCards($$$) {
 my($format, $part1, $part2) = @_;
 return new EnVec::Card cardType => $format,
  content => [@{$part1->content}, @{$part2->content}],
  printings => [ joinPrintings $part1->name . ' // ' . $part2->name,
			       $part1->printings,
			       $part2->printings ],
  rulings => [ joinRulings($part1->rulings, $part2->rulings) ];
}

sub unmungFlip($) {
 my $flip = shift;
 return $flip if $flip->isMultipart;
 # Should a warning be given if $flip isn't actually a munged flip card?
 my $topText = $flip->text || '';
 $topText =~ s/\n----\n(.+)$//s or return $flip;
 my($name, $type, $pt, @text) = split /\n/, $1;
 my($supers, $types, $subs) = parseTypes $type;
 my($pow, $tough) = map { simplify $_ } split m:/:, $pt, 2;
 my $bottom = new EnVec::Card::Content name => $name, supertypes => $supers,
  types => $types, subtypes => $subs, pow => $pow, tough => $tough,
  text => join("\n", @text);
 my $top = $flip->part1;
 $top->text($topText);
 $flip->content([ $top, $bottom ]);
 $flip->cardType(FLIP_CARD);
 return $flip;
}

sub joinParts(\%) {
 # If this function is called when the multipart cards lists haven't been
 # loaded, it should do nothing.
 my $cards = shift;
 for my $a (splitLefts) {
  my $b = alternate $a;
  if (exists $cards->{$a} && exists $cards->{$b}) {
   insertCard(%$cards, joinCards SPLIT_CARD, $cards->{$a}, $cards->{$b});
   delete $cards->{$a};
   delete $cards->{$b};
  }
 }
 for my $a (flipTops) {
  my $b = alternate $a;
  if (exists $cards->{$a} && exists $cards->{$b}) {
   $cards->{$b}->cost(undef);
   insertCard(%$cards, joinCards FLIP_CARD, $cards->{$a}, $cards->{$b});
   delete $cards->{$a};
   delete $cards->{$b};
  } elsif (exists $cards->{$a} && $cards->{$a}->text =~ /\n----\n/) {
   insertCard(%$cards, unmungFlip($cards->{$a}));
   # Potential pitfall: If $cards->{$a} isn't actually a flip card (even though
   # it _should_ be one if its text has ----), it'll get deleted here.
   delete $cards->{$a};
  }
 }
 for my $a (doubleFronts) {
  my $b = alternate $a;
  if (exists $cards->{$a} && exists $cards->{$b}) {
   insertCard(%$cards, joinCards DOUBLE_CARD, $cards->{$a}, $cards->{$b});
   delete $cards->{$a};
   delete $cards->{$b};
  }
 }
 return $cards;
}
