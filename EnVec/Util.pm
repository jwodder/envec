package EnVec::Util;
use warnings;
use strict;
use Carp;
use Storable 'dclone';
use XML::DOM::Lite ('TEXT_NODE', 'ELEMENT_NODE');
use Exporter 'import';
our @EXPORT = qw< trim simplify uniq jsonify wrapLines magicContent parseTypes
 txt2xml txt2attr sym2xml openR openW >;

sub trim($) {my $str = shift; $str =~ s/^\s+|\s+$//g; return $str; }

sub simplify($) {
 my $str = shift;
 return undef if !defined $str;
 ###$str =~ tr/\xA0/ /;
 # It seems that the above would only make a difference with rulings.
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
  $obj =~ s/\r?\n|\r/\\n/g;
  $obj =~ s/\t/\\t/g;
  return '"' . $obj . '"';
 }
}

sub wrapLines($;$$) {
 my $str = shift;
 my $len = shift || 80;
 my $postdent = shift || 0;
 $str =~ s/\s+\z//;
 map {
  s/\s+\z//;
  if ($_ eq '') { ('') }
  else {
   my @lines = ();
   while (length > $len && /\s+/) {
    if (reverse(substr $_, 0, $len + 1) =~ /\s+/) {
     # Adding one to the length causes a space immediately after the first $len
     # characters to be taken into account.
     push @lines, substr $_, 0, $len + 1 - $+[0], ''
    } else { /\s+/ && push(@lines, substr $_, 0, $-[0], '') }
    s/^\s+//;
    $_ = (' ' x $postdent) . $_;
   }
   $_ eq '' ? @lines : (@lines, $_);
  }
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
    if ($sym =~ /^([2WUBRG])([WUBRGP])$/) { return "{$1/$2}" }
    elsif ($sym eq 'TAP') { return '{T}' }
    elsif ($sym eq 'UNTAP') { return '{Q}' }
    elsif ($sym eq 'SNOW') { return '{S}' }
    elsif ($sym eq 'INFINITY') { return '{∞}' }  # Mox Lotus
    elsif ($sym eq '500') { return '{HALFW}' }
    # It appears that the only fractional mana symbols are half-white (Little
    # Girl; name=500), half-red (Mons's Goblin Waiters; name=HalfR), and
    # half-colorless (Flaccify and Cheap Ass; erroneously omitted from the
    # rules texts).
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
 $str =~ s:\{(\d+|∞)\}:<m>$1</m>:g;
 $str =~ s:\{([WUBRGPXYZSTQ])\}:<$1/>:g;
 $str =~ s:\{([WUBRG])/([WUBRGP])\}:<$1$2/>:g;
 $str =~ s:\{2/([WUBRG])\}:<${1}2/>:g;
 $str =~ s:\{PW\}:<PW/>:g;
 $str =~ s:\{C\}:<chaos/>:g;
 return $str;
}

sub openR($$) {
 my($file, $func) = @_;
 if (!defined $file || $file eq '-') { *STDIN }
 else {
  open my $fh, '<', $file or croak "$func: $file: $!";
  return $fh;
 }
}

sub openW($$) {
 my($file, $func) = @_;
 if (!defined $file || $file eq '-') { *STDOUT }
 else {
  open my $fh, '>', $file or croak "$func: $file: $!";
  return $fh;
 }
}
