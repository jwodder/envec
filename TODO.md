- Properly handle JSONification and un-JSONification of CardSets in Printings
    - Go back to serializing just the set names?
        - Also serialize a top-level dict of all the CardSets?
    - Update cards.json to allow sets to be set objects as from
      sets-schema.json?
- Problem: Because `Color` is a `namedtuple`, the json module automatically
  JSONifies it as a list instead of letting EnVecEncoder handle it
- Eliminate XML output?

# Robustness

- Give `tutor.py` better error handling for, e.g., failed HTTP requests
- Make `listify.py`'s references to external images for `\img` work for other
  people
- Ensure `Printing.set` and `Printing.rarity` are always values of the
  appropriate types?

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
- Give the classes `toDict`/`_asdict` methods? (i.e., recursive `jsonable`s)

# Coding

- Give all classes "copy constructors"
- Eliminate Card.newCard?
- Should "oversized" or "nontraditional" be a card class?
- Make the bulk of tutor.py into a library function?
    - Move the code for fetching & merging together all of a card's printings
      from tutor.py into the library proper
    - Add a wrapper around `parse_details` that downloads and parses a given
      multiverseid?
- Add a JSONDecoder subclass?
- Add a class for rulings
- Store & access files in `data/` as `package_data`
- Look for a better/more standard name for `jsonable`
- Make `text` and `baseText` (and `cost`?) equal `''` rather than `None` when
  empty/absent?
- Change all tuple attributes to lists?
- Rethink the necessity of `cleanDict`

## Redo Handling of Multipart Cards and Their Printing Fields

- Possible replacements for/alterations to `Content`:
    - Instead of a list of Content objects, instead make Cards have a "primary"
      Content attribute and a nullable "secondary" Content attribute?
    - Make a single `Card` object store all of the content information for the
      primary component, with a nullable `secondary` (or `alternate`?) field
      containing a `Card` for the other component
        - A `Card`'s various attributes will only return data for that
          component (except colorID, which must take both components into
          account), with variant attributes that return a tuple of values for
          all components.
        - also add attributes/methods for querying split cards while respecting
          their dual nature?
        - This won't support Who/What/When/Where/Why, but what will?
        - Each Card object stores the rulings for that component; rulings are
          not merged.
        - Should printing information also be divided between Card objects?

- Possible replacements for `Multival`:
    - Make Printing objects store lists of "ComponentPrinting" (or something)
      objects, with special handling for multiverseids
    - lists of `{"subcard": INT, "value": INT | STR}` objects?
    - Divide printing information up into three dicts: fields shared by all
      components, fields unique to the first component, and fields unique to
      the last component

- Rethink the Multival.get method
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
    - expansion symbols for cards from Chronicles and Anthologies?
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
    - Also fetch text (printed & Oracle?) in other languages?
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
