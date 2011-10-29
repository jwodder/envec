#!/usr/bin/perl -w
use strict;
use Carp;
use HTTP::Status qw< status_message is_success >;
use LWP::Simple 'mirror';
use XML::DOM::Lite qw< Parser TEXT_NODE ELEMENT_NODE >;
use Card;

use constant {
 COLOR_WHITE => 1,
 COLOR_BLUE  => 2,
 COLOR_BLACK => 4,
 COLOR_RED   => 8,
 COLOR_GREEN => 16
};

sub importTextSpoiler($$);
sub addCard($$$$$$@);
sub colorStr2Bits($);
sub simplify($);
sub trim($);
sub elem($@);
sub textContent($);

my $setURL = 'http://gatherer.wizards.com/Pages/Search/Default.aspx?output=spoiler&method=text&set=[%22!longname!%22]&special=true';

my $setfile = 'sets.txt';

# Read list of long set names into @allSets; sets that aren't meant to be
# downloaded/imported should be commented out of the list of sets beforehand.
open my $sets, '<', $setfile or die "$0: $setfile: $!";
my @allSets = grep { !/^\s*#/ && !/^\s*$/ } <$sets>;
close $sets;
chomp for @allSets;

my %cardHash;

for my $set (@allSets) {
 (my $url = $setURL) =~ s/!longname!/$set/g;
 (my $file = "oracle/$set.html") =~ tr/ /_/;
 #my $res = getstore($url, $file);
 my $res = mirror($url, $file);
 if (!is_success $res) {
  print STDERR "Could not fetch set \"$set\": ", status_message($res), "\n";
  next;
 }
 my $qty = importTextSpoiler($set, $file);
 print STDERR "$set imported ($qty cards)\n";
}
print "[\n";
my $first = 1;
for (values %cardHash) {
 print ",\n\n" if !$first;
 print $_->toJSON;
 $first = 0;
}
print "]\n";


sub importTextSpoiler($$) {
 my($set, $file) = @_;
 my $cards = 0;

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
 ##if (!doc.setContent(bufferContents, &errorMsg, &errorLine, &errorColumn))
 ## qDebug() << "error:" << errorMsg << "line:" << errorLine << "column:" << errorColumn;
 for my $div (@{$doc->getElementsByTagName('div')}) {
  my $divClass = $div->getAttribute('class');
  if (defined $divClass && $divClass eq 'textspoiler') {
   my($cardName, $cardCost, $cardType, $cardPT, $cardText);
   my $cardId = 0;
   for my $tr (@{$div->getElementsByTagName('tr')}) {
    my $tds = $tr->getElementsByTagName("td");
    if ($tds->length != 2) {
     my @cardTextSplit = split /\n/, $cardText;
     s/^\s+|\s+$//g for @cardTextSplit;
     addCard($set, $cardName, $cardId, $cardCost, $cardType, $cardPT,
      @cardTextSplit);
     undef $cardName;
     undef $cardCost;
     undef $cardType;
     undef $cardPT;
     undef $cardText;
     $cards++;
    } else {
     my $v1 = simplify textContent $tds->[0];
     my $v2 = textContent $tds->[1];
     if ($v1 eq 'Name:') {
      my $a = $tds->[1]->getElementsByTagName('a')->[0];
      my $href = $a->getAttribute('href');
      $href =~ /multiverseid=(\d+)/ and $cardId = $1;
      $cardName = simplify $v2;
     } elsif ($v1 eq 'Cost:') { $cardCost = simplify $v2 }
     elsif ($v1 eq 'Type:') { $cardType = simplify $v2 }
     elsif ($v1 eq 'Pow/Tgh:') { ($cardPT = simplify $v2) =~ tr/()//d }
     elsif ($v1 eq 'Rules Text:') { $cardText = trim $v2 }
    }
   }
   last;
  }
 }
 return $cards;
}

sub addCard($$$$$$@) {
 my($setName, $cardName, $cardId, $cardCost, $cardType, $cardPT, @cardText)
  = @_;
 my $fullCardText = join "\n", @cardText;
 my $splitCard = ($cardName =~ s/ \(.*\)//g);
 my $card;
 if (exists $cardHash{$cardName}) {
  $card = $cardHash{$cardName};
  $card->text($card->text() . "\n---\n" . $fullCardText)
   if $splitCard && index($card->text, $fullCardText) == -1;
 } else {
  $cardName =~ s/XX//g;  # Workaround for card name weirdness
  my @colors = grep { $cardCost =~ /$_/ } qw< W U B R G >;
  push @colors, 'W' if elem("$cardName is white.", @cardText);
  push @colors, 'U' if elem("$cardName is blue.", @cardText);
  push @colors, 'B' if elem("$cardName is black.", @cardText);
  push @colors, 'R' if elem("$cardName is red.", @cardText);
  push @colors, 'G' if elem("$cardName is green.", @cardText);
  $card = new Card name => $cardName, manacost => $cardCost,
   cardtype => $cardType, powtough => $cardPT, text => $fullCardText,
   colors => colorStr2Bits(join '', @colors);
  $cardHash{$cardName} = $card;
 }
 $card->sets($setName, $cardId);
 return $card;
}

sub colorStr2Bits($) {
 my $str = shift;
 my $mask = 0;
 $mask |= COLOR_WHITE if $str =~ y/W//;
 $mask |= COLOR_BLUE  if $str =~ y/U//;
 $mask |= COLOR_BLACK if $str =~ y/B//;
 $mask |= COLOR_RED   if $str =~ y/R//;
 $mask |= COLOR_GREEN if $str =~ y/G//;
 return $mask;
}

sub simplify($) {
 my $str = shift;
 $str =~ s/^\s+|\s+$//g;
 $str =~ s/\s+/ /g;
 return $str;
}

sub trim($) {
 my $str = shift;
 $str =~ s/^\s+|\s+$//g;
 return $str;
}

sub elem($@) {
 my $str = shift;
 for (@_) { return 1 if $_ eq $str }
 return 0;
}

sub textContent($) {
# cf. <http://www.w3.org/TR/2004/REC-DOM-Level-3-Core-20040407/core.html#Node3-textContent>
 my $node = shift;
 if ($node->nodeType == TEXT_NODE) { $node->nodeValue }
 elsif ($node->nodeType == ELEMENT_NODE) {
  join '', map { textContent $_ } @{$node->childNodes}
 } ### else { ??? }
}
