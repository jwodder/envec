package EnVec::Util;
use JSON::Syck;
use XML::DOM::Lite qw< TEXT_NODE ELEMENT_NODE >;
use EnVec::Card;

use Exporter 'import';
our @EXPORT = qw< simplify trim textContent jsonify addCard parseTypes
 wrapLines >;

sub simplify($) {
 my $str = shift;
 return 'XXX' if !defined $str;  #####
 $str =~ s/^\s+|\s+$//g;
 $str =~ s/\s+/ /g;
 return $str;
}

sub trim($) {
 my $str = shift;
 $str =~ s/^\s+|\s+$//g;
 return $str;
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

sub jsonify($) {
 my $obj = shift;
 if (!defined $obj) { 'null' }
 elsif (ref $obj eq 'ARRAY') { '['.join(', ', map { jsonify $_ } @$obj).']' }
 elsif (ref $obj eq 'HASH') {
  '{' . join(', ', map { jsonify($_) . ': ' . jsonify($obj->{$_}) } sort keys %$obj) . '}'
 } else {
  $obj =~ s/([\\"])/\\$1/g;
  $obj =~ s/[\n\r]/\\n/g;
  $obj =~ s/\t/\\t/g;
  return '"' . $obj . '"';
 }
}

my $subname = qr:[^(/)]+:;

sub addCard(\%$$%) {
 my($db, $set, $id, %fields) = @_;
 my $card = new EnVec::Card %fields;

#if ($card->name =~ m:^($subname) // ($subname) \(($subname)\)$:) {
# my($left, $right, $this) = ($1, $2, $3);
# my $other = "$left // $right (" . ($left eq $this ? $right : $left) . ')';
# if (exists $db->{$other}) {
#  $card = $db->{"$left // $right"} = joinCards $card, delete $db->{$other};
#  $card->addSetId($set, $id);
#  return $card;
# }
#}

 $db->{$card->name} = $card if !exists $db->{$card->name};
 $db->{$card->name}->addSetID($set, $id);
 return $db->{$card->name};
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

sub wrapLines($;$) {
 my $str = shift;
 my $len = shift || 80;
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
  }
  $_ eq '' ? @lines : (@lines, $_);
 } split /\n/, $str;
}
