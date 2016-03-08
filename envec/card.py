import copy
from   functools  import total_ordering
from   itertools  import groupby, starmap, zip_longest
import re
from   .printing  import Printing
from   .color     import Color
from   .multipart import CardClass
from   ._util     import wrapLines, cheap_repr, for_json, split_mana

sep = ' // '

fields = {
    "name":       'Name:',
    "cost":       'Cost:',
    "cmc":        'CMC:',
    "color_indicator": 'Color:',
    "supertypes": 'Super:',
    "types":      'Types:',
    "subtypes":   'Sub:',
    "type":       'Type:',
    "text":       'Text:',
    "power":      'Power:',
    "toughness":  'Tough:',
    "loyalty":    'Loyalty:',
    "hand":       'Hand:',
    "life":       'Life:',
    "PT":         'P/T:',
    "HandLife":   'H/L:',
   #"printings":  'Printings:',
}

@total_ordering
class Card:
    def __init__(self, cardClass, name, types, cost=None, supertypes=(),
                 subtypes=(), text=None, power=None, toughness=None,
                 loyalty=None, hand=None, life=None, color_indicator=None,
                 secondary=None, printings=None, rulings=None):
        self.cardClass  = cardClass
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
        self.secondary  = secondary
        self.printings  = list(printings or []) # list of envec.Printing objects
        self.rulings    = list(rulings or [])
         # list of dicts with the following fields:
         #  - date
         #  - ruling
         #  - subcard - 0 or 1 (optional)
         # TODO: Create a `namedtuple` Rulings class?

    @classmethod
    def fromDict(cls, obj):
        if isinstance(obj, cls):
            return copy.deepcopy(obj)
        ### TODO: Move all of these transformations to __init__?
        cardClass = CardClass[obj.get("cardClass", "normal")]
        if obj.get("secondary") is not None:
            obj["secondary"] = cls.fromDict(obj["secondary"])
        obj["printings"] = map(Printing.fromDict, obj.get("printings", ()))
        return cls(**obj)

    @property
    def color(self):
        if self.name == 'Ghostfire' or \
                (self.text and 'devoid' in self.baseText.lower()):
            return Color.COLORLESS
        elif self.color_indicator is not None:
            return self.color_indicator
        else:
            return Color.fromString(self.cost or '')

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
        for c in Color.WUBRG:
            if re.search(r'\{(./)?' + c.name + r'(/.)?\}', txt):
                colors |= c
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
        if self.secondary is not None:
            colors |= self.secondary.colorID
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

    def devotion(self, to_color):
        if not self.cost:
            return 0
        devot = 0
        for c in split_mana(self.cost)[0]:
            c = Color.fromString(c)
            if any(to_color & c):
                devot += 1
        return devot

    ###
    @property
    def parts(self):
        return len(self.content)

    ###
    @property
    def part1(self):
        return self.content[0]

    ###
    @property
    def part2(self):
        return self.content[1] if len(self.content) > 1 else None

    ###
    def isMultipart(self):
        return self.parts > 1

    def isNormal(self):
        return self.cardClass == CardClass.normal

    def isSplit(self):
        return self.cardClass == CardClass.split

    def isFlip(self):
        return self.cardClass == CardClass.flip

    def isDouble(self):
        return self.cardClass == CardClass.double_faced

    def sets(self):
        return tuple(set(p.set for p in self.printings))

    def firstSet(self):
        return min(self.sets())

    def inSet(self, set_):
        return [p for p in self.printings if p.set == set_]

    @property
    def type(self):
        return ' '.join(self.supertypes + self.types +
                        (('—',) + self.subtypes if self.subtypes else ()))

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

    @property
    def baseText(self):  # Returns rules text without reminder text
        if self.text is None:
            return None
        txt = re.sub(r'\([^()]+\)', '', self.text)
        # It is assumed that text is reminder text if & only if it's enclosed
        # in parentheses.
        return '\n'.join(filter(None, map(str.strip, txt.splitlines())))

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

    tagwidth = 8  # may be modified externally

    ###
    def showField1(self, field, width=None):
        if not width:
            width = 79
        width = width - Card.tagwidth - 1
        if not field:
            return ''
        elif field == 'sets':
            def showPrnt(prnt):
                try:
                    rare = prnt.rarity.shortname
                except AttributeError:
                    rare = str(prnt.rarity)
                return prnt.set.name + ' (' + rare + ')'
            text = ', '.join(k for k,_ in groupby(map(showPrnt,
                                                      sorted(self.printings))))
            lines = wrapLines(text, width, 2)
            (first, rest) = (lines[0], lines[1:]) if lines else ('', [])
            return ''.join(["%-*s %s\n" % (Card.tagwidth, 'Sets:', first)] \
                         + [' ' * Card.tagwidth + ' ' + r + "\n" for r in rest])
        elif field == 'cardClass':
            return "%-*s %s\n" % (Card.tagwidth, 'Format:',
                                  self.cardClass.name.title())
        elif field in fields:
            width = (width - (self.parts - 1) * len(sep)) // self.parts
            def lineify(c):
                val = getattr(c, field)
                if val is None:
                    val = ''
                elif isinstance(val, (list, tuple)):
                    val = ' '.join(map(str, val))
                else:
                    val = str(val)
                return ['%-*s' % (width, s) for s in wrapLines(val, width, 2)]
            def joining(tag, *ls):
                line = sep.join(s or ' ' * width for s in ls).rstrip()
                return "%-*s %s\n" % (Card.tagwidth, tag, line)
            lines = map(lineify, self.content)
            return ''.join(starmap(joining, zip_longest([fields[field]], *lines, fillvalue='')))
        else:
            return ''

    def toText1(self, width=None, showSets=False):
        txt = self.showField1('name', width)
        txt += self.showField1('type', width)
        if self.cost:
            txt += self.showField1('cost', width)
        if self.color_indicator is not None:
            txt += self.showField1('color_indicator', width)
        if self.text:
            txt += self.showField1('text', width)
        if self.power is not None:
            txt += self.showField1('PT', width)
        if self.loyalty is not None:
            txt += self.showField1('loyalty', width)
        if self.hand is not None:
            txt += self.showField1('HandLife', width)
        if self.isMultipart():
            txt += self.showField1('cardClass', width)
        if showSets:
            txt += self.showField1('sets', width)
        return txt

    def __eq__(self, other):
        return type(self) is type(other) and vars(self) == vars(other)

    def __le__(self, other):
        if type(self) is type(other):
            return vars(self) <= vars(other)
        else:
            return NotImplemented

    def __repr__(self):
        return cheap_repr(self)

    def for_json(self):
        return for_json(vars(self), trim=True)
