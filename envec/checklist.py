import re
from   ._util import simplify, magicContent
from   bs4    import BeautifulSoup

def parseChecklist(obj):
    ### TODO: Make this use `yield`?
    ### TODO: Return namedtuples instead of dicts
    cards = []
    doc = BeautifulSoup(obj, 'html.parser')
    for table in doc.find_all('table'):
        if 'checklist' not in table['class']:
            continue
        for tr in table.find_all('tr'):
            if 'cardItem' not in tr['class']:
                continue
            item = {}
            for td in tr.find_all('td'):
                key = td['class'][0]
                #value = td.get_text()
                value = simplify(magicContent(td))
                item[key] = value
                if key == 'name':
                    url = td.a['href']
                    if url:
                        m = re.search(r'\bmultiverseid=(\d+)', url)
                        if m:
                            item['multiverseid'] = m.group(1)
            cards.append(item)
        break
