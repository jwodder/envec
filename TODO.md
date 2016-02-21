- Properly handle JSONification and un-JSONification of CardSets in Printings
    - Go back to serializing just the set names?
        - Also serialize a top-level dict of all the CardSets?
    - Update cards.json to allow sets to be set objects as from
      sets-schema.json?
- Turn this into a library with one or more CLI commands that can be used for
  querying, updating, & dumping a local version of Gatherer
    - Store card data in actual SQL databases rather than flat JSON files
    - This would mean that I could stop storing printing & ruling information
      in Card objects and could instead store it separately.
    - There should still be methods for converting the database to (and from?)
      JSON.

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
- Card.showField1 should treat a negative width as disabling line-wrapping

# Coding

- Give all classes "copy constructors"?
- Eliminate Card.newCard?
- Should "oversized" or "nontraditional" be a card class?
- Make the bulk of tutor.py into a library function?
    - Move the code for fetching & merging together all of a card's printings
      from tutor.py into the library proper
    - Add a wrapper around `parse_details` that downloads and parses a given
      multiverseid
    - Add a class ("Gathererer"? "Gatherest"? "Tutor"?) containing a `Session`
      object with methods for fetching & parsing checklists & details pages
- Add a JSONDecoder subclass?
- Add a class for rulings
- Store & access files in `data/` as `package_data`
- Look for a better/more standard name for `jsonable`
- Make `text` and `baseText` (and `cost`?) equal `''` rather than `None` when
  empty/absent?
- Change all tuple attributes to lists?
- Rethink the necessity of `cleanDict`
- Make `parse_details` return a list of `(Card, [OtherSet])` pairs, one for
  each section/component on the page, rather than joining everything together
  into one card
- Should the checklist parsing functions perform any massaging or typecasting
  of the data or make any guarantees about what the data will contain at all?
- Give `Color` objects an attribute for their nicknames (guild, shard, etc.) ?
    - also (for single & dual colors) an attribute for land type?
- The library functions that use `logging` should register a `NullHandler`
  first; see <https://docs.python.org/3/howto/logging.html#configuring-logging-for-a-library>.
- Add function annotations?

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
- Make the scraping code able to handle sets in Gatherer that aren't listed in
  sets.json
- Make `parse_details` automatically determine whether a multipart card is
  split, flip, or double-faced (by looking at the rulings?)
