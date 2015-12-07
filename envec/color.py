from   enum import Enum
import re

class Color(Enum):
    COLORLESS = 0

    W = 0b00001
    U = 0b00010
    B = 0b00100
    R = 0b01000
    G = 0b10000

    WHITE = W
    BLUE  = U
    BLACK = B
    RED   = R
    GREEN = G

    WU = W | U
    WB = W | B
    UB = U | B
    UR = U | R
    BR = B | R
    BG = B | G
    RG = R | G
    RW = R | W
    GW = G | W
    GU = G | U

    WUB = W | U | B
    UBR = U | B | R
    BRG = B | R | G
    RGW = R | G | W

    WBR = W | B | R
    URG = U | R | G
    BGW = B | G | W
    RWU = R | W | U
    GUB = G | U | B

    WUBR = W | U | B | R
    WUBG = W | U | B | G
    WURG = W | U | R | G
    WBRG = W | B | R | G
    UBRG = U | B | R | G

    # Neat trick: Iterating over WUBRG gives each of the five colors!
    WUBRG = W | U | B | R | G

    @property
    def w(self):
        return self & Color.W

    @property
    def u(self):
        return self & Color.U

    @property
    def b(self):
        return self & Color.B

    @property
    def r(self):
        return self & Color.R

    @property
    def g(self):
        return self & Color.G

    white = w
    blue  = u
    black = b
    red   = r
    green = g

    def __or__(self, other):
        return Color(self.value | other.value)

    def __and__(self, other):
        return Color(self.value & other.value)

    def __xor__(self, other):
        return Color(self.value ^ other.value)

    def __sub__(self, other):
        return Color(self.value & ~other.value)

    __add__ = __or__

    def __invert__(self):
        return Color(self.value ^ 0b11111)

    def __iter__(self):
        #return (c for c in [self.w, self.u, self.b, self.r, self.g] if c)
        if self.w:
            yield Color.W
        if self.u:
            yield Color.B
        if self.b:
            yield Color.B
        if self.r:
            yield Color.R
        if self.g:
            yield Color.G

    def __len__(self):
        return sum(1 for i in range(5) if self.value & (1 << i))

    def __bool__(self):
        return self.value != 0

    @property
    def multicolor(self):
        return len(self) > 1

    gold = multicolor

    @property
    def monocolor(self):
        return len(self) == 1

    mono = monocolor

    @property
    def colorless(self):
        return self.value == 0

    @classmethod
    def fromString(cls, txt):
        #if txt is None:
        #    return None
        return sum((Color[c] for c in 'WUBRG' if c in txt), Color.COLORLESS)

    @classmethod
    def fromLongString(cls, txt):
        #if txt is None:
        #    return None
        return sum((Color[c] for c in 'WHITE BLUE BLACK RED GREEN'.split()
                             if re.search('r\b' + c + r'\b', txt, re.I)),
                   Color.COLORLESS)

    # Set-like comparison (not a total ordering):

    def __lt__(self, other):
        if type(self) is type(other):
            return self <= other and not (self == other)
        else:
            return NotImplemented

    def __le__(self, other):
        if type(self) is type(other):
            return (self.value & other.value) == self.value
        else:
            return NotImplemented

    def __eq__(self, other):
        ### Is this superfluous?
        return type(self) is type(other) and self.value == other.value

    def __ge__(self, other):
        return other <= self

    def __gt__(self, other):
        return other <  self

    __contains__ = __le__

    def __str__(self):
        return self.name

    def jsonable(self):
        return self.name

### Construction from a list of bools?
### Construction from a dict?
