from   functools import total_ordering
import re
from   .color    import Color
from   ._util    import txt2xml, sym2xml, cheap_repr, split_mana, cleanDict

@total_ordering
class Content:
    def __init__(self, name, types, cost=None, supertypes=(), subtypes=(),
                 text=None, power=None, toughness=None, loyalty=None,
                 hand=None, life=None, color_indicator=None):
        self.name       = name                  # string
        self.types      = tuple(types)          # tuple of strings
        self.cost       = cost                  # string or None
        self.supertypes = tuple(supertypes)     # tuple of strings
        self.subtypes   = tuple(subtypes)       # tuple of strings
        self.text       = text                  # string or None
        self.power      = power                 # string or None
        self.toughness  = toughness             # string or None
        self.loyalty    = loyalty               # string or None
        self.hand       = hand                  # string or None
        self.life       = life                  # string or None
        self.color_indicator = color_indicator  # Color or None

    def toXML(self):
        txt = "  <content>\n   <name>" + txt2xml(self.name) + "</name>\n"
        if self.cost is not None:
            txt += "   <cost>" + sym2xml(self.cost) + "</cost>\n"
        for sup in self.supertypes:
            txt += "   <supertype>" + txt2xml(sup) + "</supertype>\n"
        for t in self.types:
            txt += "   <type>" + txt2xml(t) + "</type>\n"
        for sub in self.subtypes:
            txt += "   <subtype>" + txt2xml(sub) + "</subtype>\n"
        for line in (self.text or '').splitlines():
            txt += "   <text>" + sym2xml(line) + "</text>\n"
        for attr in "power toughness loyalty hand life color_indicator".split():
            val = getattr(self, attr)
            if val is not None:
                txt += "   <%s>%s</%s>\n" % (attr, txt2xml(val), attr)
        txt += "  </content>\n"
        return txt

    @property
    def color(self):
        if self.name == 'Ghostfire' or \
                (self.text and 'devoid' in self.baseText.lower()):
            return Color()
        return Color.fromString((self.cost or '') + (self.color_indicator or ''))

    @property
    def colorID(self):
        # Since Innistrad, cards that formerly said "[This card] is [color]"
        # now have color indicators instead, so there's no need to check for
        # such strings.
        colors = self.color
        txt = self.baseText or ''
        # Reminder text is supposed to be ignored for the purposes of
        # establishing color identity, though (as of Dark Ascension) Charmed
        # Pendant and Trinisphere appear to be the only cards for which this
        # makes a difference.
        if re.search(r'\{(./)?W(/.)?\}', txt):
            colors |= Color.WHITE
        if re.search(r'\{(./)?U(/.)?\}', txt):
            colors |= Color.BLUE
        if re.search(r'\{(./)?B(/.)?\}', txt):
            colors |= Color.BLACK
        if re.search(r'\{(./)?R(/.)?\}', txt):
            colors |= Color.RED
        if re.search(r'\{(./)?G(/.)?\}', txt):
            colors |= Color.GREEN
        if self.isType('Land'):
            # Basic land types aren't _de jure_ part of color identity, but
            # rule 903.5d makes them a part _de facto_ anyway.
            if self.isSubtype('Plains'):
                colors |= Color.WHITE
            if self.isSubtype('Island'):
                colors |= Color.BLUE
            if self.isSubtype('Swamp'):
                colors |= Color.BLACK
            if self.isSubtype('Mountain'):
                colors |= Color.RED
            if self.isSubtype('Forest'):
                colors |= Color.GREEN
        return colors

    @property
    def cmc(self):
        if not self.cost:
            return 0
        cost = 0
        for c in split_mana(self.cost)[0]:
            m = re.search(r'(\d+)', c)
            if m:
                cost += int(m.group(1))
            elif any(ch in c for ch in 'WUBRGSwubrgs'):
                # This weeds out {X}, {Y}, etc.
                cost += 1
        return cost

    @property
    def type(self):
        return ' '.join(self.supertypes + self.types +
                        (('—',) + self.subtypes if self.subtypes else ()))

    def isSupertype(self, type_):
        return type_ in self.supertypes

    def isType(self, type_):
        return type_ in self.types

    def isSubtype(self, type_):
        return type_ in self.subtypes

    def hasType(self, type_):
        return self.isType(type_) or self.isSubtype(type_) \
                                  or self.isSupertype(type_)

    def isNontraditional(self):
        return self.isType('Vanguard')   or self.isType('Plane') \
            or self.isType('Phenomenon') or self.isType('Scheme')

    @property
    def PT(self):
        if self.power is not None:
            return '%s/%s' % (self.power, self.toughness)
        else:
            return None

    @property
    def HandLife(self):
        if self.hand is not None:
            return '%s/%s' % (self.hand, self.life)
        else:
            return None

    def __eq__(self, other):
        return type(self) is type(other) and vars(self) == vars(other)

    def __le__(self, other):
        if type(self) is type(other):
            return vars(self) <= vars(other)
        else:
            return NotImplemented

    @classmethod
    def fromDict(cls, obj):
        if isinstance(obj, cls):
            return obj.copy()
        else:
            return cls(**obj)

    @property
    def baseText(self):  # Returns rules text without reminder text
        if self.text is None:
            return None
        txt = re.sub(r'\([^()]+\)', '', self.text)
        # It is assumed that text is reminder text if & only if it's enclosed
        # in parentheses.
        return '\n'.join(filter(None, map(str.strip, txt.splitlines())))

    def __repr__(self):
        return cheap_repr(self)

    def jsonable(self):
        data = cleanDict(vars(self))
        if "color_indicator" in data:
            data["color_indicator"] = str(data["color_indicator"])
        return data

    def devotion(self, to_color):
        if not self.cost:
            return 0
        devot = 0
        for c in split_mana(self.cost)[0]:
            c = Color.fromString(c)
            if any(to_color & c):
                devot += 1
        return devot
