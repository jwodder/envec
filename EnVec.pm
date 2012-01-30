package EnVec;
use warnings;
use strict;
#use EnVec::Card;
use EnVec::Checklist ':all';
use EnVec::Colors;
use EnVec::Details ':all';
use EnVec::Get ':all';
use EnVec::JSON ':all';
use EnVec::Sets ':all';
use EnVec::SplitList ':all';
use EnVec::TextSpoiler ':all';
use Exporter 'import';
our @EXPORT_OK = (@{$EnVec::Checklist::EXPORT_TAGS{all}},
		  @EnVec::Colors::EXPORT,
		  @{$EnVec::Details::EXPORT_TAGS{all}},
		  @{$EnVec::Get::EXPORT_TAGS{all}},
		  @{$EnVec::JSON::EXPORT_TAGS{all}},
		  @{$EnVec::Sets::EXPORT_TAGS{all}},
		  @{$EnVec::SplitList::EXPORT_TAGS{all}},
		  @{$EnVec::TextSpoiler::EXPORT_TAGS{all}},
		  'mergeCards');
our %EXPORT_TAGS = (all => \@EXPORT_OK);

sub mergeCards(\%\%) {
 # The contents of $db2 are merged into $db1.  $db2 is left intact, $db1 is not.
 my($db1, $db2) = @_;
 for (keys %$db2) {
  if (exists $db1->{$_}) { $db1->{$_} = $db1->{$_}->merge($db2->{$_}) }
  else { $db1->{$_} = $db2->{$_} }
 }
}
