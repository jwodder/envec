import re
from   urllib   import urlencode
from   urlparse import urljoin, urlparse, parse_qs
from   bs4      import BeautifulSoup
import requests
from   ._util   import simplify, magicContent

SEARCH_ENDPOINT = 'http://gatherer.wizards.com/Pages/Search/Default.aspx'

def fetch_checklist(cardset):
    url = SEARCH_ENDPOINT + '?' + urlencode({
        "output": "checklist",
        "action": "advanced",
        "set": '["' + str(cardset) + '"]',
        "special": "true",
    })
    with requests.Session() as s:
        while url is not None:
            r = s.get(url)
            r.raise_for_status()
            cards, url = parse_checklist_page(r.text)
            for c in cards:
                yield c
            if url is not None:
                url = urljoin(r.request.url, url)

def parse_checklist_page(obj):
    cards = []
    doc = BeautifulSoup(obj, 'html.parser')
    for tr in doc.find('table', class_='checklist')\
                 .find_all('tr', class_='cardItem'):
        item = {}
        for td in tr.find_all('td'):
            key = ' '.join(td['class'])
            #value = td.get_text()
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
                        item['multiverseid'] = params['multiverseid'][0]
        cards.append(item)
    nextlink = doc.find('div', class_='pagingcontrols')\
                  .find('a', string=re.compile(r'^\s*>\s*$', flags=re.U))
    if nextlink is not None:
        nextlink = nextlink['href']
    return (cards, nextlink)
