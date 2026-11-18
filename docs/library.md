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
behind.
