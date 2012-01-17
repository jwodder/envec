package EnVec::Sets;
use warnings;
use strict;
use Carp;
use Exporter 'import';
our @EXPORT_OK = qw< loadedSets loadSets cmpSets setsToImport allSets setData
 fromAbbrev firstSet >;
our %EXPORT_TAGS = (all => \@EXPORT_OK);

our $setFile = 'data/sets.tsv';

my %sets = ();
my %shorts = ();
my @setList = ();
my $loaded = 0;
my $warned = 0;

sub loadedSets() { $loaded }

sub loadSets(;$) {
 my $sf = shift || $setFile;
 my $setdat;
 if ($sf eq '-') { $setdat = *STDIN }
 else { open $setdat, '<', $sf or croak "EnVec::Sets::loadSets: $sf: $!" }
 %sets = ();
 %shorts = ();
 @setList = ();
 while (<$setdat>) {
  chomp;
  next if /^\s*#/ || /^\s*$/;
  my($short, $name, $date, $import) = split /\t+/;
  if (exists $sets{$name}) {
   carp "EnVec::Sets::loadSets: $sf: set \"$name\" appears more than once; second appearance discarded";
   next;
  }
  $date =~ tr/0-9//cd;
  $date = $name if $date eq '';
   # ^^ so that comparing two dateless sets will at least be deterministic
  $sets{$name} = {
   short  => $short,
   name   => $name,
   date   => $date,
   import => $import
  };
  push @setList, $name;
  if (exists $shorts{$short}) {
   carp "EnVec::Sets::loadSets: $sf: abbreviation \"$short\" used more than once; second appearance ignored"
  } else { $shorts{$short} = $name }
 }
 $loaded = 1;
 close $setdat;
}

sub loadCheck() {  # not for export
 if (!$loaded && !$warned) {
  carp "Warning: EnVec::Sets::loadSets not yet invoked";
  $warned = 1;
 }
}

sub cmpSets($$) {
 loadCheck;
 my($a, $b) = map { exists $sets{$_}{date} ? $sets{$_}{date} : $_ } @_;
 return $a cmp $b || $_[0] cmp $_[1];
}

sub setsToImport() {loadCheck; return grep { $sets{$_}{import} } @setList; }

sub allSets() {loadCheck; return @setList; }

sub setData($) {loadCheck; exists $sets{$_[0]} ? %{$sets{$_[0]}} : (); }

sub fromAbbrev($) {loadCheck; return $shorts{$_[0]}; }
 # Get the name of the set corresponding to an abbreviation (or undef if there
 # is no such abbreviation)

sub firstSet(@) {
 loadCheck;
 my $first = shift;
 for (@_) { $first = $_ if cmpSets($_, $first) < 0 }
 return $first;
}

1;
