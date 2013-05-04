package EnVec::Checklist;
use warnings;
use strict;
use XML::DOM::Lite 'Parser';
use EnVec::Util;
use Exporter 'import';
our @EXPORT_OK = ('parseChecklist', 'loadChecklist');
our %EXPORT_TAGS = (all => \@EXPORT_OK);

sub parseChecklist($) { walkChecklist(Parser->new->parse(shift)) }

sub loadChecklist($) { walkChecklist(Parser->new->parseFile(shift)) }

sub walkChecklist($) {
 my $doc = shift;
 my @cards = ();
 for my $table (@{$doc->getElementsByTagName('table')}) {
  my $tblClass = $table->getAttribute('class');
  next unless defined $tblClass && $tblClass eq 'checklist';
  for my $tr (@{$table->getElementsByTagName('tr')}) {
   my $trClass = $tr->getAttribute('class');
   next unless defined $trClass && $trClass eq 'cardItem';
   my %item = ();
   for my $td (@{$tr->getElementsByTagName('td')}) {
    my $key = $td->getAttribute('class');
    my $value = simplify magicContent $td;
    $item{$key} = $value;
    if ($key eq 'name') {
     my $url = $td->getElementsByTagName('a')->[0]->getAttribute('href');
     ($item{multiverseid}) = ($url =~ /\bmultiverseid=(\d+)/) if defined $url;
    }
   }
   push @cards, \%item;
  }
  last;
 }
 return @cards;
}
