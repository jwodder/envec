from itertools  import starmap, zip_longest
from .content   import Content
from .printing  import Printing
from .color     import Color
from .multipart import CardClass
from ._util     import uniq, wrapLines, txt2attr, txt2xml, cheap_repr

sep = ' // '

fields = {
    "name":       'Name:',
    "cost":       'Cost:',
    "cmc":        'CMC:',
    "indicator":  'Color:',
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

def scalarField(field):
    def getter(self):
        fields = [getattr(c, field) for c in self.content]
        if all(f is None for f in fields):
            return None
        else:
            #return tuple(fields)
            #return tuple(fields) if len(fields) > 1 else fields[0]
            return sep.join(str(f) or '' for f in fields)
    return property(getter)

class Card:
    def __init__(self, cardClass, content, printings=None, rulings=None):
        self.cardClass = cardClass
        self.content   = list(content)         # list of envec.content objects
        self.printings = list(printings or []) # list of envec.printing objects
        self.rulings   = list(rulings or [])
         # list of dicts with the following fields:
         #  - date
         #  - ruling
         #  - subcard - 0 or 1 (optional)
         # TODO: Create a `namedtuple` Rulings class?

    @classmethod
    def newCard(cls, **attrs):
        content = {}
        for field in ("name", "cost", "text", "power", "toughness", "loyalty",
                      "hand", "life", "indicator", "supertypes", "types",
                      "subtypes"):
            if field in attrs:
                content[field] = attrs[field]
        attrs2 = attrs.copy()
        attrs2["content"] = [content]
        return cls.fromDict(attrs2)

    @classmethod
    def fromDict(cls, obj):
        if isinstance(obj, cls):
            return obj.copy()
        ### TODO: Move all of these transformations to __init__?
        cardClass = CardClass[obj.get("cardClass", "normal")]
        content = obj["content"]
        if isinstance(content, (list, tuple)):
            if not content:
                raise ValueError("'content' field must be a nonempty list")
            content = map(Content.fromDict, content)
        else:
            content = [Content.fromDict(content)]
        printings = map(Printing.fromDict, obj.get("printings", ()))
        rulings = obj.get("rulings", [])
        return cls(cardClass, content, printings, rulings)

    def toXML(self):
        txt = ' <card cardClass="' + txt2attr(self.cardClass.name) + '">\n'
        for c in self.content:
            txt += c.toXML()
        for p in self.printings:
            txt += p.toXML()
        for rule in self.rulings:
            txt += '  <ruling date="' + txt2attr(rule["date"]) + '"'
            if "subcard" in rule:
                txt += ' subcard="' + txt2attr(rule["subcard"]) + '"'
            txt += '>' + txt2xml(rule["ruling"]) + '</ruling>\n'
        txt += ' </card>\n'
        return txt

    @property
    def color(self):
        return Color.union(*[c.color   for c in self.content])

    @property
    def colorID(self):
        return Color.union(*[c.colorID for c in self.content])

    @property
    def cmc(self):
        if self.cardClass == CardClass.flip:
            return self.part1.cmc
        else:
            return sum(c.cmc for c in self.content)

    @property
    def parts(self):
        return len(self.content)

    @property
    def part1(self):
        return self.content[0]

    @property
    def part2(self):
        return self.content[1] if len(self.content) > 1 else None

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

    name      = scalarField("name")
    text      = scalarField("text")
    power     = scalarField("power")
    toughness = scalarField("toughness")
    loyalty   = scalarField("loyalty")
    hand      = scalarField("hand")
    life      = scalarField("life")
    indicator = scalarField("indicator")
    type      = scalarField("type")
    PT        = scalarField("PT")
    HandLife  = scalarField("HandLife")
    baseText  = scalarField("baseText")

    @property
    def supertypes(self):
        return (t for c in self.content for t in c.supertypes)

    @property
    def types(self):
        return (t for c in self.content for t in c.types)

    @property
    def subtypes(self):
        return (t for c in self.content for t in c.subtypes)

    @property
    def cost(self):
        if self.isNormal() or self.isSplit():
            return sep.join(c.cost or '' for c in self.content)
        else:
            return self.part1.cost

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

    def copy(self):
        return self.__class__(self.cardClass,
                              [c.copy() for c in self.content],
                              [p.copy() for p in self.printings],
                              [r.copy() for r in self.rulings])

    tagwidth = 8  # may be modified externally

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
            text = ', '.join(uniq(map(showPrnt, sorted(self.printings))))
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
                val = val.replace('\u2014', '--')
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
        if self.indicator is not None:
            txt += self.showField1('indicator', width)
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

    def __repr__(self):
        return cheap_repr(self)

    def jsonable(self):
        return vars(self)
