import re
from xml.dom.minidom import parse, parseString
from ._util import simplify, magicContent

def parseChecklist(txt): return walkChecklist(parseString(txt))

def loadChecklist(fileish): return walkChecklist(parse(fileish))

def walkChecklist(doc):
    ### TODO: Make this use `yield`?
    cards = []
    for table in doc.getElementsByTagName('table'):
        tblClass = table.getAttribute('class')
        if tblClass != 'checklist': continue
        for tr in table.getElementsByTagName('tr'):
            trClass = tr.getAttribute('class')
            if trClass != 'cardItem': continue
            item = {}
            for td in tr.getElementsByTagName('td'):
                key = td.getAttribute('class')
                value = simplify(magicContent(td))
                item[key] = value
                if key == 'name':
                    url = td.getElementsByTagName('a')[0].getAttribute('href')
                    if url:
                        m = re.search(r'\bmultiverseid=(\d+)', url)
                        if m: item['multiverseid'] = m.group(1)
            cards.append(item)
        break
    return cards
