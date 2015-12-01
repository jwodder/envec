- Properly handle JSONification and un-JSONification of CardSets in Printings
    - Go back to serializing just the set names?
        - Also serialize a top-level dict of all the CardSets?
    - Update cards.json to allow sets to be set objects as from
      sets-schema.json?
- Ensure `Printing.set` and `Printing.rarity` are always values of the
  appropriate types?
- Problem: Because `Color` is a `namedtuple`, the json module automatically
  JSONifies it as a list instead of letting EnVecEncoder handle it
- Move EnVecEncoder's filtering out of `None` and `''` values to the individual
  `jsonable` methods?
- Look for a better/more standard name for `jsonable`
- Eliminate XML output?

# Robustness

- Give `tutor.py` better error handling for, e.g., failed HTTP requests
- Make `listify.py`'s references to external images for `\img` work for other
  people

# Features

- `tutor.py`:
    - Incorporate data/rarities.tsv (adding an "old-rarity" field to
      `Printing`)
    - Somehow handle split cards with differing artists for each half
- `listify.py`:
    - Improve PostScript output
    - Add checkboxes to the output (but only if a flag is given?)
    - Implement single-file LaTeX & PostScript output
- Add special handling/storage for leveler cards
- Add a means to read Card objects from an XML file one at a time rather than
  all at once
- Give Card a fromXML method?
- Card.showField1 should treat a negative width as disabling line-wrapping
- Give Content a "devotion" method
- Give the classes `toDict`/`_asdict` methods? (i.e., recursive `jsonable`s)
- Add a function for splitting mana costs into a list of one string per mana
  symbol

# Coding

- Make the storage of Content.text fields mirror their representation in
  mtgcard.dtd
- Make the default datafile paths absolute rather than relative (possibly with
  a way to set the datafile directory at runtime?)
- Rethink the Multival.get method
- Give all classes "copy constructors"
- Eliminate Card.newCard?
- Should "oversized" or "nontraditional" be a card class?
- Move the code for fetching & merging together all of a card's printings from
  tutor.py into the library proper
- Add a JSONDecoder subclass?
- Add a class for rulings
- Make the bulk of tutor.py into a library function?

## Redo Handling of Multipart Cards and Their Printing Fields

- Ideas for new data structures:
    - Instead of Multivals, make Printing objects store lists of
      "ComponentPrinting" (or something) objects, with special handling for
      multiverseids
    - Instead of Card objects having a list of Content objects, instead make
      them have a "primary" Content attribute and a nullable "secondary"
      Content attribute?
    - Replace Multivals with lists of `{"subcard": INT, "value": INT | STR}`
      objects?
    - Eliminate Multivals by dividing printing information up into three dicts:
      fields shared by all components, fields unique to the first component,
      and fields unique to the last component
    - Eliminate `Content` and make a single `Card` object store all of the
      content information for the primary component, with a nullable
      `secondary` field containing a `Card` for the other component
        - A `Card`'s various fields will only return data for that component
          (except colorID, which must take both components into account), with
          variant fields that return a tuple of values for all components.
        - This won't support Who/What/When/Where/Why, but what will?
- Should subcard numbering in XML output (and internal rulings representation,
  et alii?) start from 1 for the first part rather than 0?
- Make it so that only multiverseid fields can have multiple values per
  component

# Data & Documentation

- Add documentation
- Rewrite `spoilers/*` so that it makes sense to other people
- For the multiversion cards in rarities.tsv, give each entry a field for the
  multiverseid and another field for a short description (to become the
  'notes' field) that a mortal can use to identify the version
- Add files to data/ for:
    - Promo cards not in Gatherer
    - The release dates of the various promo cards
    - The release dates of the different Vanguard card sets
    - The Anthologies, Deckmasters, & Duels of the Planeswalkers (et alii?)
      sets and any other sets not in Gatherer
    - Multiversion cards not in rarities.tsv (e.g., alternate-art foils from
      Planeshift, Brothers Yamazaki, ???)
- Add the rest of the Twitter hashtags to sets.json

# For Later

- Make use of all of the unused data/ files
- Implement `Card.showField1('printings')`
- Better handling of Uncards, specifically:
    - B.F.M.
    - Who/What/When/Where/Why
    - Curse of the Fire Penguin
    - Little Girl's CMC
    - Should fractional P/T's be stored as floats rather than as strings with
      '½'?
    - How should mtgcard.dtd handle fractional mana symbols?
    - Give all Uncards an attribute marking them as such?
- Support fetching & storing format legality information
    - Note that Gatherer has been known to be out of date regarding Commander
      format legality
- Add a function for parsing an individual card page for printed (rather than
  Oracle) text
- Add elements to mtgcard.dtd for storing printed text, expansion symbols,
  card language, etc.
- Add a wrapper around parseDetails that downloads and parses a given
  multiverseid?
- Overload stringification of Multival objects?
- Add fields to sets.json for:
    - whether a set is online-only?
    - number of cards
    - maximum collector's number (only worth noting for Unhinged, M15, and
      Magic Origins)
    - printed abbreviation (M15+)
    - "codename" used during development; see
      <http://archive.wizards.com/Magic/magazine/article.aspx?x=mtgcom/daily/mr33>,
      among other sources
    - whether the set had foil/premium cards, no foil cards, or only foil cards
    - dates of prereleases etc.?
- Store card data in actual SQL databases rather than flat JSON/XML files
