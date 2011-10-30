package EnVec;
#use EnVec::Card;
use EnVec::Colors;
use EnVec::Get ':all';
use EnVec::JSON ':all';
use EnVec::TextSpoiler ':all';

use Exporter 'import';
our @EXPORT_OK = (@EnVec::Colors::EXPORT,
		  $EnVec::Get::EXPORT_TAGS{all},
		  $EnVec::JSON::EXPORT_TAGS{all},
		  $EnVec::TextSpoiler::EXPORT_TAGS{all},
		  'mergeCards');
our %EXPORT_TAGS = (all => [ @EXPORT_OK ]);

sub mergeCards(\%\%) {
 # The contents of $db2 are merged into $db1.  $db2 is left intact, $db1 is not.
 my($db1, $db2) = @_;
 for (keys %$db2) {
  if (exists $db1->{$_}) { $db1->{$_} = $db1->{$_}->mergeWith($db2->{$_}) }
  else { $db1->{$_} = $db2->{$_} }
 }
}
