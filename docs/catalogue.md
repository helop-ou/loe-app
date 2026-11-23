# Catalogue

Loe searches an offline copy of the Estonian National Bibliography (ERB): every
book published in Estonia, in Estonian and in other languages. It is one SQLite
file, built by [`tools/catalogue/build.py`](../tools/catalogue/build.py) from
the National Library's open data, with the schema in
[`tools/catalogue/schema.sql`](../tools/catalogue/schema.sql).

## Source

| Set | Export | Records (November 2026) |
| --- | --- | --- |
| Books in Estonian (`raamat`) | `https://data.digar.ee/erb/ERB_eestikeelne_raamat.zip` | 232,181 |
| Books in other languages (`muukeelne`) | `https://data.digar.ee/erb/ERB_muukeelne_raamat.zip` | 92,205 |

The same records are served over OAI-PMH at
`https://data.digar.ee/repox/OAIHandler` (sets `raamat` and `muukeelne`,
`metadataPrefix=marc21xml`). Its datestamps are bulk reload dates, not edit
dates, it publishes no deletions, and the weekly change feed on data.digar.ee
has been empty since 2023. So every build starts from the full exports and
replaces the whole file. There is no incremental update.

**Licence.** Zenodo, the RaRa Digilab and andmed.eesti.ee publish the
bibliography as CC0 1.0. One page on data.digar.ee says CC BY-SA 3.0 EE
instead. Until the National Library says which applies, Loe's credit meets
both: the About page names the National Library and the bibliography, says
what Loe changed (the fields it keeps, editions grouped into works), and links
CC BY-SA 3.0 EE beside CC0 1.0's text.

The bibliography holds books published in Estonia, and some published elsewhere
by Estonian authors or about Estonia, such as Jaan Kross in English from London
and New York. Other books published abroad are not in it.

## Rebuilding

```sh
mkdir -p /tmp/erb && cd /tmp/erb
curl -O https://data.digar.ee/erb/ERB_eestikeelne_raamat.zip
curl -O https://data.digar.ee/erb/ERB_muukeelne_raamat.zip
cd -
python3 -I tools/catalogue/build.py /tmp/erb/catalogue.sqlite /tmp/erb/ERB_*.zip
xz -9 -k /tmp/erb/catalogue.sqlite
```

A build takes about a minute. It prints how many records it kept, why it
skipped the rest and how many ISBN values it dropped as invalid. Run the tests
with `python3 -I -m unittest discover -s tools/catalogue`.

The build fails, with a message on stderr, a non-zero exit status and no output
file, when it kept nothing or fewer than 90% of the `editions` in
`manifest.json`, the last published count. It also fails when SQLite's
integrity check does not pass, and it records the name and SHA-256 of each
source file in `meta`. To try the tool on a sample, add `--allow-small`, which
turns the 90% check off. Set `SOURCE_DATE_EPOCH` to make a build repeatable:
it replaces the build time in `meta`, and two builds of the same files with the
same value are byte-identical.

The November 2026 build kept 312,349 editions. It is 123 MB, or 31 MB as xz,
which the app can unpack with Apple's Compression framework.

## In the app

The app opens the file read-only from
`Application Support/Catalogue/catalogue.sqlite`. `CatalogueStore` says whether it
is there, and `Catalogue`, an actor, runs every query off the main thread. A
file whose `schema_version` differs from `Catalogue.schemaVersion` is refused,
so bump both together. `CatalogueTests` builds its fixture from
`schema.sql` itself, so a schema change the app does not follow fails the unit
suite.

Search matches every word the reader typed, the last one as a prefix while
it is being typed. A string that reads as a valid ISBN is looked up by number
instead. On a phone, Search can also scan the barcode on a book's back cover
with VisionKit. Only an EAN-13 that starts 978 or 979 and passes its check digit
counts as an ISBN, and an ISBN in view wins over any other barcode. The scanner
also reads the barcode types library stickers use (Code 128, Code 39, Codabar
and interleaved 2 of 5) and other shop codes, only to tell the reader that is
not the one, and keeps scanning. A 978 or 979 code that fails its check digit
is a misread, so it is read again rather than called the wrong barcode. The simulator
has no camera, so the scan button is not shown there. Hits are grouped into works (the same title by the same authors), a
title typed exactly comes first, and among the rest a book published in many
editions ranks a little higher.

A book's page asks `Catalogue.details(for:)` for the rest of what it shows:

- **Editions**: every edition with the work's title and lead author. A book
  opened from a shelf may carry a title or authors the catalogue has since
  corrected. When nothing matches them, the work is found by its record number
  and its page shows what the catalogue says now.
- **The original**, for a translation: the work whose title is the edition's
  original title, by the same lead author.
