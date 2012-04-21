package EnVec::Reader2;
use warnings;
use strict;
use overload '<>' => 'readCard';
use Carp;
use EnVec::Card;
use EnVec::Util 'openR';

sub open {
 my($class, $file) = @_;
 my $in = openR($file, 'EnVec::Reader2->open');
 local $/ = '[';
 my $first = <$in>;
 croak "EnVec::Reader2->open: $file: bad opening"
  if !defined $first || $first !~ /^\s*\[$/;
 bless {
  fh => $in,
  filename => defined($file) ? $file : '-',
  buf => '',
 }, $class;
}

sub readCard {
 my $self = shift;
 return undef if !defined $self->{fh};
 my($buf, $level, $quoting, $trailEsc) = ('', 0, 0, 0);
 local $_ = $self->{buf};
 do {
  $_ = "\\" . $_ if $trailEsc;
  $trailEsc = 0;
  if (/^\s*\]\s*$/) {
   croak 'EnVec::Reader2->readCard: ', $self->{filename}, ': invalid format #1'
    if $buf =~ /\S/;
   close $self->{fh};
   return $self->{fh} = undef;
  }
  pos() = 0;  # just making sure
  for (;;) {
   /\G\{/gc        && do {$level++ if !$quoting; next; };
   /\G\}/gc        && do {
			  if (!$quoting && --$level == 0) {
			   $self->{buf} = substr $_, $+[0];
			   substr($_, $+[0]) = '';
			   last;
			  } else { next }
			 };
   /\G"/gc         && do {$quoting = !$quoting; next; };
   /\G\\./gc       && next;
   /\G\\\z/gc      && do {$trailEsc = 1; chop; last; };
   /\G[^{}"\\]+/gc && next;
   /\G\z/gc        && last;
   croak 'EnVec::Reader2->readCard: ', $self->{filename}, ': invalid format #2';
  }
  $buf .= $_;
  if ($level == 0) {
   $buf =~ s/^\s*,\s*//;
   return EnVec::Card->fromJSON($buf) if $buf =~ /\S/;
  }
 } while (read $self->{fh}, $_, 2048);
 croak 'EnVec::Reader2->readCard: ', $self->{filename}, ': invalid format #3';
}

1;
