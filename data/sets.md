- Set names are as listed on Gatherer.
- Release dates of old sets are taken from
  <http://en.wikipedia.org/wiki/List_of_Magic:_The_Gathering_sets>
- The "fetch" fields indicate which sets to scrape in order to get a list of
  all cards with a (hopefully) minimum number of HTTP requests.
- Sets not listed in Gatherer (e.g., Anthologies, Deckmasters 2001) are not
  included.
- The "askwizards-20040812" abbreviations are taken from <http://archive.wizards.com/Magic/magazine/article.aspx?x=mtgcom/askwizards/0804>

- Fields for each entry:
    - name (not nullable)
    - `elease_date (nullable)
    - fetch (boolean)
    - abbreviations; dictionary with the following keys:
        - Gatherer
        - [askwizards-20040812][askwizards]
        - magiccards.info
        - Twitter
    - type (expansion, core set, duel decks, premium deck series, etc.)
    - block (nullable)
    - modern (boolean)
    - border (black, white, silver, or gold)
    - online only (boolean)
    - promotional (boolean) ?
    - development codenames?
        - See <http://archive.wizards.com/Magic/magazine/article.aspx?x=mtgcom/daily/mr33> et alii
    - prerelease etc. dates?
    - foil/premium? ("no foil", "foil", "foil-only")
    - notes (list of strings)

[askwizards]: http://archive.wizards.com/Magic/magazine/article.aspx?x=mtgcom/askwizards/0804
