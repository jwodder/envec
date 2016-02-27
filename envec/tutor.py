from   collections  import namedtuple
import re
from   bs4          import BeautifulSoup
import requests
from   urllib.parse import urljoin, urlparse, parse_qs, urlencode
from   ._util       import simplify, magicContent, maybeInt

ChecklistPage = namedtuple('ChecklistPage', 'cards prev_url next_url')

class Tutor:
    SEARCH_PATH = '/Pages/Search/Default.aspx'

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
            page = parse_checklist_page(r.text)
            for c in page.cards:
                yield c
            if page.next_url is None:
                return
            url = urljoin(r.request.url, page.next_url)

    @staticmethod
    def parse_checklist_page(html):
        cards = []
        doc = BeautifulSoup(html, self.parser)
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
                        params = parse_qs(urlparse(url).query)
                        if 'multiverseid' in params:
                            item['multiverseid'] = \
                                maybeInt(params['multiverseid'][0])
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
