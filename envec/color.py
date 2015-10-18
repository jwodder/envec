from   collections import namedtuple
import operator
import re
from   six.moves   import reduce

class Color(namedtuple('Color', 'W U B R G')):  ### Use an Enum instead?
    __slots__ = ()

    def __new__(cls, **colors):
        for c in 'WUBRG':
            colors[c] = bool(colors.get(c, False))
        return super(Color, cls).__new__(cls, **colors)

    def __str__(self):
        return ''.join(c for c in 'WUBRG' if getattr(self, c))

    def __or__(self, other):
        return self._make(map(operator.or_,  self, other))

    def __and__(self, other):
        return self._make(map(operator.and_, self, other))

    def __xor__(self, other):
        return self._make(map(operator.xor,  self, other))

    def __sub__(self, other):
        return self._make(c and not d for (c,d) in zip(self, other))

    def __invert__(self):
        return self._make(map(operator.not_, self))

    def colors(self):  ### Rethink whether this should be __iter__
        if self.W: yield Color.WHITE
        if self.U: yield Color.BLUE
        if self.B: yield Color.BLACK
        if self.R: yield Color.RED
        if self.G: yield Color.GREEN

    def size(self):  ### Could this be __len__ without breaking too much?
        return sum(self)

    @property
    def multicolor(self): return self.size() > 1

    gold = multicolor

    @property
    def monocolor(self): return self.size() == 1

    mono = monocolor

    @property
    def colorless(self): return not any(self)

    @classmethod
    def fromString(cls, txt):
        if txt is None:
            return None
        return cls(W='W' in txt, U='U' in txt, B='B' in txt, R='R' in txt,
                   G='G' in txt)

    @classmethod
    def fromLongString(cls, txt):
        if txt is None:
            return None
        return cls(W=re.search(r'\bWhite\b', txt, re.I),
                   U=re.search(r'\bBlue\b',  txt, re.I),
                   B=re.search(r'\bBlack\b', txt, re.I),
                   R=re.search(r'\bRed\b',   txt, re.I),
                   G=re.search(r'\bGreen\b', txt, re.I))

    # Set-like comparison (not a total ordering):

    def __lt__(self, other):
        if type(self) is type(other):
            return self <= other and not (self == other)
        else:
            return NotImplemented

    def __le__(self, other):
        if type(self) is type(other):
            return all(map(operator.le, self, other))
        else:
            return NotImplemented

    def __eq__(self, other):
        return type(self) is type(other) and all(map(operator.eq, self, other))

    def __ne__(self, other): return not (self == other)
    def __ge__(self, other): return other <= self
    def __gt__(self, other): return other <  self

    __contains__ = __le__

    @classmethod
    def union(cls, *colors):
        return reduce(operator.or_, colors, cls())

    ### Implement .iteritems() etc.?


Color.COLORLESS = Color()
Color.WHITE     = Color(W=True)
Color.BLUE      = Color(U=True)
Color.BLACK     = Color(B=True)
Color.RED       = Color(R=True)
Color.GREEN     = Color(G=True)
### Add constants for each color combination?

Color.PENTAGON = [Color.WHITE, Color.BLUE, Color.BLACK, Color.RED, Color.GREEN]
