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

sub addCard(\%$$$$$$$) {
 my($db, $set, $name, $id, $cost, $type, $PT, $text) = @_;
 my $splitCard = ($name =~ s/ \(.*\)//);
 my $card;
 if (exists $db->{$name}) {
  $card = $db->{$name};
  $card->text($card->text() . "\n---\n" . $text)
   if $splitCard && index($card->text, $text) == -1;
 } else {
  $name =~ s/^XX//g;  ## Workaround for card name weirdness
  $card = new Card name => $name, cost => $cost, type => $type,
   powtough => $PT, text => $text;
  $db->{$name} = $card;
 }
 $card->sets($set, $id);
 return $card;
}
