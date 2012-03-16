package EnVec::Reader;
use warnings;
use strict;
use overload '<>' => 'readCard';
use Carp;

sub open {
 my($class, $file) = @_;
 my $in;
 if (!defined $file || $file eq '-') {$in = *STDIN; $file = 'STDIN'; }
 else { open $in, '<', $file or croak "EnVec::Reader->open: $file: $!" }
 local $/ = '[';
 my $first = <$in>;
 croak "EnVec::Reader->open: $file: bad opening"
  if !defined $first || $first !~ /^\s*\[$/;
 bless { filename => $file, fh => $in }, $class;
}

sub readCard {
 my $self = shift;
 return undef if !defined $self->{fh};
 my($buf, $level, $quoting) = ('', 0, 0);
 local $/ = '}';
 while (defined($_ = readline $self->{fh})) {
  if (/^\s*\]\s*$/) {
   croak 'EnVec::Reader->readCard: ', $self->{filename}, ': invalid format'
    if $buf ne '';
   close $self->{fh};
   return $self->{fh} = undef;
  }
  croak 'EnVec::Reader->readCard: ', $self->{filename}, ': invalid format'
   if !/\}$/;
  pos() = 0;  # just making sure
  for (;;) {
   /\G\{/g        && do {$level++ if !$quoting; next; }
   /\G\}$/g       && do {$level-- if !$quoting; last; }
   /\G"/g         && do {$quoting = !$quoting; next; }
   /\G\\./g       && next;
   /\G[^{}"\\]+/g && next;
  }
  $buf .= $_;
  if ($level == 0) {
   $buf =~ s/^\s*,\*//;
   return EnVec::Card->fromJSON($buf);
  }
 }
 croak 'EnVec::Reader->readCard: ', $self->{filename}, ': invalid format';
}

1;
