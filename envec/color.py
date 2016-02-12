from   enum import Enum
import re

class Color(Enum):
    # The first name on each line is the "canonical" name for the value.
    COLORLESS = 0
    W = WHITE = 0b00001
    U = BLUE  = 0b00010
    B = BLACK = 0b00100
    R = RED   = 0b01000
    G = GREEN = 0b10000

    WU = UW = AZORIUS  = W | U
    WB = BW = ORZHOV   = W | B
    UB = BU = DIMIR    = U | B
    UR = RU = IZZET    = U | R
    BR = RB = RAKDOS   = B | R
    BG = GB = GOLGARI  = B | G
    RG = GR = GRUUL    = R | G
    RW = WR = BOROS    = R | W
    GW = WG = SELESNYA = G | W
    GU = UG = SIMIC    = G | U

    GWU = GUW = WGU = WUG = UGW = UWG = BANT   = G | W | U
    WUB = WBU = UWB = UBW = BWU = BUW = ESPER  = W | U | B
    UBR = URB = BUR = BRU = RUB = RBU = GRIXIS = U | B | R
    BRG = BGR = RBG = RGB = GBR = GRB = JUND   = B | R | G
    RGW = RWG = GRW = GWR = WRG = WGR = NAYA   = R | G | W

    WBR = WRB = BWR = BRW = RWB = RBW = MARDU  = DEGA  = W | B | R
    URG = UGR = RUG = RGU = GUR = GRU = TEMUR  = CETA  = U | R | G
    BGW = BWG = GBW = GWB = WBG = WGB = ABZAN  = NECRA = B | G | W
    RWU = RUW = WRU = WUR = URW = UWR = JESKAI = RAKA  = R | W | U
    GUB = GBU = UGB = UBG = BGU = BUG = SULTAI = ANA   = G | U | B

    # I am NOT putting every 4-color permutation here; just the ones where the
    # colors are in clockwise order.
    WUBR = UBRW = BRWU = RWUB = YORE_TILLER = W | U | B | R
    GWUB = WUBG = UBGW = BGWU = WITCH_MAW   = W | U | B | G
    RGWU = GWUR = WURG = URGW = INK_TREADER = W | U | R | G
    BRGW = RGWB = GWBR = WBRG = DUNE_BROOD  = W | B | R | G
    UBRG = BRGU = RGUB = GUBR = GLINT_EYE   = U | B | R | G

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
            yield Color.U
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

    @classmethod
    def fromBits(cls, W=False, U=False, B=False, R=False, G=False):
        return cls(int(''.join('1' if c else '0' for c in (G,R,B,U,W)), base=2))
