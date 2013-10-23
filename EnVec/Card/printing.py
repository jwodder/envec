from string              import ascii_lowercase
from warnings            import warn
from envec.card.multival import Multival
from envec.util          import jsonify, txt2xml

multival = "number artist flavor watermark multiverseid notes".split()

class Printing(object):
    __slots__ = ("set",           # str (required)
		 "date",          # str or None
		 "rarity",        # str or None
		 "number",        # Multival
		 "artist",        # Multival
		 "flavor",        # Multival
		 "watermark",     # Multival
		 "multiverseid",  # Multival
		 "notes")         # Multival

    def __init__(self, set_, date=None, rarity=None, number=None, artist=None,
		 flavor=None, watermark=None, multiverseid=None, notes=None):

	croak "EnVec::Card::Printing->new: 'set' field must be a nonempty string"
	 if !defined $fields{set} || $fields{set} eq '' || ref $fields{set};
	$self->{set} = $fields{set};

	if (!defined $fields{date} || $fields{date} eq '') {
	 $self->{date} = undef
	} elsif (ref $fields{date}) {
	 carp "EnVec::Card::Printing->new: 'date' field may not be a reference";
	 $self->{date} = undef;
	} else { $self->{date} = $fields{date} }

	if (!defined $fields{rarity} || $fields{rarity} eq '') {
	 $self->{rarity} = undef
	} elsif (ref $fields{rarity}) {
	 carp "EnVec::Card::Printing->new: 'rarity' field may not be a reference";
	 $self->{rarity} = undef;
	} else { $self->{rarity} = $fields{rarity} }

	self.number = Multival(number)
	self.artist = Multival(artist)
	self.flavor = Multival(flavor)
	self.watermark = Multival(watermark)
	self.multiverseid = Multival(multiverseid)
	self.notes = Multival(notes)

sub set {
 my $self = shift;
 if (@_) {
  my $new = shift;
  croak "EnVec::Card::Printing->set: field must be a nonempty string"
   if !defined $new || $new eq '' || ref $new;
  $self->{set} = $new;
 }
 return $self->{set};
}

sub rarity {
 my $self = shift;
 if (@_) {
  my $new = shift;
  if (!defined $new || $new eq '') { $self->{rarity} = undef }
  elsif (ref $new) {
   carp "EnVec::Card::Printing->rarity: field may not be a reference";
   $self->{rarity} = undef;
  } else { $self->{rarity} = $new }
 }
 return $self->{rarity};
}

sub date {
 my $self = shift;
 if (@_) {
  my $new = shift;
  if (!defined $new || $new eq '') { $self->{date} = undef }
  elsif (ref $new) {
   carp "EnVec::Card::Printing->date: field may not be a reference";
   $self->{date} = undef;
  } else { $self->{date} = $new }
 }
 return $self->{date};
}

for my $field (@multival) {
 eval <<EOT;
  sub $field {
   my \$self = shift;
   \$self->{$field} = new EnVec::Card::Multival shift if \@_;
   return \$self->{$field};
  }
EOT
}

sub copy {
 my $self = shift;
 #return $self->new(%$self);
 my %dup = (set    => $self->{set},
	    date   => $self->{date},
	    rarity => $self->{rarity});
 $dup{$_} = $self->{$_}->copy for @multival;
 bless \%dup, ref $self;
}

    def toJSON(self):
	txt = '{"set": ' + jsonify(self.set)
	if self.date: txt += ', "date": ' + jsonify(self.date)
	if self.rarity: txt += ', "rarity": ' + jsonify(self.rarity)
	for attr in multival:
	    val = getattr(self, attr)
	    if val.any():
		txt += ', "' + attr + '": ' + val.toJSON()
	return txt + '}'

    def toXML(self):
	txt = "  <printing>\n   <set>" + txt2xml(self.set) + "</set>\n"
	if self.date: txt += "   <date>" + txt2xml(self.date) + "</date>\n"
	if self.rarity:
	    txt += "   <rarity>" + txt2xml(self.rarity) + "</rarity>\n"
	for attr in multival:
	    txt += getattr(self, attr).toXML(attr, attr in ('flavor', 'notes'))
	txt += "  </printing>\n"
	return txt

    def effectiveNum(self):
	nums = self.number.all()
	if not nums: return None
	elif len(nums) == 1: return int(nums[0])
	else: return sorted(int(n.rstrip(ascii_lowercase)) for n in nums)[0]

    @classmethod
    def fromDict(cls, obj):  # called `fromHashref` in the Perl version
	if isinstance(obj, cls): return obj.copy()
	else: return cls(**obj)
