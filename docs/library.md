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
- The shelf is stored as its raw name in `shelfName`, so queries can filter on
  it. Read `shelf`.

Sync has only been seen to start: the simulator, with no iCloud account,
reports `CKAccountStatusNoAccount` and keeps working locally. A device build
needs the container and push notifications registered for the team, which
Xcode does on the first signed build with automatic signing.

## Covers

A cover is the reader's own photo, taken or chosen from the book's page once
the book is on a shelf. `CoverPhoto` shrinks it to at most 900 pixels tall as a
JPEG (tens of kilobytes) so it syncs quickly, and reads its colour once, which
`ShelvedBook` keeps beside it. The book's page and the card for the book being
read take a wash of that colour, and Sinu toon will read the same values.
Books without a photo get the plain card with their title.

Online covers are left out on purpose. In November 2026, Open Library had a
cover for 2 of 80 ISBNs sampled from the catalogue, and Google Books refuses
lookups without an API key. A source worth adding would need a better showing
than that, and would send which books the reader looks at to someone else.

## Rules

- A book is on one shelf at a time, found by its work key
  (`CatalogueWork.id`). Shelving it again from any edition moves it.
- A shelved book keeps its own title, authors, ESTER number and page count, so
  the shelves read the same without the catalogue and through catalogue
  updates. Its page opens from that and fills in the rest from the catalogue.
- Moving to Reading records when it started, once. Moving to Read records when
  it finished and turns to the last page.
- Ratings are one to five stars, or none. The page stays between zero and the
  page count.

Two devices that shelve the same book while offline can each make a record for
it. Nothing merges those yet.

## Testing

`ShelvedBookTests` covers the rules on an in-memory store. In debug builds the
`-inMemoryLibrary YES` launch argument opens an empty in-memory library, which
`ShelvesJourneyTests` uses so it starts from empty shelves and leaves nothing
behind. Its cover journey picks the newest photo in the simulator's
Photos, so add a cover image first with `xcrun simctl addmedia <udid> cover.jpg`.
