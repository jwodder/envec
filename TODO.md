- Turn this into a library with one or more CLI commands that can be used for
  creating, querying, & dumping (and updating?) a local version of Gatherer
    - Store card data in actual SQL databases rather than flat JSON files
    - Stop storing printings inside Card objects; instead make them available
      to the user via a `db.get_printings(card, set)` method
    - There should still be methods for converting the database to (and from?)
      JSON.
        - In addition to `"date"` and `"cards"`, the JSON database should have
          a `"sets"` field containing the contents of `sets.json`.  Rather than
          each JSONified `Printing` object storing a copy of its `CardSet`,
          each `Printing` should instead store the set's long name (or some
          other identifying string).
    - Add an `EnVec` class that handles interactions with the database

- It appears that flavor text of double-faced cards and BFM is rendered in
  details pages inside `<div class="cardtextbox"><i> ... </i></div>` tags
  instead of just a `<div class="flavortextbox"> ... </div>` tag as is done for
  other cards.  Deal with this.

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
- Card.showField1 should treat a negative width as disabling line-wrapping
- Add functions/methods for splitting up a block of rules text into lines
  and/or levels
- Give `fetch.sh` IDfile-handling functionality again?

# Coding

- Eliminate Card.newCard?
- Should "oversized" or "nontraditional" be a card class?
- Move the code for fetching & merging together all of a card's printings from
  tutor.py to `Tutor`
- Convert `tutor.py` into a `main` function for `envec.tutor`?
- Add a JSONDecoder subclass?
- Add a class for rulings
- Store & access files in `data/` as `package_data`
- Make `text` and `baseText` (and `cost`?) equal `''` rather than `None` when
  empty/absent?
- Change all tuple attributes to lists?
- Rethink the necessity of `for_json(*, trim=True)`
- Should the checklist parsing functions perform any massaging or typecasting
  of the data or make any guarantees about what the data will contain at all?
- Add function annotations?
- Convert ruling dates into `datetime.date` objects
- Define rarities via a data/ file?
- Define a custom class for warnings
- Instead of a list of dicts, make `Tutor.parse_details` return a `Details`
  object (containing a list of dicts) with a `to_card` method
- Actually _use_ the `BFM` CardClass
- Use `.format` instead of `%`
- `tutor.py`: Log _all_ exceptions that propagate to the top by wrapping almost
  everything in `try: ... except Exception: logging.exception( ... ); raise`

## Redo Handling of Multipart Cards and Their Printing Fields

Merge `Card` and `Content` into a single type that stores all of the content
information for a single card component plus a `secondary` (or `alternate`?)
field containing a reference to the card's other component, if any.

- Lists of cards will be of primary components with populated `secondary`
  fields.
- A `Card`'s various attributes will only return data for that component
  (except colorID, which must take both components into account), with variant
  attributes that return a tuple of values for all components.
- also add attributes/methods for querying split cards while respecting their
  dual nature?
- Support Who/What/When/Where/Why by using the `secondary` field as a reference
  to the next component in the card, thereby constructing a linked list?
- Each Card object stores the rulings for that component; rulings are not
  merged.
- The primary component of each card will have the combined card's card class,
  while the secondary component will have a special "secondary"/"alternative"
  card class.
- A single `Printing` object should only store information for a single
  component and should, like `Card` objects, contain a reference to the
  corresponding `Printing` for the other half of the card, if any
    - Give `Printing` a method for getting a `Printing` object containing only
      the values that are shared between components (including `effectiveNum`)
    - For the few cards with more than one multiverseid per component printing,
      just store multiple nearly-identical `Printing` objects.  This eliminates
      the need for `Multival`.


Yet another idea: Each card class is represented by a different subclass of the
`Card` ABC, with instances of the multipart classes (subclassing
`MultipartCard`) each containing two "normal card" (`SimpleCard`?) objects.

- Even if this idea isn't used, `CardClass` should still be replaced by a class
  hierarchy (with the `"cardClass"` field in JSON output renamed to
  `"__class__"`).

# Data & Documentation

- Add documentation
- Update & reformat/rewrite the pages on the wiki
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
- Make the scraping code able to handle sets in Gatherer that aren't listed in
  sets.json
- Make `parse_details` automatically determine whether a multipart card is
  split, flip, or double-faced (by looking at the rulings?)
