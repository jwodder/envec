# -*- coding: utf-8 -*-
from   collections  import namedtuple
import re
from   urllib.parse import parse_qs, urlencode, urljoin, urlparse
import warnings
from   bs4          import BeautifulSoup
import requests
from   .card        import Card
from   .printing    import Printing
from   ._cardutil   import joinCards
from   .color       import Color
from   .multipart   import CardClass
from   ._util       import magicContent, maybeInt, parseTypes, simplify

__all__ = ['ChecklistPage', 'Tutor']

ChecklistPage = namedtuple('ChecklistPage', 'cards prev_url next_url')

class Tutor:
    SEARCH_PATH  = '/Pages/Search/Default.aspx'
    DETAILS_PATH = '/Pages/Card/Details.aspx'

    def __init__(self, endpoint='http://gatherer.wizards.com',
                       parser='html.parser'):
        self.session = requests.Session()
        self.endpoint = endpoint
        self.parser = parser

    def close(self):
        self.session.close()

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        self.close()
        return False

    def fetch_checklist(self, cardset):
        url = self.endpoint + self.SEARCH_PATH + '?' + urlencode({
            "output": "checklist",
            "action": "advanced",
            "set": '["' + str(cardset) + '"]',
            "special": "true",
        })
        while True:
            r = self.session.get(url)
            r.raise_for_status()
            page = self.parse_checklist_page(r.content, encoding=charset(r))
            for c in page.cards:
                yield c
            if page.next_url is None:
                return
            url = urljoin(r.request.url, page.next_url)

    def parse_checklist_page(self, html, encoding=None):
        cards = []
        doc = BeautifulSoup(html, self.parser, from_encoding=encoding)
        for tr in doc.find('table', class_='checklist')\
                     .find_all('tr', class_='cardItem'):
            item = {}
            for td in tr.find_all('td'):
                key = ' '.join(td['class'])
                value = simplify(magicContent(td))
                ### Use td.get_text() or td.stripped_strings instead?
                item[key] = value
                if key == 'name':
                    try:
                        url = td.a['href']
                    except (TypeError, KeyError):
                        pass
                    else:
                        item['multiverseid'] = url2id(url)
            cards.append(item)
        prev_url, next_url = None, None
        paging = doc.find('div', class_='pagingcontrols')
        if paging is not None:
            prev_url = paging.find('a',
                                   string=re.compile(r'^\s*<\s*$', flags=re.U))
            if prev_url is not None:
                prev_url = prev_url['href']
            next_url = paging.find('a',
                                   string=re.compile(r'^\s*>\s*$', flags=re.U))
            if next_url is not None:
                next_url = next_url['href']
        return ChecklistPage(cards=cards, prev_url=prev_url, next_url=next_url)

    def fetch_details(self, multiverseid, part=None):
        params = {"multiverseid": multiverseid}
        if part is not None:
            params["part"] = part
        # As of 2013 July 10, despite the fact that split cards in Gatherer now
        # have both halves on a single page like flip & double-faced cards, you
        # still need to append "&part=$name" to the end of their URLs or else
        # the page may non-deterministically display the halves in the wrong
        # order.
        r = self.session.get(self.endpoint + self.DETAILS_PATH, params=params)
        r.raise_for_status()
        return self.parse_details(r.content, encoding=charset(r))

    def parse_details(self, html, encoding=None):
        doc = BeautifulSoup(html, self.parser, from_encoding=encoding)
        parts = []
        for namediv in doc.find_all(id=endswith('nameRow')):
            parts.append(scrapeSection(doc, namediv['id'][:-len('nameRow')]))
        if len(parts) == 1:
            return parts[0]
        elif len(parts) == 2:
            return joinCards(CardClass.normal, *parts)
        else:
            raise ValueError('Card details page has too many components')


# Here be internal helper functions

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
            prnt['watermark'] = re.sub(r'<i>\s*|\s*</i>', '', multiline(row))
        elif key == 'colorIndicatorRow':
            fields['color_indicator'] = Color.fromLongString(value)
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
                warnings.warn('Unknown ptRow label for %s: %r',
                              fields['name'], label)
        elif key == 'currentSetSymbol':
            prnt0 = expansions(row)[0]
            prnt['set'] = prnt0.set
            prnt['rarity'] = prnt0.rarity
            prnt['multiverseid'] = prnt0.multiverseid
        elif key == 'numberRow':
            prnt['number'] = maybeInt(simplify(value))
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
                    "ruling": ruling.strip()
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
                      for m in [magicContent(n).strip()]
                      if m)
    return txt.rstrip("\n\r")
    # Trailing empty lines should definitely be removed, though.

def url2id(url):
    """ Extract the multiverseid parameter from a URL"""
    params = parse_qs(urlparse(url).query)
    if 'multiverseid' in params:
        return maybeInt(params['multiverseid'][0])
    else:
        return None

def expansions(node):
    expands = []
    for a in node.find_all('a'):
        try:
            idval = url2id(a['href'])
            src = parse_qs(urlparse(a.img['src']).query, strict_parsing=True)
        except (ValueError, TypeError, LookupError):
            continue
        if idval is not None:
            expands.append(Printing(set=src.get('set', [None])[0],
                                    rarity=src.get('rarity', [None])[0],
                                    multiverseid=idval))
    return expands

def endswith(end):
    return lambda s: s is not None and s.endswith(end)

def startswith(start):
    return lambda s: s is not None and s.startswith(start)

def charset(r):
    # Only use `r.encoding` if the response explicitly defined it; see
    # <http://stackoverflow.com/a/35383883/744178> and comments thereon for
    # more information
    if 'charset' in r.headers.get('content-type', '').lower():
        return r.encoding
    else:
        return None
