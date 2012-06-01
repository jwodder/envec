package EnVec::Details;
use warnings;
use strict;
use Carp;
use XML::DOM::Lite 'Parser';
use EnVec::Card;
use EnVec::Card::Printing;
use EnVec::Card::Util 'joinCards';
use EnVec::Colors;
use EnVec::Multipart 'NORMAL_CARD';
use EnVec::Util;

use Exporter 'import';
our @EXPORT_OK = ('parseDetails', 'loadDetails');
our %EXPORT_TAGS = (all => \@EXPORT_OK);

sub parseDetails($) {
 my $str = shift;
 $str =~ s:</i>([^<>]+)</i>:$1:gi;  # Work around italicization farkup
 my $doc = Parser->new->parse($str);
 my $pre = 'ctl00_ctl00_ctl00_MainContent_SubContent_SubContent_';
 if ($doc->getElementById("${pre}nameRow")) { scrapeSection($doc, $pre) }
 elsif ($doc->getElementById("${pre}ctl05_nameRow")) {
  # Flip or double-faced card
  joinCards NORMAL_CARD, scrapeSection($doc, "${pre}ctl05_"),
			 scrapeSection($doc, "${pre}ctl06_")
 } else {
  # B.F.M. (Big Furry Monster)
  joinCards NORMAL_CARD, scrapeSection($doc, "${pre}ctl07_"),
			 scrapeSection($doc, "${pre}ctl08_")
 }
}

sub loadDetails($) {
 my $file = shift;
 local $/ = undef;
 my $in = openR($file, 'EnVec::Details::loadDetails');
 my $str = <$in>;
 close $in;
 return parseDetails($str);
}

sub divsByClass($$) {
 my($node, $class) = @_;
 return () if !$node;
 return grep {
  $_->nodeName eq 'div'
   && defined $_->getAttribute('class')
   && $_->getAttribute('class') eq $class
 } @{$node->childNodes};
}

sub rowVal($) {
 my $val = (divsByClass $_[0], 'value')[0];
 return defined $val ? magicContent $val : undef;
}

sub multiline($) {
 my $row = shift;
 return undef if !$row;
 my $txt = join "\n", grep { $_ ne '' }
  # There are some cards with superfluous empty cardtextboxes inserted into
  # their rules text for no good reason, and these empty lines should probably
  # be removed.  On the other hand, preserving empty lines is needed for
  # B.F.M.'s text to line up.
  map { trim magicContent $_ }  ### simplify() instead?
  divsByClass((divsByClass $row, 'value')[0], 'cardtextbox');
 $txt =~ s/[\n\r]+\z//;  # Trailing empty lines should definitely be removed.
 return $txt;
}

sub expansions($) {
 my $node = shift;
 return () if !$node;
 my @expands = ();
 for my $a (@{$node->getElementsByTagName('a')}) {
  my($id) = ($a->getAttribute('href') =~ /\bmultiverseid=(\d+)/);
  next if !defined $id;
  my($img) = @{$a->getElementsByTagName('img')};
  next if !$img;
  my $src = $img->getAttribute('src');
  next if !defined $src;
  my($set) = ($src =~ /\bset=(\w+)/);
  my($rarity) = ($src =~ /\brarity=(\w+)/);
  push @expands, new EnVec::Card::Printing set => $set, rarity => $rarity,
   multiverseid => $id;
 }
 return @expands;
}

sub scrapeSection($$) {
 my($doc, $pre) = @_;
 my(%fields, %prnt);
 $fields{name} = simplify rowVal $doc->getElementById("${pre}nameRow");
 $fields{cost} = rowVal $doc->getElementById("${pre}manaRow");
 $fields{cost} =~ s/\s+//g if defined $fields{cost};
 @fields{'supertypes','types','subtypes'}
  = parseTypes rowVal $doc->getElementById("${pre}typeRow");
 $fields{text} = multiline $doc->getElementById("${pre}textRow");
 if (defined $fields{text}) {
  # Unbotch mana symbols in Unglued cards:
  $fields{text} =~ s/\bocT\b/{T}/g;
  $fields{text} =~ s/\bo([WUBRG]|\d+)/{$1}/g;
 }
 $prnt{flavor} = multiline $doc->getElementById("${pre}flavorRow");
 $prnt{watermark} = multiline $doc->getElementById("${pre}markRow");
 $fields{indicator}
  = parseColors rowVal $doc->getElementById("${pre}colorIndicatorRow");
 my $ptRow = $doc->getElementById("${pre}ptRow");
 if ($ptRow) {
  my $label = simplify magicContent((divsByClass $ptRow, 'label')[0]);
  my $pt = simplify rowVal $ptRow;
  $pt =~ s:\{\^2\}:²:g;  # S.N.O.T.
  $pt =~ s:\{1/2\}:½:g;
  # Note that ½s in rules texts (in details mode) are already represented by ½.
  if ($label eq 'P/T:') {
   @fields{'pow','tough'} = ($pt =~ m:^([^/]+?) ?/ ?(.+?)$:)
  } elsif ($label eq 'Loyalty:') { $fields{loyalty} = $pt }
  elsif ($label eq 'Hand/Life:') {
   @fields{'hand','life'}
    = ($pt =~ /Hand Modifier: ?([-+]?\d+) ?, ?Life Modifier: ?([-+]?\d+)/i)
  } else { carp "Unknown ptRow label for $fields{name}: \"$label\"" }
 }
 my($prnt0) = expansions $doc->getElementById("${pre}currentSetSymbol");
 $prnt{number} = simplify rowVal $doc->getElementById("${pre}numberRow");
 $prnt{artist} = simplify rowVal $doc->getElementById("${pre}artistRow");
 $fields{printings} = [
  (new EnVec::Card::Printing set => $prnt0->set,
			     rarity => $prnt0->rarity,
			     multiverseid => $prnt0->multiverseid,
			     %prnt),
  expansions $doc->getElementById("${pre}otherSetsValue"),
 ];
 my $rulings = $doc->getElementById("${pre}rulingsContainer");
 if ($rulings) {
  for my $tr (@{$rulings->getElementsByTagName('tr')}) {
   my $tds = $tr->getElementsByTagName('td');
   next if $tds->length != 2;
   my($date, $ruling) = map { magicContent $_ } @$tds;
   $ruling =~ s/\r\n?/\n/g;
   push @{$fields{rulings}}, { date => simplify $date, ruling => trim $ruling };
  }
 }
 return newCard EnVec::Card %fields;
}
