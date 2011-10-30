package EnVec;

#use EnVec::Card;
use EnVec::Colors;
use EnVec::Get 'getTextSpoiler';
use EnVec::JSON qw< dumpArray dumpHash loadJSON >;
use EnVec::TextSpoiler 'textSpoiler';

use Exporter 'import';
our @EXPORT_OK = (@EnVec::Colors::EXPORT, @EnVec::Get::EXPORT_OK,
 @EnVec::JSON::EXPORT_OK, @EnVec::TextSpoiler::EXPORT_OK, 'mergeCards');

sub mergeCards(\%\%) {
 # The contents of $db2 are merged into $db1.  $db2 is left intact, $db1 is not.
 my($db1, $db2) = @_;
 for (keys %$db2) {
  if (exists $db1->{$_}) { $db1->{$_} = $db1->{$_}->mergeWith($db2->{$_}) }
  else { $db1->{$_} = $db2->{$_} }
 }
}
