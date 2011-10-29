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

sub jsonify($) {
 my $str = shift;
 $str =~ s/([\\"])/\\$1/g;
 $str =~ s/[\n\r]/\\n/g;
 $str =~ s/\t/\\t/g;
 return $str;
}

sub addCard(\%$$$$$$@) {
 my($cardHash, $setName, $cardName, $cardId, $cardCost, $cardType, $cardPT, @cardText) = @_;
 my $fullCardText = join "\n", @cardText;
 my $splitCard = ($cardName =~ s/ \(.*\)//g);
 my $card;
 if (exists $cardHash->{$cardName}) {
  $card = $cardHash->{$cardName};
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
  $cardHash->{$cardName} = $card;
 }
 $card->sets($setName, $cardId);
 return $card;
}