- **Translations**, for an original: the works whose original title is this
  title, by the same lead author. This is how „Keisri hull“ finds *The czar's
  madman*, and the reverse. A book from abroad finds its translation the same
  way: *Project Hail Mary* from Open Library lists „Ave Maria“.
  [`SameBook`](../Loe/Shared/Catalogue/SameBook.swift) compares the two, so a
  leading article or a middle initial doesn't hide one. The bibliography
  writes an original title with or without its subtitle, and Open Library puts
  the subtitle in the title, so either side may drop what follows its colon.
  Never both, because the books of a series share what comes before it.
- **By the same author**: other works by the lead author in the same language,
  so an Estonian page lists Estonian books and a translation lists others in
  its language.
- **Similar books**: books by other authors that share what the bibliography
  says about this one. A subject heading or genre counts only when more than
  half of the work's editions carry it, so one oddly catalogued edition cannot
  steer it. Headings on more than 4,000 editions ("romaanid") and format or
  nationality headings ("e-raamatud", "eesti") say too little and are left
  out. A narrow publisher series (3 to 400 editions) counts at half weight.
  Rarer shared headings count for more, a book published often ranks a little
  higher, and only the same language and the same side of fiction are
  suggested. Fewer than three good matches and the section is not shown, so
  a book with no genre more specific than "romaanid" or "ilukirjandus" gets
  none rather than a guess. Each suggestion shows the heading or series it
  shares.

Read next also asks `Catalogue.nextInSeries(after:)` for the book that
follows one the reader is reading or has read, in its language:

- **A numbered series of the author's own.** The bibliography's series field
  holds both narrative series („Näljamängud“, 2. raamat) and publisher series
  („Eesti lugu“, 49). A series counts when at least 70% of its editions share
  the book's lead author, which lets a companion book by others in. The next
  book is the lowest number above this one.
- **A book published in parts**, numbered in its title after the first full
  stop: „Tõde ja õigus. II jagu“, „Sõrmuste Isand. 2. osa. Kaks kantsi“,
  „Sõrmuste Isand. Teine osa“. Arabic and Roman numbers and Estonian ordinals
  up to kümnes are read. The next part is by the same lead author.

Where several works fit, the most often published is chosen. A sequel the
bibliography does not number, such as „Suvi“ after „Kevade“, is not found.

### Genres

The quiz's genres find books through the bibliography's genre headings (655),
which carry nearly all the signal on fiction. Subject headings (650) on fiction
are mostly nationalities. Each `Genre` lists the heading names it takes, as the
bibliography spells them, and `Catalogue.works(withHeadings:language:limit:)`
finds fiction in one language under any of them, the most often published
first.

| Genre | Headings |
| --- | --- |
| Crime and mystery | kriminaalromaanid, kriminaaljutud |
| Thrillers | põnevusromaanid, spiooniromaanid |
| Psychological | psühholoogilised romaanid |
| Romance | armastusromaanid, haiglaromaanid |
| Family and drama | perekonnaromaanid, päevikromaanid, arenguromaanid, külaromaanid |
| Historical | ajaloolised romaanid, biograafilised romaanid, sõjaromaanid, ajaloolised näidendid |
| Fantasy | fantaasiaromaanid, fantaasiakirjandus |
| Science fiction | ulmeromaanid, ulmejutud, ulmekirjandus, düstoopiad |
| Horror | õudusromaanid, õudusjutud |
| Humour | huumor, humoreskid (kirjandus), satiirilised romaanid, satiir |
| Poetry | luuletused, poeemid, haikud, proosaluuletused, sonetid, armastusluule, värssromaanid |
| Young adult | noorsookirjandus, koolijutud |

- The bibliography catalogues mysteries as crime, so they come under Crime and
  mystery. „Müsteeriumid“ are medieval mystery plays, and plays are not
  offered.
- Genre headings arrived around 1990 and are rare outside Estonian, so a genre
  finds mostly Estonian fiction from the last thirty years. A novel with no
  genre beyond „romaanid“ or „ilukirjandus“ is not found by any.

`GenreTests` checks every heading against the catalogue installed on the
simulator, where there is one, so a misspelt name fails instead of finding
nothing.

The page links each edition's ESTER record (the 001 number without its final
check digit, so `b10500820` is `record=b1050082`) and searches Rahva Raamat and
Apollo for the title and author.

### Download and updates

The app finds the current catalogue through
[`tools/catalogue/manifest.json`](../tools/catalogue/manifest.json), read from
this repository's `main` branch on GitHub. Shipped apps read that exact path,
so never move or rename it. The manifest names a GitHub release asset, its
SHA-256, its size and its schema version.

- The first download is the reader's choice, from Search, and may use mobile
  data. `CatalogueDownloader` checks the SHA-256, unpacks the xz file, opens
  the result, and only then puts it in place, so a failed download never costs
  the reader the catalogue they had. The file is excluded from iCloud backup,
  since it can be downloaded again.
