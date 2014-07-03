This monstrosity is an attempt to create a Perl program that scrapes the
_Magic: The Gathering_® [Oracle™ card database](http://gatherer.wizards.com)
for all of the Oracle text, rulings, flavor text, set data, etc. for each &
every Magic card and stores it all in JSON & XML files for offline viewing &
querying, together with a set of Perl modules for enabling this scraping and
offline querying.  It technically works.

This code depends on [XML-DOM-Lite][1], which [needs to be patched to fix a
memory leak][2]; cf. [my fork](https://github.com/jwodder/XML-DOM-Lite).

There is also a `python` branch in which all of the code is slowly being
translated to Python.  It should hopefully eventually supplant the Perl
version.

Also, for those who still don't get the reference: [Oracle _en_-Vec][3].

# Manifest

- `EnVec.pm` — a single module that re-exports most of `EnVec/`

- `EnVec/` — the Perl modules:
    - `Card.pm` — `Card` class
    - `Card/Content.pm` — `Card::Content` class for representing individual
      components of multipart cards and the analogous collections of fields for
      single-part cards
    - `Card/Multival.pm` — `Card::Multival` class for representing
      printing-specific values that can vary between components of multipart
      cards
    - `Card/Printing.pm` — `Card::Printing` class
    - `Card/Util.pm` — `Card`-specific internal utility functions
    - `Checklist.pm` — functions for parsing Gatherer checklists
    - `Colors.pm` — functions for working with sets of M:TG colors
    - `Details.pm` — functions for parsing Gatherer's individual card details
      pages
    - `JSON.pm` — functions for converting arrays & hashes of `Card` objects to
      & from JSON
    - `Multipart.pm` — functions for reading the contents of
      `data/multipart.tsv`
    - `Sets.pm` — functions for reading the contents of `data/sets.tsv`
    - `Util.pm` — internal utility functions

- `README.md` — this file

- `TODO.txt` — an overly large file

- `data/` — data files used by the library, `tutor.pl`, and/or nothing
    - `abbrevs.tsv` — table of various systems of M:TG set abbreviations
    - `badflip.txt` — formerly contained missing text that Gatherer omitted
      from certain flip cards; currently not needed
    - `multipart.tsv` — a table of all multipart cards (split, flip, &
      double-faced), listing for each multipart card the names of its
      components and what kind of multipart card it is
    - `rarities.tsv` — listing of old-style card rarities (e.g., U3 and C2
      rather than C/U/R/M)
    - `reserved.txt` — the reserved list
    - `sets.tsv` — a table of M:TG sets with their short & long Gatherer names,
      release dates, and flags for controlling whether `tutor.pl` should fetch
      their checklists
    - `shifted-fut.txt` — list of "Timeshifted"/"future-shifted" cards from
      Future Sight
    - `shifted-pc.tsv` — table of "Timeshifted" cards from Planar Chaos and
      their original counterparts
    - `tokens.txt` — names of known creature tokens that have ended up in
      Gatherer for some reason

- `fetch.sh` — a wrapper around `tutor.pl`, `toText1.pl`, and `listify.pl` for
  performing them all together nicely

- `listify.pl` — a Perl script for converting a JSON card database into plain
  text, LaTeX, and PostScript card checklists

- `mtgcard.dtd` — the DTD for `tutor.pl`'s XML output format

- `spoilers/` — crude descriptions of how card data is represented on Gatherer
    - `check.txt` — Gatherer's checklist output format
    - `details.txt` — Gatherer's individual card details pages
    - `problems.txt` — a list of known problems with the information on
      Gatherer that Wizards can't be bothered to fix

- `toText1.pl` — a Perl script for converting a JSON card database into a
  nice-looking text spoiler file

- `tutor.pl` — a Perl script that scrapes Gatherer and creates JSON and XML
  databases of all of the cards

[1]: http://search.cpan.org/~rhundt/XML-DOM-Lite-0.15/
[2]: https://rt.cpan.org/Public/Bug/Display.html?id=73337
[3]: http://gatherer.wizards.com/Pages/Card/Details.aspx?multiverseid=4889
