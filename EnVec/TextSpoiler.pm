package EnVec::TextSpoiler;
use warnings;
use strict;
use XML::DOM::Lite 'Parser';
use EnVec::Card;
use EnVec::Card::Util;
use EnVec::Colors;
use EnVec::Util;

use Exporter 'import';
our @EXPORT_OK = ('loadTextSpoiler');
our %EXPORT_TAGS = (all => \@EXPORT_OK);

sub loadTextSpoiler($$) {
 my($set, $file) = @_;
 my %cards = ();
 ## Workaround for ampersand bug in text spoilers:
 #my $index = -1;
 #while (($index = index $data, '&', $index + 1) != -1) {
 # my $semicolonIndex = index $dat, ';', $index;
 # if ($semicolonIndex - $index > 5) {
 #  substr $data, $index + 1, 0, 'amp;';
 #  $index += 4;
 # }
 #}
 my $parser = Parser->new;
 my $doc = $parser->parseFile($file);
 ### TODO: Handle parse errors somehow!
 for my $div (@{$doc->getElementsByTagName('div')}) {
  my $divClass = $div->getAttribute('class');
  if (defined $divClass && $divClass eq 'textspoiler') {
   my %fields = ();
   my $id = 0;
   for my $tr (@{$div->getElementsByTagName('tr')}) {
    my $tds = $tr->getElementsByTagName('td');
    if ($tds->length != 2) {
     my $card = new EnVec::Card %fields;
     $card->addSetID($set, $id);
     insertCard %cards, $card;
     %fields = ();
     $id = 0;
    } else {
     my $v1 = simplify magicContent $tds->[0];
     my $v2 = magicContent $tds->[1];
     if ($v1 eq 'Name:') {
      ($fields{name} = simplify $v2) =~ s/^[^()]+ \(([^()]+)\)$/$1/;
      ($id) = ($tds->[1]->getElementsByTagName('a')->[0]->getAttribute('href')
		=~ /\bmultiverseid=(\d+)/);
     } elsif ($v1 eq 'Cost:') {
      $fields{cost} = simplify $v2;
      $fields{cost} =~ s<\G(\d+|[XYZWUBRG])|\G\(([2WUBRG]/[WUBRGP])\)>
			<\U{@{[$2 || $1]}}>gi;
      # Assume no snow in mana costs
     } elsif ($v1 eq 'Type:') {
      @fields{'supertypes', 'types', 'subtypes'} = parseTypes $v2
     } elsif ($v1 eq 'Pow/Tgh:' && $v2 =~ /\S/) {
      $v2 =~ tr/()//d;
      my($p, $t) = split m:/:, $v2, 2;
      $fields{pow} = simplify $p;
      $fields{tough} = simplify $t;
     } elsif ($v1 eq 'Rules Text:') {
      $fields{text} = trim $v2;
      $fields{text} =~ s/^[ \t]+|[ \t]+$//gm;
      $fields{text} =~ s/[\n\r]+/\n/g;
      # Fix Oracular snow weirdness:
      $fields{text} =~ s/\{S\}i\}?/{S}/g;
      # Get rid of parentheses in things like "{(r/p)}":
      $fields{text} =~ s:\{\((\w/\w)\)\}:{@{[uc $1]}}:g;
     } elsif ($v1 eq 'Hand/Life:' && simplify($v2) =~ /^Hand Modifier: ([-+]?\d+) ?, ?Life Modifier: ([-+]?\d+)$/i) {
      $fields{handMod} = $1;
      $fields{lifeMod} = $2;
     } elsif ($v1 eq 'Set/Rarity:') {
      for (split /\s*,\s*/, simplify $v2) {
       s/ (Common|Uncommon|(Mythic )?Rare|Special|Promo|Land)$//;
       $fields{printings}{$_}{rarity} = $1 || 'UNKNOWN';
      }
     } elsif ($v1 eq 'Color:') { $fields{indicator} = parseColors $v2 }
     elsif ($v1 eq 'Loyalty:') { ($fields{loyalty} = simplify $v2) =~ tr/()//d }
    }
   }
   last;
  }
 }
 return %cards;
}