- Updates are checked at launch, at most once a week, and download only over
  Wi-Fi, without asking. The catalogue in use stays until the new one is in
  place. A check that can't reach the manifest doesn't count, so the next
  launch asks again.
- Settings shows the edition (its version, `2026-11`, as a month), its size
  on the phone, the number of editions and when Loe last heard which edition
  is the newest. "Check for a new edition" asks straight away, may use mobile
  data, since the reader asked, and says what came of it. Removing the
  catalogue deletes the file and forgets its version, and Search offers the
  download again. Neither runs while a download or update is replacing the
  file.
- A manifest whose `schema_version` the app does not know is ignored, and
  nothing is downloaded. Apps that old keep their catalogue until they update.

### Publishing a new catalogue

1. Rebuild it as above, then `xz -9 -k` it.
2. Create a release for it and never change it afterwards. Replacing an asset
   in place can leave a release broken. Its notes name the source files and
   the SHA-256 of each, which the build recorded in `meta` (`source_1`,
   `source_1_sha256` and so on):

   ```sh
   gh release create catalogue-2026-12 /tmp/erb/catalogue.sqlite.xz --latest=false \
     --title "Catalogue 2026-12" --notes "…"
   ```

3. Update `manifest.json` with the new `version`, `url`, `sha256`
   (`shasum -a 256`), `size` and `editions`, in a pull request. Apps pick it up
   within a week of it reaching `main`. `CatalogueDownloadTests` checks that the
   manifest is one this app can read.

### Trying it in the simulator

The journeys search a small catalogue of their own, so they find the same
books on every simulator and on CI.
[`JourneyCatalogue`](../LoeUITests/JourneyCatalogue.swift) builds it for each
run from `schema.sql` and the records in `LoeUITests/Fixtures/catalogue.sql`:
real ones from the bibliography, for the books the journeys look for and a
few around each. A debug build launched with `-catalogueFile <path>` opens
that file in place of its own. `JourneyCatalogueTests` names what each journey
needs from it, so a change to the records, the schema or the matching fails
there first. Run the journeys and look at their screenshots with:

```sh
xcodebuild test -scheme Loe -destination 'platform=iOS Simulator,id=<udid>' \
  -only-testing:LoeUITests -collect-test-diagnostics never \
  -resultBundlePath /tmp/journey.xcresult
xcrun xcresulttool export attachments --path /tmp/journey.xcresult --output-path /tmp/journey
```

To see the whole catalogue in the app, as the README screens need it, copy a
built one into the installed app's container:

```sh
container="$(xcrun simctl get_app_container <udid> ee.helop.loe data)"
mkdir -p "$container/Library/Application Support/Catalogue"
cp /tmp/erb/catalogue.sqlite "$container/Library/Application Support/Catalogue/"
```

To try the download, serve the xz file and a manifest naming it from the Mac,
remove the catalogue from the container, and pass the manifest to the
download journey. Debug builds read a `-catalogueManifestURL` launch argument
instead of the GitHub address, and plain HTTP to `127.0.0.1` works:

```sh
mkdir -p /tmp/serve && cp /tmp/erb/catalogue.sqlite.xz /tmp/serve/
# write /tmp/serve/manifest.json with "url": "http://127.0.0.1:8765/catalogue.sqlite.xz"
python3 -I -m http.server 8765 --bind 127.0.0.1 --directory /tmp/serve &
rm "$container/Library/Application Support/Catalogue/catalogue.sqlite"
TEST_RUNNER_LOE_CATALOGUE_MANIFEST=http://127.0.0.1:8765/manifest.json xcodebuild test \
  -scheme Loe -destination 'platform=iOS Simulator,id=<udid>' \
  -only-testing:LoeUITests/SearchJourneyTests/testDownloadsTheCatalogue -collect-test-diagnostics never
```

## Books from abroad

