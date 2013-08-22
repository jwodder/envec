package EnVec::Card::Util;
use warnings;
use strict;
use Carp;
use EnVec::Multipart 'FLIP_CARD';
use EnVec::Sets 'loadedSets', 'cmpSets';
use EnVec::Util;
use Exporter 'import';
our @EXPORT = qw< joinCards unmungFlip joinPrintings sortPrintings
		  joinRulings >;

sub joinCards($$$) {
 my($format, $part1, $part2) = @_;
 return new EnVec::Card
  cardClass => $format,
  content   => [ @{$part1->content}, @{$part2->content} ],
  printings => [ joinPrintings($part1->name . ' // ' . $part2->name,
			       $part1->printings,
			       $part2->printings) ],
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
 my $bottom = new EnVec::Card::Content name => $name, cost => $flip->cost,
  supertypes => $supers, types => $types, subtypes => $subs, pow => $pow,
  tough => $tough, text => join("\n", @text);
 my $top = $flip->part1;
 $top->text($topText);
 $flip->content([ $top, $bottom ]);
 $flip->cardClass(FLIP_CARD);
 return $flip;
}

sub joinPrintings($$$) {
 ### FRAGILE ASSUMPTIONS:
 ### - joinPrintings will only ever be called to join data freshly scraped from
 ###   Gatherer.
 ### - The data will always contain no more than one value in each Multival
 ###   field.
 ### - Such values will always be in the card-wide slot.
 ### - The split cards from the Invasion blocks are the only cards that need to
 ###   be joined that have more than one printing per set, and these duplicate
 ###   printings differ only in multiverseid.
 ### - The rarity & date fields of part 1 are always valid for the whole card.
 my($name, $prnt1, $prnt2) = @_;
 my(%prnts1, %prnts2);
 push @{$prnts1{$_->set}}, $_ for @$prnt1;
 push @{$prnts2{$_->set}}, $_ for @$prnt2;
 my @joined;
 for my $set (keys %prnts1) {
  croak "joinPrintings: set mismatch for \"$name\": part 1 has a printing in $set but part 2 does not" if !exists $prnts2{$set};
  ### Should I also check for sets that part 2 has but part 1 doesn't?
  croak "joinPrintings: printings mismatch for \"$name\" in $set: part 1 has ",
   scalar @{$prnts1{$set}}, " printings but part 2 has ",
   scalar @{$prnts2{$set}} if @{$prnts1{$set}} != @{$prnts2{$set}};
  my $multiverse;
  $multiverse = new EnVec::Card::Multival
   [[ sort map { $_->multiverseid->all } @{$prnts1{$set}} ]]
   if @{$prnts1{$set}} > 1;
  my $p1 = $prnts1{$set}[0];
  my $p2 = $prnts2{$set}[0];
  my %prnt = (set => $set, rarity => $p1->rarity, date => $p1->date);
  for my $field (qw< number artist flavor watermark multiverseid notes >) {
   my($val1) = $p1->$field->get;
   my($val2) = $p2->$field->get;
   my $valM;
   if (defined $val1 || defined $val2) {
    if (!defined $val1) { $valM = [[], [], [ $val2 ]] }
    elsif (!defined $val2) { $valM = [[], [ $val1 ]] }
    elsif ($val1 ne $val2) { $valM = [[], [ $val1 ], [ $val2 ]] }
    else { $valM = $p1->$field }
   }
   $prnt{$field} = new EnVec::Card::Multival $valM;
  }
  $prnt{multiverseid} = $multiverse if defined $multiverse;
  push @joined, new EnVec::Card::Printing %prnt;
 }
 return sortPrintings(@joined);
}

sub sortPrintings(@) {
 sort {
  (loadedSets ? cmpSets($a->set, $b->set) : $a->set cmp $b->set)
   || ($a->multiverseid->all)[0] <=> ($b->multiverseid->all)[0]
  ### This needs to handle multiverseid->all being empty or unsorted.
 } @_
}

sub joinRulings($$) {
 my($rules1, $rules2) = @_;
 $rules1 = [] if !defined $rules1;
 $rules2 = [] if !defined $rules2;
 my @rulings;
 loop1: for my $r1 (@$rules1) {
  for my $i (0..$#$rules2) {
   if ($r1->{date} eq $rules2->[$i]{date}
    && $r1->{ruling} eq $rules2->[$i]{ruling}) {
    push @rulings, { %$r1 };
    splice @$rules2, $i, 1;
    next loop1;
   }
  }
  push @rulings, { %$r1, subcard => 0 };
 }
 return @rulings, map { +{ %$_, subcard => 1 } } @$rules2;
}
