# Library

The reader's shelves: which books are on which shelf, ratings, and how far
through a book they are. It is the only data Loe makes, and it never leaves the
reader's phone and their own iCloud.

## Storage and sync

`ShelvedBook` is a SwiftData model in
[`Loe/Shared/Library`](../Loe/Shared/Library). `LibraryStore` opens it with
CloudKit's automatic configuration, which syncs it through the private
database of the iCloud container `iCloud.ee.helop.loe` named in
`Loe.entitlements`. There is no server and no account of Loe's own.

CloudKit sets the rules for the model:

- Every property is optional or has a default. No `@Attribute(.unique)`, and
  relationships are optional.
- Never rename or remove a property. Synced records outlive app versions, so
  add new properties instead.
- Every synced field is listed in `scripts/synced-models.txt`. Add a new one
  there in the same pull request, and never rename or remove a line.
- The shelf is stored as its raw name in `shelfName`, so queries can filter on
  it. Read `shelf`.

When the store can't be opened, Loe shows
[a screen saying so](../Loe/App/LibraryUnavailableView.swift) instead of
crashing on every launch. It offers trying again and writing to the developer.
Nothing is ever deleted or replaced to get past the failure.

The simulator, with no iCloud account, reports `CKAccountStatusNoAccount` and
keeps working locally. A device build
needs the container and push notifications registered for the team, which
Xcode does on the first signed build with automatic signing.

### What Settings says about iCloud

[`CloudSync`](../Loe/Shared/Library/CloudSync.swift) tells the reader whether
their shelves reach iCloud. It starts with the app and works from two things:

- **The account**, from `CKContainer.accountStatus()`, asked at launch, when
  Settings opens and on `CKAccountChanged`. No account, a restricted one or one
  that can't be reached comes first, whatever the last sync did. iCloud can
  leave the question unanswered, as it does on CI's simulator, so after five
  seconds the account counts as unreachable rather than still being checked.
- **The last sync**, from `NSPersistentCloudKitContainer.eventChangedNotification`,
  which SwiftData posts for every setup, import and export. A sync that worked
  says when. A failed one is read for its CloudKit reason, which Core Data
  wraps and a batch reports per record: a full iCloud wins over other reasons,
  because the reader can do something about it. A network error says it is
  waiting, and anything else says Loe tries again.

Loe can't open iCloud's own settings, so each status says where to look in the
Settings app instead. There is nothing to sign in to in Loe.

## Covers

A cover is the reader's own photo, taken or chosen from the book's page once
the book is on a shelf. `CoverPhoto` shrinks it to at most 900 pixels tall as a
JPEG (tens of kilobytes) so it syncs quickly, and reads its colour once, which
`ShelvedBook` keeps beside it. The book's page and the card for the book being
read take a wash of that colour, and Sinu toon will read the same values.

Without a photo, a book shows the cover found for it, and the plain card with
its title when there is none. A book found on Open Library shows Open
Library's cover. A catalogue book shows ESTER's: Open Library has next to no
covers for books published in Estonia, so it is not asked about them. A book
entered by hand always shows the card. The reader's photo always wins, and
removing it brings the found cover back. The cover is credited under it on the
book's page, to Open Library or to ESTER, and its colour gives the wash until
there is a photo. [`Covers`](../Loe/Shared/Covers/Covers.swift) loads them:

- **Which cover, from Open Library.** A book from Open Library by its cover
  id, which every search answer carries and which Open Library does not rate
  limit, else its ISBN. The id is the cover of the English edition Loe shows,
  else the work's: a work can wear another book's cover, as *Halo: First
  Strike* wears *The Fall of Reach*'s.