Books the bibliography doesn't have, such as English books published abroad,
are found on [Open Library](https://openlibrary.org), whose catalogue data is
CC0. [`OpenLibrary`](../Loe/Shared/OpenLibrary/OpenLibrary.swift) asks its
search from the phone, and Search shows what it finds under the catalogue's
results as "From Open Library".

- **When it asks.** Only once typing pauses (`OpenLibrary.pause`, 600 ms after
  the catalogue's own 150 ms), never on each keystroke, and only for three or
  more characters. A new keystroke cancels the wait before anything is sent.
  Answers are kept in memory for the session, and a search already answered
  shows at once, as when coming back from a book's page.
- **An ISBN.** The catalogue answers an ISBN first, whether it was typed or
  scanned. Open Library is asked only when the catalogue has no edition with
  it, in the same search as `isbn:` and the thirteen digits, so the answer is
  read like any other. When neither has it, Search says so and offers adding
  the book by hand. `OpenLibrary.question(for:catalogueFound:)` has the rule.
- **What it sends.** `https://openlibrary.org/search.json` with the search
  text or the ISBN, `lang=en`, a limit of 20 and the fields Loe reads, over a
  session with no cookies, cache or credentials. The `User-Agent` names the app, the
  repository and `kontakt@helop.ee`: Open Library asks apps to identify
  themselves, and allows three requests a second for those that do.
  `Accept-Language` is set to `en`, so the reader's own languages are not sent.
- **Translations.** Open Library files a translated book under its original
  work, so *The Last Wish* is „Ostatnie życzenie“. `lang=en` with the
  `editions` field returns the English edition inside it.
- **Titles.** The work's title is shown, with its English edition's subtitle
  when the work has none and the subtitle is seven words or fewer ("Halo" and
  "The Fall of Reach", but not a publisher's blurb). An edition whose short
  subtitle differs from its work's is another book filed under that work, and
  it shows under its own subtitle: Open Library keeps an edition of "Halo: The
  Fall of Reach" under "Halo: First Strike". When the two
  titles share nothing, the book is a translation and the edition's title is
  shown. `OpenLibraryBook.displayTitle` has the rule.
- **Each book once.** Open Library often has one book as several works. A
  book already in the answer, or among the catalogue's results, is left out.
  When one of those works is another book's, as above, the book's own work is
  the one kept.
  [`SameBook`](../Loe/Shared/Catalogue/SameBook.swift) decides: the title
  with or without the catalogue's subtitle, folded and without a leading
  article, and the lead author's surname. The shelves use the same rule.
- **Reading it.** The search schema "is not guaranteed to be stable", so every
  field is optional and a malformed result is skipped, not the whole answer.

A book from Open Library opens as a work with one edition and no catalogue
record: an empty `erbID` and an `OpenLibraryRecord` with its work key, ISBN and
cover id. Its page shows no editions, ESTER link or library availability,
searches the bookshops by title and author, and links back to Open Library.
It lists the catalogue's translations of the book, so an English book leads
to its Estonian edition and the libraries that hold it.
How it is kept on a shelf is in [Library](library.md#books-from-open-library).

With no network, or when Open Library fails, the catalogue's results show as
they are and the section says it can't be reached. Debug builds launched with
`-networkStub YES` answer "halo", or the ISBN 9780345451323, with a fixed
Halo book, and "hail mary" with *Project Hail Mary*, which the catalogue has in
Estonian. They fail any search with "offline" in it and find nothing for
anything else, so the journeys never touch the network.

## What is kept

Skipped: records that are not text (maps, music), doctoral theses (a 502
note), the digital copies the library now creates automatically beside a
print record (a 588 note starting "Digikoopia"), and records with no title
proper (a 245 with no `$a`, which would otherwise start with a part number).

Each remaining record is one row in `edition`, read like this:

| Column | MARC | Notes |
| --- | --- | --- |
| `erb_id` | 001 | The ESTER record number, such as `b10500820` |
| `title` | 245 `$a`, `$n`, `$p` | ISBD punctuation and cataloguer brackets removed, part numbers joined with ". " |
| `subtitle` | 245 `$b` | |
| `authors` | 100, and 700 with the role autor or kaasautor | Given name first. Falls back to koostaja (compiler) for anthologies. The role is only ever an Estonian word in `$e`, never a `$4` code |
| `translators` | 700 with the role tõlkija | |
| `year` | 008/07-10, else 264 or 260 `$c` | Years after next year are dropped as errors |
| `publisher`, `place` | 264 (second indicator 1), else 260 | "s.n." and "S.l." become empty |
| `language` | 008/35-37 | |
| `original_title` | 240, else 246 with second indicator 9, else a "Tõlgitud …:" note | 246 with indicator 9 is ERB's own convention and its main source |
| `original_language` | 041 `$h` | `und` and `mul` become empty |
| `series`, `series_number` | 490, else 830 or 800 | Numbers stay text: "2. kd." |
| `pages` | 300 `$a` | Numbered pages before bracketed ones. Offprint ranges give none |
| `fiction` | 008/33 | Novels, drama, humour, short stories, poetry or unspecified fiction |
| `electronic` | 007, 300 | Born digital, not a print book with a scanned copy |

`isbn` holds every valid ISBN as 13 digits with its qualifier (`pdf`,
`köites`, `vale` for a wrong ISBN printed on the book). Keep `vale`: it is
what a barcode scan of that book returns. Volumes of a set can share one ISBN.
An ISBN written with spaces, such as `978 9949 633 28 9`, is read, and text
after it is never joined into the number.

`heading` holds subject headings (650, from the Estonian Subject Thesaurus,
with its EMS id) and genres (655), and `edition_heading` links them.

`edition_search` is an FTS5 index over title, authors, series and original
title that ignores diacritics: "tode" finds „Tõde“. It does not forgive typos.
