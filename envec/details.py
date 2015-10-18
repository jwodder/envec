!!! TODO: Implement getElementById !!!

# -*- coding: utf-8 -*-
import re
from warnings import warn
from xml.dom.minidom import parseString

from envec.card          import Card
from envec.card.printing import Printing
from envec.card.util     import joinCards
from envec.colors        import Color
from envec.multipart     import CardClass
from envec.util          import magicContent, trim, simplify, parseTypes, openR

def parseDetails(txt):
    # Work around italicization farkup:
    txt = re.sub(r'</i>([^<>]+)</i>', r'\1', txt, flags=re.I)
    txt = re.sub(r'\r\n?', "\n", txt)
    doc = parseString(txt)
    pre = 'ctl00_ctl00_ctl00_MainContent_SubContent_SubContent_'
    if doc.getElementById(pre + "nameRow"): return scrapeSection(doc, pre)
    else:
        # Split, flip, double-faced, or B.F.M.
        parts = []
        for i in xrange(11):
            prefix = '%sctl%02d_' % (pre, i)
            if doc.getElementById(prefix + 'nameRow'):
                parts.append(scrapeSection(doc, prefix))
        if len(parts) == 2: return joinCards(CardClass.NORMAL_CARD, *parts)
        else:
            raise ValueError('multipart details page has too %s parts'
                             % ('many' if len(parts) > 2 else 'few',))

def loadDetails(filename):
    fp = openR(filename)
    txt = fp.read()
    fp.close()
    return parseDetails(txt)

def divsByClass(node, dclass):
    if not node: return []
    return [n for n in node.childNodes if n.nodeName == 'div'
                                      and n.getAttribute('class') == dclass]

def rowVal(node):
    val = divsByClass(node, 'value')
    return magicContent(val[0]) if val else None

def multiline(row):
    if not row: return None
    txt = "\n".join(filter(None,
     # There are some cards with superfluous empty cardtextboxes inserted into
     # their rules text for no good reason, and these empty lines should
     # probably be removed.  On the other hand, preserving empty lines is
     # needed for B.F.M.'s text to line up.
     [trim(magicContent(n))  ### simplify instead of trim?
      for n in divsByClass(divsByClass(row, 'value')[0], 'cardtextbox')]))
    return txt.rstrip("\n\r")
     # Trailing empty lines should definitely be removed.

def matchGroup(regex, txt):
    m = re.search(regex, txt)
    return m.group(1) if m else None

def expansions(node):
    if not node: return []
    expands = []
    for a in node.getElementsByTagName('a'):
        idval = matchGroup(r'\bmultiverseid=(\d+)', a.getAttribute('href'))
        if idval is None: continue
        img = list(a.getElementsByTagName('img'))
        if not img: continue
        src = img[0].getAttribute('src')
        if not src: continue
        set_ = matchGroup(r'\bset=(\w+)', src)
        rarity = matchGroup(r'\brarity=(\w+)', src)
        expands.append(Printing(set=set_, rarity=rarity, multiverseid=idval))
    return expands

def scrapeSection(doc, pre):
    fields = {}
    prnt = {}
    fields['name'] = simplify(rowVal(doc.getElementById(pre + "nameRow")))
    fields['cost'] = rowVal(doc.getElementById(pre + "manaRow"))
    if fields['cost']:
        fields['cost'] = filter(lambda c: not c.isspace(), fields['cost'])
    (fields['supertypes'], fields['types'], fields['subtypes']) \
     = parseTypes(rowVal(doc.getElementById(pre + "typeRow")))
    fields['text'] = multiline(doc.getElementById(pre + "textRow"))
    if fields['text'] is not None:
        # Unbotch mana symbols in Unglued cards:
        changes = 1
        txt = fields['text']
        while changes > 0:
            (txt, n1) = re.subn(r'\bocT\b', '{T}', txt, count=1)
            (txt, n2) = re.subn(r'\bo([WUBRGX]|\d+)', r'{\1}', txt, count=1)
            changes = n1 + n2
        fields['text'] = txt
    prnt['flavor'] = multiline(doc.getElementById(pre + "flavorRow"))
    prnt['watermark'] = multiline(doc.getElementById(pre + "markRow"))
    fields['indicator'] = Color.fromLongString(rowVal(doc.getElementById(pre
                                                       + "colorIndicatorRow")))
    ptRow = doc.getElementById(pre + "ptRow")
    if ptRow:
        label = simplify(magicContent(divsByClass(ptRow, 'label')[0]))
        pt = simplify(rowVal(ptRow))
        pt = pt.replace('{^2}', '²')  # S.N.O.T.
        pt = pt.replace('{1/2}', '½')
        # Note that ½'s in rules texts (in details mode) are already
        # represented by ½.
        if label == 'P/T:':
            (fields['pow'], fields['tough']) \
             = re.search(r'^([^/]+?) ?/ ?(.+?)$', pt).groups()
        elif label == 'Loyalty:':
            fields['loyalty'] = pt
        elif label == 'Hand/Life:':
            (fields['hand'], fields['life']) = re.search(r'Hand Modifier: ?([-+]?\d+) ?, ?Life Modifier: ?([-+]?\d+)', pt, re.I).groups()
        else:
            warn("Unknown ptRow label for %s: %r" % (fields['name'], label))
    prnt0 = expansions(doc.getElementById(pre + "currentSetSymbol"))[0]
    prnt['number'] = simplify(rowVal(doc.getElementById(pre + "numberRow")))
    prnt['artist'] = simplify(rowVal(doc.getElementById(pre + "artistRow")))
    fields['printings'] = \
     [Printing(set=prnt0.set_, rarity=prnt0.rarity,
               multiverseid=prnt0.multiverseid, **prnt)] \
     + expansions(doc.getElementById(pre + "otherSetsValue"))
    rulings = doc.getElementById(pre + "rulingsContainer")
    fields['rulings'] = []
    if rulings:
        for tr in rulings.getElementsByTagName('tr'):
            tds = tr.getElementsByTagName('td')
            if len(tds) != 2: continue
            (date, ruling) = map(magicContent, tds)
            fields['rulings'].append({"date": simplify(date),
                                      "ruling": trim(ruling)})
    return Card.newCard(**fields)
