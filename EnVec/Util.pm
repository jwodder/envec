package EnVec::Util;
use warnings;
use strict;
use Carp;
use Storable 'dclone';
use XML::DOM::Lite qw< TEXT_NODE ELEMENT_NODE >;

use Exporter 'import';
our @EXPORT = qw< trim simplify uniq jsonify wrapLines textContent parseTypes
 mergePrintings showSets >;

our $tagwidth = 8;

sub trim($) {my $str = shift; $str =~ s/^\s+|\s+$//g; return $str; }

sub simplify($) {
 my $str = shift;
 return 'XXX' if !defined $str;  #####
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

sub textContent($) {
# cf. <http://www.w3.org/TR/2004/REC-DOM-Level-3-Core-20040407/core.html#Node3-textContent>
 my $node = shift;
 if ($node->nodeType == TEXT_NODE) {
  (my $txt = $node->nodeValue) =~ s/&nbsp;/ /g;
  return $txt;
 } elsif ($node->nodeType == ELEMENT_NODE) {
  $node->nodeName eq 'br' ? "\n"
   : join('', map { textContent($_) } @{$node->childNodes})
 } ### else { ??? }
}

sub parseTypes($) {
 my($type, $sub) = split / ?— ?| -+ /, simplify $_[0], 2;
  # The first "hyphen" above is U+2014.
 return [], [ 'Summon' ], [ $2 || $sub ] if $type =~ /^Summon( (.+))?$/i;
 my @sublist = $type eq 'Plane' ? ($sub) : defined $sub ? split(' ', $sub) : ();
  # Assume that Plane cards never have supertypes or other card types.
 my @typelist = split ' ', $type;
 my @superlist = ();
 while (@typelist) {
  if ($typelist[0] =~ /^(Basic|Legendary|Ongoing|Snow|World)$/i) {
   push @superlist, shift @typelist
  } elsif ($typelist[0] =~ /^Enchant$/i) {
   @typelist = join ' ', @typelist;
   last;
  } else { last }
 }
 return [ @superlist ], [ @typelist ], [ @sublist ];
}

sub mergePrintings($$$) {
 my($name, $left, $right) = @_;
 my %merged = %{dclone $left};
 for my $set (keys %$right) {
  if (!exists $merged{$set}) { $merged{$set} = $right->{$set} }
  else {
   if (defined $right->{$set}{rarity}) {
    if (!defined $merged{$set}{rarity}) {
     $merged{$set}{rarity} = $right->{$set}{rarity}
    } elsif ($merged{$set}{rarity} ne $right->{$set}{rarity}) {
     carp "Conflicting rarities for $name in $set: $merged{$set}{rarity} vs. "
      . $right->{$set}{rarity}
    }
   }
   my $leftIDs = $merged{$set}{ids} || [];
   my $rightIDs = $right->{$set}{ids} || [];
   my @ids = uniq sort @$leftIDs, @$rightIDs;
   $merged{$set}{ids} = \@ids if @ids;
  }
 }
 return \%merged;
}

my %shortRares = (common => 'C', uncommon => 'U', rare => 'R', land => 'L',
 'mythic rare' => 'M');

sub showSets($$) {
 my($printings, $width) = @_;
 my $text = join ', ', map {
  my $rare = $printings->{$_}{rarity} || 'XXX';
  "$_ (" . ($shortRares{lc $rare} || $rare) . ')';
 } sort keys %$printings;
 my($first, @rest) = wrapLines $text, $width, 2;
 $first = '' if !defined $first;
 return join '', sprintf("%-${tagwidth}s %s\n", 'Sets:', $first),
  map { (' ' x $tagwidth) . " $_\n" } @rest;
}
