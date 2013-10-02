# -*- coding: utf-8 -*-
import json
from envec.card.content  import Content
from envec.card.printing import Printing
from envec.card.util     import sortPrintings
from envec.colors        import Color
from envec.multipart     import NORMAL_CARD, SPLIT_CARD, FLIP_CARD, DOUBLE_CARD, classEnum
from envec.sets          import getCardSetDB
from envec.util          import uniq, wrapLines, jsonify, txt2attr, txt2xml

formats = {NORMAL_CARD: 'normal',
	   SPLIT_CARD:  'split',
	   FLIP_CARD:   'flip',
	   DOUBLE_CARD: 'double-faced'}

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
 "pow":        'Power:',
 "tough":      'Tough:',
 "loyalty":    'Loyalty:',
 "hand":       'Hand:',
 "life":       'Life:',
 "PT":         'P/T:',
 "HandLife":   'H/L:',
#"printings":  'Printings:',
}

shortRares = {"common":      'C',
	      "uncommon":    'U',
	      "rare":        'R',
	      "land":        'L',
	      "mythic rare": 'M'}

def scalarField(field):
    def getter(self):
	fields = [getattr(c, field) for c in self.content]
	if all(f is None for f in fields): return None
	#else: return tuple(fields)
	#else: return tuple(fields) if len(fields) > 1 else fields[0]
	else: return sep.join(f or '' for f in fields)
    return property(getter)

