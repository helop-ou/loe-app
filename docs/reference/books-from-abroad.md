# Books from abroad

Loe's catalogue is the Estonian National Bibliography, so most English books
a reader owns cannot be found: *Halo: The Fall of Reach* was the example that
started this. This note compares the online services that could fill the gap,
with coverage measured on a sample of books, what each one's terms allow, and
what a lookup would send. It was written in November 2026, before any of it was
built. The decisions it needs are at the end.

## The short answer

Open Library is the one source that fits. It found all 75 books in the sample,
knew 85% of an independent sample of English ISBNs, has a cover for nearly
every book and a description for most, needs no key, and its catalogue data is
CC0. A phone can ask it directly over HTTPS with no cookies.

Google Books needs an API key, and Google's terms say "Developer credentials may
not be embedded in open source projects". Apple's Search API covers e-books
well but knew few print ISBNs, and its terms allow its content "only to promote
store content". Neither fits an open-source app with no server.

The offline catalogue stays as it is. A filtered copy of Open Library is not
worth its size (see [Offline](#offline)).

## The catalogue already has some

The bibliography covers more than books printed in Estonia. It has 14,315
English editions, and at least 1,500 of them were published abroad, most often
in London, Stockholm, New York, Helsinki and Toronto: Jaan Kross from Harvill
and The New Press, Andrus Kivirähk's *The Man Who Spoke Snakish* from Grove,
and books from Estonian exile presses. These are books by Estonian authors or about Estonia.
Anything else from abroad is missing.

The bibliography does know many of those books by their English title. 30,783
editions record that they were translated from English and carry the original
title, which is how „Keisri hull“ already finds *The Czar's Madman*. 41 of the
75 books in the sample have a translation in the catalogue with the English
title recorded. An English book found online can be linked to
its Estonian translation the same way, by title and lead author.

## The sample

75 English books published outside Estonia, chosen to cover what readers here
own rather than only bestsellers:

| Group | Books | Examples |
| --- | --- | --- |
| Game and film tie-ins | 10 | six *Halo* novels, *Horus Rising*, *Thrawn*, *Mass Effect: Revelation*, *The Last Wish* |
| Recent bestsellers | 21 | *Fourth Wing*, *Project Hail Mary*, *Intermezzo*, *James*, *Orbital*, *Sea of Tranquility* |
| Non-fiction | 6 | *Atomic Habits*, *Sapiens*, *Educated*, *Braiding Sweetgrass* |
| Fantasy and science fiction | 19 | *The Way of Kings*, *Children of Time*, *Dungeon Crawler Carl*, *He Who Fights with Monsters* |
| Classics | 6 | *Pride and Prejudice*, *Nineteen Eighty-Four*, *Slaughterhouse-Five* |
| Children's and young adult | 5 | *The Very Hungry Caterpillar*, *The Lightning Thief*, *The Hunger Games* |
| Graphic novels | 3 | *Watchmen*, *Maus*, *Heartstopper* |
| Estonian books in English | 4 | *The Man Who Spoke Snakish*, *The Czar's Madman*, *Treading Air*, *Truth and Justice* |
| Translated into English | 1 | *The Hotel Years* |

Each book was searched twice, once with its title as a reader would type it
and once with the title and the author's surname. A book counts as found when
a result in the first five has a matching title and author.

ISBNs were checked separately, because a barcode scan asks by number. 150
ISBNs of English editions of literary works were picked at random from Wikidata
(CC0), which neither service draws on, and looked up on each.

The scripts are not kept in the repository. They searched each service no
faster than its stated limit and cached every answer.

## Results

| | Open Library | Apple (Estonian store) |
| --- | --- | --- |
| Found by title, first result | 71 of 75 | 68 of 75 |
| Found by title and author, in the first five | 75 of 75 | 72 of 75 |
| Wikidata ISBNs known (150) | 127 (85%) | 28 (19%) |
| Of those published since 2010 (47) | 37 (79%) | 5 (11%) |
| Cover, for the books found | 72 of 73 | 72 of 72 |
| Description, for the books found | 68 of 73 | 72 of 72 |
| Typical answer time | 1.0 s search, 1.2 s ISBN | 0.2 s |
| Key | none | none |

**Open Library.** The four books not first by title alone have one-word titles
(*James*, *Orbital*, *Educated*) or a common one (*Truth and Justice*), and each
came first once the author was added. A translated book is filed under its
original work, so *The Last Wish* is the work „Ostatnie życzenie“. Searching
with `lang=en` and asking for `editions` returns the English edition inside
it, with its own title and ISBNs. Without that, *The Last Wish* and *The Man
Who Spoke Snakish* were missed. The edition Open Library picks is sometimes
odd, such as a study guide for *Slaughterhouse-Five* or a boxed set, so the
work's title should lead when it is in English. The ISBNs it did not know were
mostly self-published editions (`979-8`), e-book ISBNs, cheap reprints printed
outside the English-speaking world and a few academic books. One search took
five seconds.

**Apple.** Apple covers its own e-book store, so it found almost every title
but knew only 25 of 196 print ISBNs taken from Open Library's English editions.
A barcode on a paperback is a print ISBN. It found none of the Estonian books in
English except Kivirähk.

**Google Books.** Not measured. Every request without a key is refused
(`quota_limit_value: 0`), and its terms rule out the key Loe would need (see
below). It can be measured if a server ever becomes an option.

**Others.** The Library of Congress answers through a Cloudflare challenge that
an app cannot pass. Wikidata, used here for the ISBN sample, is not built for
searching books by title. BookBrainz holds 27,000 editions. Hardcover needs every
reader to have a Hardcover account. ISBNdb is paid and its key "may not be
shared, published or transferred".

## Terms

Checked against each service's own pages on 19 November 2026.

**Open Library** ([API](https://openlibrary.org/developers/api),
[FAQ](https://openlibrary.org/help/faq/using),
[covers](https://openlibrary.org/dev/docs/api/covers)):

- No key. One request a second per address by default, three for requests
  whose `User-Agent` names the app and gives "your contact email or phone
  number". Each phone asks from its own address.
- They ask apps to "make useful, time-sensitive requests on behalf of human
  users" and to "cache responses whenever possible". They ask them not to use
  Open Library "as a backend for high-traffic commercial services". A reader
  searching from their phone is the first kind.
- The catalogue is contributed under CC0 1.0. Covers and descriptions are not
  covered by that statement: descriptions are often the publisher's blurb.
  Showing them with "From Open Library" is the safe course.
- Covers by cover id (`covers.openlibrary.org/b/id/<id>-M.jpg`, the id comes
  with each search result) are not rate limited. Covers by ISBN are limited to
  100 every five minutes. `?default=false` returns 404 instead of a blank image.
  A link back is "appreciated", on an About page.
- The search response schema "is not guaranteed to be stable", so decoding must
  be defensive.

**Google Books** ([terms](https://developers.google.com/terms),
[branding](https://developers.google.com/books/branding)):

- Needs an API key. The terms say "You will keep your credentials confidential"
  and "Developer credentials may not be embedded in open source projects".
  Loe's source is public, and a key in the app can be read out of it. Google's
  own page calls bypassing the iOS bundle restriction "straightforward".
- Every result must show "powered by Google" and link to Google Books.
- The only compliant setup is a server that holds the key, which Loe does not
  have.

**Apple** ([Search API](https://performance-partners.apple.com/search-api)):

- No key, about 20 requests a minute.
- Content may be used "only to promote store content and not for entertainment
  purposes", next to a store badge that links to the item, and not "for
  independent entertainment value apart from its promotional purpose". Showing
  Apple's covers and descriptions on a reader's shelf does not fit that.

## Privacy

A search sends what the reader typed to Open Library, and a scan sends the
ISBN, from the phone's address, as any website would see. Open Library is run
by the Internet Archive, which says it does not use tracking cookies and, "in
most circumstances", logs a hash of the address with a daily key instead of
the address itself ([Internet Archive](https://help.archive.org/help/what-is-a-view/)).

The request carries no cookies and nothing about the reader. The
`User-Agent` names the app and a contact for the developer, as Open Library
asks. Loe keeps nothing of it, so the manifest's collected data stays empty.
The privacy section of `docs/release.md` and the comment in
`PrivacyInfo.xcprivacy` say what is sent, as they do for ESTER.

## Offline

Open Library's monthly dump is 12.6 GB of editions (October 2026) for 57
million editions and 42 million works. How many are English with an ISBN is not
published and would have to be counted from the dump. Loe's catalogue holds
312,349 editions in 31 MB compressed, so a few hundred thousand popular English
works would, as an estimate, add as much again to the download, and still miss
the newest and the niche books that online search finds. The offline catalogue keeps working
with no network, which is enough.

## How it would fit

Today everything about a book comes from the catalogue, so a book from Open
Library needs its own path in a few places:

- **Search.** `SearchView` asks `Catalogue.search` and shows `CatalogueWork`s.
  Online results would come from a new shared client and show below the
  catalogue's. Books the catalogue already has, by
  ISBN or by folded title and lead author, are left out of them. With no
  network, the catalogue's results show as now. Search needs the catalogue to
  be downloaded today, which can stay.
- **Barcode scanning.** A scan types the ISBN into search. When the catalogue
  has no edition with it, the same search asks Open Library by ISBN before
  showing "No book with this ISBN".
- **Shelves.** `ShelvedBook` finds a book by `workKey`, the folded title and
  authors. An online book can use the same key, so an English book the
  catalogue also has, such as one of Kross's, stays one book. Its `erbID` stays
  empty. It needs a few new optional properties: the Open Library work, the
  ISBN, the language and the cover id. Following the CloudKit rules in
  [Library](../library.md), they are added, never renamed.
- **Book page.** The header, shelf controls, cover photo and bookshop links
  work by title and author. The editions, ESTER link, library availability,
  same-author and similar-book sections need catalogue editions and are left
  out. A cover from Open Library shows until the reader takes their own
  photo. Where the catalogue has an Estonian translation, the page links to it,
  and through it to the libraries that hold it.
- **Read next.** Suggestions come from the catalogue. An online book can still
  lead to suggestions through its Estonian translation, and its author when the
  catalogue has them.

A book added by hand needs the same shelf and page changes without the
network, so the two can share them.

## Covers and descriptions

The same responses answer the cover art and description questions for books
from abroad. Open Library had a cover for 72 of the 73 sample books it matched
and a description for 68. It had covers for only 2 of 80 catalogue ISBNs
when that was sampled earlier (see "Covers" in [Library](../library.md)), so
Estonian books still need another source.

## Open questions

1. Use Open Library for books from abroad, and leave Google Books and Apple out?
2. Search online as the reader types, alongside the catalogue, or only when they
   tap to search further?
3. Open Library asks for an email or phone number in the `User-Agent` for its
   higher limit. Give one, or name only the app and the repository and keep
   one request a second?
4. Show Open Library's covers and descriptions for these books, marked as
   coming from Open Library?
5. Leave the offline catalogue as it is, with no Open Library subset?

## Decisions

Made by the maintainer after reading this note:

- **Open Library is the source** for books from abroad. Google Books and Apple
  are left out.
- **Search online once the reader stops typing**, alongside the catalogue,
  never on every keystroke. A phone stays under Open Library's limit of one
  request a second.
- **The `User-Agent` names the app and the repository's address**, with no
  email or phone number, so the limit stays at one request a second.
- **Covers from Open Library are shown, credited to Open Library.** Whether
  descriptions are shown is decided with the description task.
- **The offline catalogue stays as it is.** Covers load from Open Library when
  it has one, for books from the catalogue as well as books from abroad, and
  the reader's own photo always wins.
