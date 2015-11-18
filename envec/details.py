# -*- coding: utf-8 -*-
from   __future__ import unicode_literals
import logging
import re
from   bs4        import BeautifulSoup
from   six.moves.urllib.parse import urlparse, parse_qs

from   .card      import Card
from   .printing  import Printing
from   ._cardutil import joinCards
from   .color     import Color
from   .multipart import CardClass
from   ._util     import magicContent, trim, simplify, parseTypes, maybeInt

def parse_details(obj):
    doc = BeautifulSoup(obj, 'html.parser')
    parts = []
    for namediv in doc.find_all(id=endswith('nameRow')):
        parts.append(scrapeSection(doc, namediv['id'][:-len('nameRow')]))
    if len(parts) == 1:
        return parts[0]
    elif len(parts) == 2:
        return joinCards(CardClass.normal, *parts)
    else:
        raise ValueError('Card details page has too many components')

def scrapeSection(doc, pre):
    fields = {}
    prnt = {}
    for row in doc.find_all('div', id=startswith(pre)):
        key = row['id'][len(pre):]
        value = magicContent(row.find('div', class_='value'))
        if key == 'nameRow':
            fields['name'] = simplify(value)
        elif key == 'manaRow':
            fields['cost'] = ''.join(c for c in value if not c.isspace())
        elif key == 'typeRow':
            fields['supertypes'], fields['types'], fields['subtypes'] \
                = parseTypes(value)
        elif key == 'textRow':
            txt = multiline(row)
            # Unbotch mana symbols in Unglued cards:
            changes = 1
            while changes > 0:
                (txt, n1) = re.subn(r'\bocT\b', '{T}', txt, count=1)
                (txt, n2) = re.subn(r'\bo([WUBRGX]|\d+)', r'{\1}', txt, count=1)
                changes = n1 + n2
            fields['text'] = txt
        elif key == 'flavorRow':
            prnt['flavor'] = multiline(row)
        elif key == 'markRow':
            prnt['watermark'] = multiline(row)
        elif key == 'colorIndicatorRow':
            fields['indicator'] = Color.fromLongString(value)
        elif key == 'ptRow':
            label = simplify(magicContent(row.find('div', class_='label')))
            pt = simplify(value).replace('{^2}', '²').replace('{1/2}', '½')
            # Note that ½'s in rules texts (in details mode) are already
            # represented by ½.
            if label == 'P/T:':
                fields['power'], _, fields['toughness'] \
                    = [maybeInt(f.strip()) for f in pt.partition('/')]
            elif label == 'Loyalty:':
                fields['loyalty'] = maybeInt(pt)
            elif label == 'Hand/Life:':
                fields['hand'], fields['life'] \
                    = re.search(r'Hand Modifier: ?([-+]?\d+) ?,'
                                r' ?Life Modifier: ?([-+]?\d+)', pt, re.I)\
                        .groups()
            else:
                logging.warning('Unknown ptRow label for %s: %r',
                                fields['name'], label)
        elif key == 'currentSetSymbol':
            prnt0 = expansions(row)[0]
            prnt['set'] = prnt0.set
            prnt['rarity'] = prnt0.rarity
            prnt['multiverseid'] = prnt0.multiverseid
        elif key == 'numberRow':
            prnt['number'] = simplify(value)
        elif key == 'artistRow':
            prnt['artist'] = simplify(value)
        elif key == 'otherSetsValue':
            fields['printings'] = expansions(row)
        elif key == 'rulingsContainer':
            fields['rulings'] = []
            for tr in row.find_all('tr'):
                tds = tr.find_all('td')
                if len(tds) != 2:
                    continue
                (date, ruling) = map(magicContent, tds)
                fields['rulings'].append({
                    "date": simplify(date),
                    "ruling": trim(ruling)
                })
    fields.setdefault('printings', []).insert(0, Printing(**prnt))
    return Card.newCard(**fields)

def multiline(row):
    # There are some cards with superfluous empty cardtextboxes inserted into
    # their rules text for no good reason, and these empty lines should
    # probably be removed.  On the other hand, preserving empty lines is needed
    # for B.F.M.'s text to line up.
    txt = '\n'.join(m for n in row.find('div', class_='value')
                                  .find_all('div', class_=endswith('textbox'))
                      for m in [trim(magicContent(n))]
                      if m)
    return txt.rstrip("\n\r")
    # Trailing empty lines should definitely be removed, though.

def expansions(node):
    expands = []
    for a in node.find_all('a'):
        try:
            idval = parse_qs(urlparse(a['href']).query, strict_parsing=True)\
                            ['multiverseid'][0]
            src = parse_qs(urlparse(a.img['src']).query, strict_parsing=True)
        except (ValueError, TypeError, LookupError):
            continue
        expands.append(Printing(set=src.get('set', [None])[0],
                                rarity=src.get('rarity', [None])[0],
                                multiverseid=maybeInt(idval)))
    return expands

def endswith(end):
    return lambda s: s is not None and s.endswith(end)

def startswith(start):
    return lambda s: s is not None and s.startswith(start)
