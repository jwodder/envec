package EnVec;
use warnings;
use strict;
use EnVec::Card;
use EnVec::Checklist ':all';
use EnVec::Colors;
use EnVec::Details ':all';
use EnVec::Get ':all';
use EnVec::JSON ':all';
use EnVec::Reader;
use EnVec::Sets ':all';
use EnVec::Multipart ':all';
use Exporter 'import';
our @EXPORT_OK = (@{$EnVec::Checklist::EXPORT_TAGS{all}},
		  @EnVec::Colors::EXPORT,
		  @{$EnVec::Details::EXPORT_TAGS{all}},
		  @{$EnVec::Get::EXPORT_TAGS{all}},
		  @{$EnVec::JSON::EXPORT_TAGS{all}},
		  @{$EnVec::Sets::EXPORT_TAGS{all}},
		  @{$EnVec::Multipart::EXPORT_TAGS{all}},
		  'mergeCards');
our %EXPORT_TAGS = (all => \@EXPORT_OK);