- **Which cover, from ESTER.** A catalogue book by the ESTER records of its
  editions: a book's page asks about up to twelve, newest first, and takes the
  first that has a cover, and a shelf asks about the edition that was shelved.
  The cover a page found is kept for each of its editions too, so the shelf
  shows it even when the shelved edition, often an e-book's record, has none
  of its own. [`EPIK`](../Loe/Shared/Covers/EPIK.swift) is ESTER's cover
  service, asked as ESTER's own pages ask it: which of some records have a
  cover, then the details of the one that does. EPIK files some records under
  another book and gives that book's cover, so a cover is taken only when the
  title EPIK has the record under is the book's, with or without its
  subtitle, and up to three of a book's records are tried. Its covers are 240
  pixels tall, soft on a book's page and fine on a shelf. Some are the whole
  jacket, wider than tall, and Loe keeps the right half, which is the front.
- **A summary with it.** The details also carry the record's own summary when
  it has one, which a book's page shows as its description, credited to ESTER
  (see [Catalogue](catalogue.md#books-from-abroad)), under the same rule for
  the title. EPIK also holds text it took from elsewhere, which can be another
  book's, and that is left out.
- **Where.** A book's own page and the shelves ask for its cover. Where books
  are listed, in search results, the rows of covers on a page and Read next,
  [`ListedCover`](../Loe/Shared/UI/ListedCover.swift) shows the cover the
  phone already has and asks only by Open Library's cover id. Lookups by
  ISBN, for a book from Open Library with no cover id, wait for the page and
  the shelves: Open Library allows 100 every five minutes from one address,
  so lists would spend that, and tell it about every book scrolled past.
  ESTER is asked only from a catalogue book's own page and the shelves, never
  from a list.
- **What a list has.** The reader's own photo, for a book that is on a shelf.
  Otherwise the cover the book's page or a shelf found, read from memory or
  the caches folder with nobody asked. A page keeps a cover under its
  editions together and under each alone, and a shelf under the edition it
  holds, so a list looks under every edition of the book it shows, however
  many its page asked about. A book whose page was never opened shows its
  card until it is.
- **How often.** Only covers on screen are asked for (the shelf rails are
  lazy), four at a time, and one scrolled past while it waited is dropped
  before it is sent. Lookups by ISBN are counted as they are sent and stop
  short of 90 every five minutes, skipped rather than blocked. A cover is kept
  in the caches folder, and the 200 most recent in memory. A book with none
  (404 from Open Library, or no record with a cover on ESTER) is not asked
  about again for 30 days. A failure, a rate limit or an answer that is not
  what was asked for is not remembered past the session. ESTER's covers
  wanted at the same moment, a shelf's worth, are asked about in one request.
- **How it shows.** A book shows its card until its cover is ready, and the
  cover then fades in over the card, briefly.
  [`CoverPictures`](../Loe/Shared/UI/CoverPictures.swift) decodes it first,
  off the main thread and no larger than it shows, so a list keeps scrolling
  smoothly while its covers arrive. The decoded picture is kept in memory
  while the phone has room. One that is there shows with a view's first
  frame, with no card and no fade, so a cover seen once does not flicker when
  it scrolls back into view. The wash and the credit a cover brings ease in
  with it. The fade stays when Reduce Motion is on, because it moves nothing.
  The reader's own photo is on the phone already and shows at once.
- **What is sent.** The cover id or ISBN of a book from Open Library, to
  `covers.openlibrary.org`, with the same `User-Agent` as search and no
  cookies. Open Library redirects to the Internet Archive (`archive.org`),
  which serves the image and so sees the same request. For a catalogue book,
  the record numbers of its editions, to `epik.ester.ee`, on the same kind of
  session. Debug builds launched with `-networkStub YES` give every cover id a
  plain green cover and no ISBN one, and give the print edition of „Ave Maria“
  a plain blue cover and a summary from ESTER, all from memory only.
- **Permission.** ESTER's statutes put copying its data under ELNET's
  permission, which has been asked for. Until it is given, ESTER's covers and
  summaries are for internal builds only (see
  [Release](release.md#before-the-app-store)).

## Books entered by hand

When Search finds nothing, or the book the reader wants is not among the
results, they can add it themselves: "Add it yourself" on an empty search, or
"Can't find it?" under the results. The form starts from what they searched
for, unless that was an ISBN, and asks for the title, authors, pages, year and
language. [`EnteredBook`](../Loe/Shared/Library/EnteredBook.swift) tidies what
was typed: spaces are collapsed, authors separated by commas are kept as the
catalogue keeps them, and a page count or year that cannot be right is dropped.

The book goes on Want to read and its page opens. It is a `ShelvedBook` like
any other, with `sourceName` set to `hand` and its year and language kept
beside it, so it can be rated, read, photographed and synced. Its work key is
its own (`hand:` and a UUID), so it never merges with a catalogue book of the
same title, and editing it never changes which book it is.

Its page shows what the reader entered, with Edit to change it. Editions, the
ESTER link and library availability need a catalogue record and are left out,
and the bookshops are searched by title and author. Translations and books by
the same author still come from the catalogue when it has them. Removing the
book from the shelves asks first, then deletes it, so its page closes.

Older versions of Loe read a book entered by hand as a catalogue book with no
record, and show it without the Edit button.

## Books from Open Library

A book found on Open Library (see [Catalogue](catalogue.md#books-from-abroad))
is shelved from its page like any other. Its `ShelvedBook` has `sourceName`
set to `openLibrary`, keeps the Open Library work key, ISBN and cover id
(`openLibraryKey`, `isbn`, `coverID`) with its year and language, and its page
opens from the shelf with its link back to Open Library.

A book both sources have stays one book on the shelves. Its work key is built
the catalogue's way (folded title and authors), and when the two write it
differently, shelving it looks for the other source's copy first and moves
that one instead of adding a second. [`SameBook`](../Loe/Shared/Catalogue/SameBook.swift)
decides, as it does for Search: the title with or without its subtitle (the
catalogue keeps a subtitle apart, Open Library puts it in the title), folded
and without a leading article, and the lead author's surname, so "Eric Nylund"
and "Eric S. Nylund" match. A book shelved from the catalogue keeps its
subtitle for this. Books entered by hand are never matched.

## Read next

The Read next tab suggests books from the reader's own shelves and the
catalogue, worked out on the phone. Nothing is sent anywhere.
[`ReadNext`](../Loe/Features/ReadNext/ReadNext.swift) does the work and
`ReadNextView` shows it.

- **Where it starts.** Favourites are books rated four or five stars, on any
  shelf. A series continues from a book being read or already read, unless
  the reader gave it one or two stars. The eight most recently changed of each
  are used.
- **Next in a series.** The next book after one being read or finished,
  found by `Catalogue.nextInSeries(after:)`. See
  [Catalogue](catalogue.md#in-the-app).
- **More by the author.** For each favourite, three of the lead author's other
  books in the same language, the most often published first, as the book's
  page lists them. Later books of a series the reader is in are left out, and
  so is any part after the first, so nothing skips ahead.
- **Similar books.** For each favourite, the similar books its page shows. A
  book like several favourites names how many and comes first.
- **Tastes.** For each genre the reader likes, four of the most often
  published books under its headings, in the language the reader's favourites
  and series are mostly in, Estonian until there are any. See
  [Catalogue](catalogue.md#genres).
- **Order.** Series first, then books by favourite authors, similar books and
  books for the reader's tastes in turn, at most 24. Each book is suggested
  once, for its first reason.
- **Left out.** Anything on a shelf, from any edition. A title with a part or
  year after its first full stop, „Harry Potter ja saladuste kamber. 2. aasta“,
  is the same book as the title without it, by the same author.

Each suggestion says why, naming the reader's book: „Kevade“ in Estonian marks,
*Truth and justice* in italics for an English one. The first is shown large
with a button that puts it on Want to read. The list is worked out again when a
rating, a shelf or a taste changes, but not when a page is updated or a
suggestion is kept, which only takes it off the list.

With no catalogue the tab says to download it. With no favourites and no
tastes it says to rate a book four or five stars or pick tastes in Settings.
With something to go on and nothing close enough, it says so.

## Tastes

On first launch Loe asks what the reader likes to read: twelve genres to tap,
from [`Genre`](../Loe/Shared/Catalogue/Genre.swift). Done keeps the picks and
Skip keeps nothing. Either way the quiz is not asked again on that phone
(`tasteQuizSeen` in its user defaults), nor on a phone that already has tastes
from iCloud. Settings, from the gear on Shelves, changes them at any time.

Each liked genre is one `Taste` record, synced like the shelves, so two
devices adding the same genre offline cannot clash. `Taste.set` removes a
second record of a genre and keeps genres it does not know, which a newer
version of Loe may have added.

## Where to get it

A book's page lists where to get it: the libraries and bookshops the reader
picked in Settings, in their order, or ESTER, Rahva Raamat and Apollo when
they have picked none. A library row opens the book's ESTER record and a shop
row the shop's search for the title and author.

A book ESTER has no record of, from Open Library or entered by hand, can still
be in a library, but there is nothing to ask about each one. One ESTER row
then stands where the first library would be and opens ESTER's keyword search
for the title and author. Without it, a reader who picked only libraries would
see no "Where to get it" at all. `WhereToGetItTests` pins both cases.

[`Place`](../Loe/Shared/Places/Place.swift) holds every place that can be
picked:

- **Tallinna Raamatukogud**, branch by branch, as the library's locations page
  lists them, with the bus and the three small lending points.
- **Tartu Linnaraamatukogu**: the main library and its four branches.
- **Every other library in ESTER**, one place each, from ELNET's list of
  participating libraries.
- **Rahva Raamat and Apollo.**

Most county and town public libraries are not in ESTER but in URRAM
(lugeja.ee) or Riksweb, so they cannot be picked yet.

Each place says how ESTER names its shelves in a book's holdings, such as
`TlnRK Kännukuke lastekirjandus`. The longest prefix that matches decides the
place, so `Tartu LR Karlova harukogu` is the Karlova branch, while
`Tartu LR lasteosakond` falls to the main library. Availability uses this to
put each copy in its place.

Each pick is one `ChosenPlace` record, synced like the shelves, with a
position for its order. A place's ID is kept in iCloud, so never change one.
Places this version does not know are kept but not shown.

## Availability

When the reader has picked libraries, a book's page asks ESTER which copies
they have as soon as it opens, with no button to tap, and each library's row
says what it found. [`AvailabilityChecker`](../Loe/Shared/Places/AvailabilityChecker.swift)
fetches each edition's holdings page from the web catalogue over HTTPS, at most
four at a time, for the twelve newest editions. Its session keeps no cookies,
cache or credentials, so ESTER learns which records were asked about, that Loe
is asking (the `User-Agent`) and the phone's address, and nothing else.
Answers are reused for ten minutes, in memory only. With no library picked,
nothing is asked. ESTER is named under the list, as its statutes ask of
anything that shows its data.

[`ESTERHoldings`](../Loe/Shared/Places/Availability.swift) reads each row of a
holdings page by the comment that starts each cell (`field 1` is the location,
`field %` the status, `field !` a note) and counts the copy by where it is:

| ESTER says | Counts as |
| --- | --- |
| KOHAL, or "Teavik tagastamisel" (just returned) | On the shelf, or in storage when the location is a `hoidla` that is not an open `avahoidla` |
| TÄHTAEG and a date | On loan until then. Over 60 days past, taken to be lost and left out |
| VARUKOGUS | In storage, can be ordered |
| TEEL | On its way between libraries |
| KOHALKASUTUS, ARHIIVEKSEMPLAR, a note EI LAENUTATA or KOHALKASUTUS, or a reference, reading room, archive or `telli saali` location | Only to read in the library |
| REMONDI AJAKS PAKITUD, ARVE ESITATUD, anything else | Left out |

A library's row then says the first of these that is true: the edition on
screen is on the shelf, another edition is (naming its year), a copy can be
ordered from storage, the first due date to come (or overdue, when every loan
is), on its way, only to read there, or not in this library (Puudub).

Without a network or an answer the row says it could not check, and the link
still opens ESTER. `AvailabilityTests` reads two holdings pages saved in
`LoeTests/Fixtures`. Debug builds launched with `-networkStub YES` ask nobody:
every record has one copy, on the shelf at Kännukuke, so the journey that
picks that library sees it answer.

## Rules

- A book is on one shelf at a time, and shelving it again from any edition
  moves it. [`ShelvedIdentity`](../Loe/Shared/Library/ShelvedIdentity.swift)
  finds the reader's copy, for a book's page, for shelving and for Read next:
  by its record first (the ESTER number of the edition that was shelved, or
  the Open Library work), then by its work key (`CatalogueWork.id`, the folded
  title and authors), then as the other source's copy, by `SameBook`. A book
  entered by hand is only ever found by its own key.
- The work key is never relied on alone, and it is not rewritten. Titles and
  authors get corrected, in the catalogue, in how the catalogue is built and
  on Open Library, and the work key changes with them. The record does not.
- A shelved book keeps its own title, authors, ESTER number and page count, so
  the shelves read the same without the catalogue and through catalogue
  updates. Its page opens from that and fills in the rest from the catalogue,
  which finds the book by its ESTER number when the title or authors it was
  shelved under are no longer the catalogue's.
- Moving to Reading records when it started, once. Moving to Read records when
  it finished and turns to the last page.
- Ratings are one to five stars, or none. The page stays between zero and the
  page count.
- Removing a book asks first when it keeps something of the reader's: a
  rating, a page, a cover photo, when it was read, or a book entered by hand.
  A book that is only on a shelf has nothing to lose, so it is removed at once.

Two devices that shelve the same book while apart each make a record for it,
and CloudKit keeps both.
[`ShelvedBook.mergeDuplicates`](../Loe/Shared/Library/ShelvedBook+Merging.swift)
makes them one when the app opens and after each sync:

- **Which records.** Those that share a catalogue record, an Open Library work
  or a work key. The looser `SameBook` match is for shelving and merges
  nothing, and a book entered by hand is never merged.
- **Which stays.** The one shelved first, with the title and authors it was
  shelved under. Every device orders the records the same way, so two devices
  merging at once delete the same record.
- **What it keeps.** The shelf of the record changed last, the latest rating
  and cover photo, the furthest page with its own page count, the earliest
  start and the latest finish.

A change made to the other record on a device that has not synced yet is lost
when that record is deleted. `ShelvedBookMergingTests` covers these rules, and
`DuplicateBooksJourneyTests` launches with `-duplicateBooks YES`, which puts
two records of one book in an empty in-memory library, to see them open as
one.

## Testing

`ShelvedBookTests`, `ShelvedEnteredBookTests`, `ShelvedOpenLibraryBookTests`
and `TasteTests` cover the rules on an in-memory store, `CloudSyncTests` the
iCloud status, and `AddBookJourneyTests` adds, edits and removes a book by
hand in the app. `StoredNamesTests` pins every stored name and raw value of
the synced models and reads them back from a store on disk, so a rename fails
a test instead of reaching iCloud.

In debug builds the `-inMemoryLibrary YES` launch argument opens an empty
in-memory library, which every journey gets so it starts from empty shelves
and leaves nothing behind. They pass `-tasteQuizSeen YES` so the quiz stays
away, and `TasteQuizJourneyTests` passes `NO` to see it. The
[standards](standards.md#review-and-verification) say how a journey launches.
The cover journey in `ShelvesJourneyTests` picks the newest photo in the
simulator's Photos. A new simulator comes with a few, and
`xcrun simctl addmedia <udid> cover.jpg` adds another.

`LibraryStoreTests` opens a store that can't be opened, and
`LibraryUnavailableJourneyTests` launches with `-libraryCannotOpen YES`, which
makes opening the library fail in a debug build, to see the screen a reader
gets.
