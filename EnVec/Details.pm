package EnVec::Details;
use warnings;
use strict;
use Carp;
use XML::DOM::Lite 'Parser';
use EnVec::Colors;
use EnVec::Util;

use Exporter 'import';
our @EXPORT_OK = ('parseDetails', 'loadDetails');
our %EXPORT_TAGS = (all => \@EXPORT_OK);

sub parseDetails($) {
 my $str = shift;
 # Work around italicization farkup:
 $str =~ s:</i>([^<>]+)</i>:$1:gi;
 my $doc = Parser->new->parse($str);
 my $pre = 'ctl00_ctl00_ctl00_MainContent_SubContent_SubContent_';
 if ($doc->getElementById("${pre}nameRow")) { scrapeSection($doc, $pre) }
 else { (part1 => { scrapeSection($doc, "${pre}ctl05_") },
	 part2 => { scrapeSection($doc, "${pre}ctl06_") }) }
}

sub loadDetails($) {
 my $file = shift;
 local $/ = undef;
 open my $in, '<', $file or croak "EnVec::Details::loadDetails: $file: $!";
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
 return join "\n", grep { $_ ne '' } map { trim magicContent $_ }
  divsByClass((divsByClass $row, 'value')[0], 'cardtextbox');
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
  push @expands, [ $id, $set, $rarity ];
 }
 return @expands;
}

sub scrapeSection($$) {
 my($doc, $pre) = @_;
 my %fields = ();
 $fields{name} = simplify rowVal $doc->getElementById("${pre}nameRow");
 $fields{cost} = rowVal $doc->getElementById("${pre}manaRow");
 $fields{cost} =~ s/\s+//g if defined $fields{cost};
 @fields{'supertypes','types','subtypes'}
  = parseTypes rowVal $doc->getElementById("${pre}typeRow");
 $fields{text} = multiline $doc->getElementById("${pre}textRow");
 $fields{prnt}{flavor} = multiline $doc->getElementById("${pre}flavorRow");
 $fields{prnt}{watermark} = multiline $doc->getElementById("${pre}markRow");
 $fields{indicator} = parseColors rowVal $doc->getElementById("${pre}colorIndicatorRow");
 my $ptRow = $doc->getElementById("${pre}ptRow");
 if ($ptRow) {
  my $label = simplify magicContent((divsByClass $ptRow, 'label')[0]);
  if ($label eq 'P/T:') {
   @fields{'pow','tough'} = (rowVal($ptRow) =~ m:^\s*([^/]+?)\s*/\s*(.+?)\s*$:)
  } elsif ($label eq 'Loyalty:') { $fields{loyalty} = simplify rowVal $ptRow }
  elsif ($label eq 'Hand/Life:') {
   @fields{'handMod','lifeMod'} = (simplify(rowVal($ptRow))
     =~ /Hand Modifier: ?([-+]?\d+) ?, ?Life Modifier: ?([-+]?\d+)/i)
  } else { print STDERR "Unknown ptRow label for $fields{name}: \"$label\"\n" }
 }
 @{$fields{prnt}}{'multiverseid', 'set', 'rarity'}
  = @{(expansions $doc->getElementById("${pre}currentSetSymbol"))[0]};
 $fields{printings} = [expansions $doc->getElementById("${pre}otherSetsValue")];
 $fields{prnt}{number} = simplify rowVal $doc->getElementById("${pre}numberRow");
 $fields{prnt}{artist} = simplify rowVal $doc->getElementById("${pre}artistRow");
 my $rulings = $doc->getElementById("${pre}rulingsContainer");
 if ($rulings) {
  for my $tr (@{$rulings->getElementsByTagName('tr')}) {
   my $tds = $tr->getElementsByTagName('td');
   next if $tds->length != 2;
   push @{$fields{rulings}}, [ map { simplify magicContent $_ } @$tds ];
  }
 }
 return %fields;
}