class Card(object):
    def __init__(self, cardClass, content, printings=[], rulings=[]):
	self.cardClass = cardClass
	self.content   = content    # list of EnVec::Card::Content objects
	self.printings = printings  # list of EnVec::Card::Printing objects
	self.rulings   = rulings
	 # list of dicts with the following fields:
	 #  - date
	 #  - ruling
	 #  - subcard - 0 or 1 (optional)

    @classmethod
    def newCard(cls, **attrs):
	content = {}
	for field in ["name", "cost", "text", "pow", "tough", "loyalty",
		      "hand", "life", "indicator", "supertypes", "types",
		      "subtypes"]:
	    if field in attrs:
		content[field] = attrs[field]
	attrs2 = attrs.copy()
	attrs2["content"] = [content]
	return cls.fromDict(attrs2)

    @classmethod
    def fromJSON(cls, txt):
	obj = json.loads(txt) # This throws an exception on parse errors, right?
	return cls.fromDict(obj)

    @classmethod
    def fromDict(cls, obj):  # called `fromHashref` in the Perl version
	if isinstance(obj, cls): return obj.copy()
	cardClass = classEnum(obj.get("cardClass"), NORMAL_CARD)
	content = obj.get("content")
	if isinstance(content, list):
	    if not content:
		raise ValueError("'content' field must be a nonempty list")
	    content = map(Content.fromDict, content)
	else:
	    content = [Content.fromDict(content)]
	printings = map(Printing.fromDict, obj.get("printings", []))
	rulings = obj.get("rulings", [])
	#if rulings is None: rulings = []
	#if not isinstance(rulings, list):
	#    raise TypeError("'rulings' field must be a list")
	return cls(cardClass, content, printings, rulings)

    def toJSON(self):
	return ' {\n  "cardClass": "' + formats[self.cardClass] + '",\n' \
	 + '  "content": [' \
	 + ', '.join(c.toJSON() for c in self.content) \
	 + '],\n' \
	 + '  "printings": [\n     ' \
	 + '\n   , '.join(p.toJSON() for p in self.printings) \
	 + '\n  ],\n' \
	 + '  "rulings": [' \
	 + ('\n     ' + '\n   , '.join(map(jsonify, self.rulings)) + '\n  ' \
	    if self.rulings else '') \
	 + ']\n' \
	 + ' }'

    def toXML(self):
	txt = ' <card cardClass="' + txt2attr(formats[self.cardClass]) + '">\n'
	for c in self.content:   txt += c.toXML()
	for p in self.printings: txt += p.toXML()
	for rule in self.rulings:
	    txt += '  <ruling date="' . txt2attr(rule["date"]) . '"'
	    if "subcard" in rule:
		txt += ' subcard="' . txt2attr(rule["subcard"]) . '"'
	    txt += '>' . txt2xml(rule["ruling"]) . '</ruling>\n'
	txt += ' </card>\n'
	return txt

    @property
    def color(self):   return Color(*[c.color   for c in self.content])

    @property
    def colorID(self): return Color(*[c.colorID for c in self.content])

    @property
    def cmc(self):
	if self.cardClass == FLIP_CARD: return self.part1.cmc
	else: return sum(c.cmc for c in self.content)

    @property
    def parts(self): return len(self.content)

    @property
    def part1(self): return self.content[0]

    @property
    def part2(self): return self.content[1] if len(self.content) > 1 else None

    def isMultipart(self): return self.parts > 1
    def isNormal(self):    return self.cardClass == NORMAL_CARD
    def isSplit(self):     return self.cardClass == SPLIT_CARD
    def isFlip(self):      return self.cardClass == FLIP_CARD
    def isDouble(self):    return self.cardClass == DOUBLE_CARD

    def sets(self): return list(set(p.set_ for p in self.printings))

    def firstSet(self): return getCardSetDB().firstSet(self.sets())

    def inSet(self, set_): return [p for p in self.printings if p.set_ == set_]

    name      = scalarField("name")
    text      = scalarField("text")
    pow       = scalarField("pow")
    tough     = scalarField("tough")
    loyalty   = scalarField("loyalty")
    hand      = scalarField("hand")
    life      = scalarField("life")
    indicator = scalarField("indicator")
    type      = scalarField("type")
    PT        = scalarField("PT")
    HandLife  = scalarField("HandLife")

    @property
    def supertypes(self): return [t for c in self.content for t in c.supertypes]

    @property
    def types(self): return [t for c in self.content for t in c.types]

    @property
    def subtypes(self): return [t for c in self.content for t in c.subtypes]

    @property
    def cost(self):
	if self.isNormal() or self.isSplit():
	    return sep.join(c.cost or '' for c in self.content)
	else:
	    return self.part1.cost

    def isSupertype(self, type_): return type_ in self.supertypes()
    def isType(self, type_):      return type_ in self.types()
    def isSubtype(self, type_):   return type_ in self.subtypes()

    def hasType(self, type_):
	return self.isType(type_) or self.isSubtype(type_) \
				  or self.isSupertype(type_)

    def isNontraditional(self):
	return self.isType('Vanguard')   or self.isType('Plane') \
	    or self.isType('Phenomenon') or self.isType('Scheme')

    def copy(self): return Card(self.cardClass,
				[c.copy() for c in self.content],
				[p.copy() for p in self.printings],
				[r.copy() for r in self.rulings])

    tagwidth = 8  # may be modified externally

    def showField1(self, field, width=None):
	if not width: width = 79
	width = width - Card.tagwidth - 1
	if not field: return ''
	elif field == 'sets':
	    def showPrnt(prnt):
		rare = prnt.rarity or 'UNKNOWN'
		return prnt.set_ \
		     + ' (' + shortRares.get(rare.lower(), rare) + ')'
	    text = ', '.join(uniq(map(showPrnt, sortPrintings(self.printings))))
	    lines = wrapLines(text, width, 2)
	    (first, rest) = (lines[0], lines[1:]) if lines else ('', [])
	    return ''.join(["%-*s %s\n" % (Card.tagwidth, 'Sets:', first)] \
			 + [' ' * Card.tagwidth + ' ' + r + "\n" for r in rest])
	elif field == 'cardClass':
	    return "%-*s %s\n" % (Card.tagwidth, 'Format:',
		formats.get(self.cardClass, str(self.cardClass)).title())
	elif field in fields:
	    width = (width - (self.parts - 1) * len(sep)) // self.parts
	    def lineify(c):
		val = getattr(self, field)
		if val is None: val = ''
		elif isinstance(val, list): val = ' '.join(val)
		val = val.replace('—', '--')
		return ['%-*s' % (width, s) for s in wrapLines(val, width, 2)]
	    def joining(tag, *ls):
		line = sep.join(s or ' ' * width for s in ls).rstrip()
		return "%-*s %s\n" % (Card.tagwidth, tag or '', line)
	    lines = map(lineify, self.content)
	    return ''.join(map(joining([fields[field]], *lines)))
	else: return ''

    def toText1(self, width=None, showSets=False):
	txt = self.showField1('name', width)
	txt += self.showField1('type', width)
	if self.cost: txt += self.showField1('cost', width)
	if self.indicator is not None:
	    txt += self.showField1('indicator', width)
	if self.text:                txt += self.showField1('text',      width)
	if self.pow     is not None: txt += self.showField1('PT',        width)
	if self.loyalty is not None: txt += self.showField1('loyalty',   width)
	if self.hand    is not None: txt += self.showField1('HandLife',  width)
	if self.isMultipart():       txt += self.showField1('cardClass', width)
	if showSets:                 txt += self.showField1('sets',      width)
	return txt
