package EnVec::Util;
use warnings;
use strict;
use Carp;
use Storable 'dclone';
use XML::DOM::Lite ('TEXT_NODE', 'ELEMENT_NODE');
use EnVec::Card::Multival;
use EnVec::Card::Printing;
use Exporter 'import';
our @EXPORT = qw< trim simplify uniq jsonify wrapLines magicContent parseTypes
 txt2xml txt2attr sym2xml joinPrintings sortPrintings joinRulings >;
 ### mergePrintings

sub trim($) {my $str = shift; $str =~ s/^\s+|\s+$//g; return $str; }

sub simplify($) {
 my $str = shift;
 return undef if !defined $str;
 $str =~ s/^\s+|\s+$//g;
 $str =~ s/\s+/ /g;
 return $str;
}

sub uniq(@) {  # The list must be pre-sorted
 my $prev = undef;
 grep { (!defined $prev or $prev ne $_) and ($prev = $_ or 1) } @_;
}

sub jsonify($) {
 my $obj = shift;
 if (!defined $obj) { 'null' }
 elsif (ref $obj eq 'ARRAY') { '['.join(', ', map { jsonify($_) } @$obj).']' }
 elsif (ref $obj eq 'HASH') {
  '{' . join(', ', map { jsonify($_) . ': ' . jsonify($obj->{$_}) } sort keys %$obj) . '}'
 } else {
  $obj =~ s/([\\"])/\\$1/g;
  $obj =~ s/[\n\r]/\\n/g;
  $obj =~ s/\t/\\t/g;
  return '"' . $obj . '"';
 }
}

sub wrapLines($;$$) {
 my $str = shift;
 my $len = shift || 80;
 my $postdent = shift || 0;
 $str =~ s/\s+$//;
 map {
  my @lines = ();
  while (length > $len && /\s+/) {
   if (reverse (substr $_, 0, $len + 1) =~ /\s+/) {
    # Adding one to the length causes a space immediately after the first $len
    # characters to be taken into account.
    push @lines, substr $_, 0, $len + 1 - $+[0], ''
   } else { /\s+/ && push @lines, substr $_, 0, $-[0], '' }
   s/^\s+//;
   $_ = (' ' x $postdent) . $_;
  }
  $_ eq '' ? @lines : (@lines, $_);
 } split /\n/, $str;
}

sub magicContent($) {
 # Like textContent, but better ... for its intended purpose
 # cf. <http://www.w3.org/TR/2004/REC-DOM-Level-3-Core-20040407/core.html#Node3-textContent>
 my $node = shift;
 if (!defined $node) { return '' }
 elsif ($node->nodeType == TEXT_NODE) {
  (my $txt = $node->nodeValue) =~ s/&nbsp;/ /g;
  return $txt;
 } elsif ($node->nodeType == ELEMENT_NODE) {
  if ($node->nodeName eq 'br') { return "\n" }
  elsif ($node->nodeName eq 'i') {
   '<i>' . join('', map { magicContent($_) } @{$node->childNodes}) . '</i>'
  } elsif ($node->nodeName eq 'img') {
   my $src = $node->getAttribute('src') || '';
   if ($src =~ /\bchaos\.gif$/) { return '{C}' }
   elsif ($src =~ /\bname=(\w+)\b/) {
    my $sym = uc $1;
    if ($sym eq 'TAP') { return '{T}' }
    elsif ($sym eq 'UNTAP') { return '{Q}' }
    elsif ($sym eq 'SNOW') { return '{S}' }
    elsif ($sym =~ /^([2WUBRG])([WUBRGP])$/) { return "{$1/$2}" }
    else { return "{$sym}" }
   } else { return "[$src]" }
  } else { return join '', map { magicContent($_) } @{$node->childNodes} }
 } ### else { ??? }
}

sub parseTypes($) {
 my($type, $sub) = split / ?— ?| -+ /, simplify $_[0], 2;
  # The first "hyphen" above is U+2014.
 return [], [ $1 ], [ $3 || $sub ] if $type =~ /^(Summon|Enchant)( (.+))?$/i;
 my @sublist = $type eq 'Plane' ? ($sub) : split(' ', $sub || '');
  # Assume that Plane cards never have supertypes or other card types.
 my @typelist = split ' ', $type;
 my @superlist = ();
 push @superlist, shift @typelist
  while @typelist && $typelist[0] =~ /^(Basic|Legendary|Ongoing|Snow|World)$/i;
 return [ @superlist ], [ @typelist ], [ @sublist ];
}

sub txt2xml($) {
 my $str = shift;
 $str =~ s/&/&amp;/g;
 $str =~ s/</&lt;/g;
 $str =~ s/>/&gt;/g;
 return $str;
}

sub txt2attr($) {
 (my $str = txt2xml shift) =~ s/"/&quot;/g;
 return $str;
}

sub sym2xml($) {
 my $str = txt2xml shift;
 $str =~ s:&lt;(/?i)&gt;:<\L$1>:gi;
 $str =~ s:\{(\d+)\}:<m>$1</m>:g;
 $str =~ s:\{([WUBRGPXYZSTQ])\}:<$1/>:g;
 $str =~ s:\{([WUBRG])/([WUBRGP])\}:<$1$2/>:g;
 $str =~ s:\{2/([WUBRG])\}:<${1}2/>:g;
 $str =~ s:\{PW\}:<PW/>:g;
 $str =~ s:\{C\}:<chaos/>:g;
 return $str;
}

###sub mergePrintings($$$) {
### my($name, $left, $right) = @_;
### my %merged = %{dclone $left};
### for my $set (keys %$right) {
###  if (!exists $merged{$set}) { $merged{$set} = $right->{$set} }
###  else {
###   if (defined $right->{$set}{rarity}) {
###    if (!defined $merged{$set}{rarity}) {
###     $merged{$set}{rarity} = $right->{$set}{rarity}
###    } elsif ($merged{$set}{rarity} ne $right->{$set}{rarity}) {
###     carp "Conflicting rarities for $name in $set: $merged{$set}{rarity} vs. "
###      . $right->{$set}{rarity}
###    }
###   }
###   my $leftIDs = $merged{$set}{ids} || [];
###   my $rightIDs = $right->{$set}{ids} || [];
###   my @ids = uniq sort @$leftIDs, @$rightIDs;
###   $merged{$set}{ids} = \@ids if @ids;
###  }
### }
### return \%merged;
###}

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
 ### - The rarity and date fields of part 1 are always valid for the whole card.
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
 return sortPrintings @joined;
}

sub sortPrintings(@) {
 sort {
  (loadedSets ? $a->set cmpSets $b->set : $a->set cmp $b->set)
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

###sub mergeRulings($$)
###sub sortRulings(@)
