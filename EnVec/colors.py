import operator
import re

class Color(object):  # Color should be treated as an immutable type.
    __slots__ = ('W', 'U', 'B', 'R', 'G')

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

    def flags(self):
        return (self.W, self.U, self.B, self.R, self.G)
        #return tuple(map(bool, (self.W, self.U, self.B, self.R, self.G)))
        #return tuple(bool(getattr(self, p)) for p in self.__slots__)

    @classmethod
    def fromFlags(cls, flags):
        return cls(W=flags[0], U=flags[1], B=flags[2], R=flags[3], G=flags[4])

    def __repr__(self):
        colors = []
        if self.W: colors.append('WHITE')
        if self.U: colors.append('BLUE')
        if self.B: colors.append('BLACK')
        if self.R: colors.append('RED')
        if self.G: colors.append('GREEN')
        return 'Color(' + ', '.join(colors) + ')'

    def __str__(self):
        return ''.join(p for p in self.__slots__ if getattr(self, p))

    def __or__(self, other):
        return self.fromFlags(map(operator.or_,  self.flags(), other.flags()))

    def __and__(self, other):
        return self.fromFlags(map(operator.and_, self.flags(), other.flags()))

    def __xor__(self, other):
        return self.fromFlags(map(operator.xor,  self.flags(), other.flags()))

    def __sub__(self, other):
        return self.fromFlags(c and not d for (c,d) in zip(self.flags(),
                                                           other.flags()))

    def __invert__(self):
        return self.fromFlags(map(operator.not_, self.flags()))

    def __iter__(self):  # This implicitly defines __contains__.
        if self.W: yield WHITE
        if self.U: yield BLUE
        if self.B: yield BLACK
        if self.R: yield RED
        if self.G: yield GREEN

    def __len__(self): return sum(self.flags())

    def isMulticolor(self): return len(self) > 1

    def isMonocolor(self): return len(self) == 1

    def isColorless(self): return not any(self.flags())

    def __hash__(self):
        bits = 0
        if self.W: bits |= 1
        if self.U: bits |= 2
        if self.B: bits |= 4
        if self.R: bits |= 8
        if self.G: bits |= 16
        return bits

    __int__ = __hash__

    @classmethod
    def fromHash(cls, bits):
        if bits is None: return None
        return cls(W=bits & 1, U=bits & 2, B=bits & 4, R=bits & 8, G=bits & 16)

    @classmethod
    def fromString(cls, txt):
        if txt is None: return None
        return cls(W='W' in txt, U='U' in txt, B='B' in txt, R='R' in txt,
                   G='G' in txt)

    @classmethod
    def fromLongString(cls, txt):
        if txt is None: return None
        return cls(W=re.search(r'\bWhite\b', txt, re.I),
                   U=re.search(r'\bBlue\b',  txt, re.I),
                   B=re.search(r'\bBlack\b', txt, re.I),
                   R=re.search(r'\bRed\b',   txt, re.I),
                   G=re.search(r'\bGreen\b', txt, re.I))

    # Set-like comparison (not a total ordering):

    def __lt__(self, other): return self <= other and not (self == other)

    def __le__(self, other):
        return type(self) <  type(other) or \
              (type(self) <= type(other) and \
               all(map(operator.le, self.flags(), other.flags())))

    def __eq__(self, other):
        return type(self) == type(other) and \
               all(map(operator.eq, self.flags(), other.flags()))

    def __ne__(self, other): return not (self == other)
    def __ge__(self, other): return other <= self
    def __gt__(self, other): return other <  self


COLORLESS = Color()
WHITE     = Color(W=True)
BLUE      = Color(U=True)
BLACK     = Color(B=True)
RED       = Color(R=True)
GREEN     = Color(G=True)
### Add constants for each color combination?
