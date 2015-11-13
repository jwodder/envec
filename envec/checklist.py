import re
from   ._util import simplify, magicContent
from   bs4    import BeautifulSoup

def parseChecklist(obj):
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
                    m = re.search(r'\bmultiverseid=(\d+)\b', url)
                    if m:
                        item['multiverseid'] = m.group(1)
        cards.append(item)
    nextlink = doc.find('div', class_='pagingcontrols')\
                  .find('a', string=re.compile(r'^\s*>\s*$', flags=re.U))
    if nextlink is not None:
        nextlink = nextlink['href']
    return (cards, nextlink)
