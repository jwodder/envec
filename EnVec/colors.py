### TODO: Implement __and__, __xor__, __sub__, and __invert__.

import re

class Color(object):  # Color should be treated as an immutable type.
    __slots__ = ["W", "U", "B", "R", "G"]

    def __init__(self, *colors, **attrs):
	self.W = self.U = self.B = self.R = self.G = False
	for c in colors:
	    for prop in self.__slots__:
		if getattr(c, prop):
		    setattr(self, prop, True)
	for prop in self.__slots__:
	    p = attrs.get(prop, None)
	    if p is not None:
		setattr(self, prop, bool(p))

    def __repr__(self):
	colors = []
	if self.W: colors.append('WHITE')
	if self.U: colors.append('BLUE')
	if self.B: colors.append('BLACK')
	if self.R: colors.append('RED')
	if self.G: colors.append('GREEN')
	return 'Color(' + ', '.join(colors) + ')'

    def __str__(self):
	txt = ''
	for p in self.__slots__:
	    if getattr(self, p):
		txt += p
	return txt

    def __or__(self, other):
	return Color(W=self.W or other.W,
		     U=self.U or other.U,
		     B=self.B or other.B,
		     R=self.R or other.R,
		     G=self.G or other.G)

    def __iter__(self):  # This implicitly defines __contains__.
	if self.W: yield WHITE
	if self.U: yield BLUE
	if self.B: yield BLACK
	if self.R: yield RED
	if self.G: yield GREEN

    def __len__(self): return self.W + self.U + self.B + self.R + self.G

    def isMulticolor(self): return len(self) > 1

    def __hash__(self):
	bits = 0
	if self.W: bits |= 1
	if self.U: bits |= 2
	if self.B: bits |= 4
	if self.R: bits |= 8
	if self.G: bits |= 16
	return bits

    __int__ = __hash__

    @staticmethod
    def fromHash(bits):
	if bits is None: return None
	return Color(W=bits & 1, U=bits & 2, B=bits & 4, R=bits & 8,
		     G=bits & 16)

    @staticmethod
    def fromString(txt):
	if txt is None: return None
	return Color(W='W' in txt, U='U' in txt, B='B' in txt, R='R' in txt,
		     G='G' in txt)

    @staticmethod
    def fromLongString(txt):
	if txt is None: return None
	return Color(W=re.search(r'\bWhite\b', txt, re.I),
		     U=re.search(r'\bBlue\b',  txt, re.I),
		     B=re.search(r'\bBlack\b', txt, re.I),
		     R=re.search(r'\bRed\b',   txt, re.I),
		     G=re.search(r'\bGreen\b', txt, re.I))

    # Set-like comparison (not a total ordering):

    def __lt__(self, other): return self <= other and not (self == other)

    def __le__(self, other):
	return type(self) <= type(other) and \
	    all(getattr(self, p) <= getattr(other, p) for p in self.__slots__)

    def __eq__(self, other):
	return type(self) == type(other) and \
	    all(getattr(self, p) == getattr(other, p) for p in self.__slots__)

    def __ne__(self, other): return not (self == other)
    def __ge__(self, other): return other <= self
    def __gt__(self, other): return other < self

COLORLESS = Color()
WHITE     = Color(W=True)
BLUE      = Color(U=True)
BLACK     = Color(B=True)
RED       = Color(R=True)
GREEN     = Color(G=True)
