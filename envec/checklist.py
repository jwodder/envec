from   contextlib   import contextmanager
import re
from   bs4          import BeautifulSoup
import requests
from   urllib.parse import urljoin, urlparse, parse_qs, urlencode
from   ._util       import simplify, magicContent, maybeInt

SEARCH_ENDPOINT = 'http://gatherer.wizards.com/Pages/Search/Default.aspx'

def fetch_checklist(cardset, session=None):
    @contextmanager
    def maybeSession():
        ### This isn't Pythonic, is it?
        if session is None:
            s = requests.Session()
            yield s
            s.close()
        else:
            yield session
    url = SEARCH_ENDPOINT + '?' + urlencode({
        "output": "checklist",
        "action": "advanced",
        "set": '["' + str(cardset) + '"]',
        "special": "true",
    })
    with maybeSession() as s:
        while True:
            r = s.get(url)
            r.raise_for_status()
            cards, url = parse_checklist_page(r.text)
            for c in cards:
                yield c
            if url is None:
                return
            url = urljoin(r.request.url, url)

def parse_checklist_page(obj):
    ### TODO: also return the link to the previous page?
    cards = []
    doc = BeautifulSoup(obj, 'html.parser')
    for tr in doc.find('table', class_='checklist')\
                 .find_all('tr', class_='cardItem'):
        item = {}
        for td in tr.find_all('td'):
            key = ' '.join(td['class'])
            value = simplify(magicContent(td))
            item[key] = value
            if key == 'name':
                try:
                    url = td.a['href']
                except (TypeError, KeyError):
                    pass
                else:
                    params = parse_qs(urlparse(url).query)
                    if 'multiverseid' in params:
                        item['multiverseid'] = maybeInt(params['multiverseid'][0])
        cards.append(item)
    nextlink = doc.find('div', class_='pagingcontrols')\
                  .find('a', string=re.compile(r'^\s*>\s*$', flags=re.U))
    if nextlink is not None:
        nextlink = nextlink['href']
    return (cards, nextlink)
