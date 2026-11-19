# Library availability

A book page could show, for the library branches a reader picks, whether
each one has the book on the shelf, on loan until a date, or not at all.
This note says where that data lives, how Loe would ask for it, and what it
would cost in privacy. It was written in November 2026, before any of it was
built. The decisions it needs are at the end.

## The short answer

It can be built without a server. ESTER, the union catalogue that Tallinn
Libraries (Tallinna Raamatukogud, legally still Tallinna Keskraamatukogu)
use as their own catalogue, shows every copy with its branch, its status and
its due date. Loe already knows the ESTER record for each edition. The phone
can ask ESTER directly, with no login and no key.

Bookshops are different. Rahva Raamat and Apollo show stock per shop on
their own pages, but only through their web front ends, with no public
interface. They should stay plain links.

## Where the data is

### ESTER

ESTER is Innovative's Sierra WebPAC Pro at `www.ester.ee`. It answers on two
interfaces that both carry per-copy status.

**The web catalogue.** A record page or its holdings page lists each copy as a
row with location, call number and status. Adding a scope limits the rows to
one library. Scope 8 is Tallinn Libraries. `*est` gives Estonian labels.

```
GET https://www.ester.ee/search~S8*est?/.b5206912/.b5206912/1,1,1,B/holdings~5206912&FF=&1,0,
```

The rows, trimmed, for Oskar Luts' „Kevade“ (2025):

```
TlnRK Kännukuke lastekirjandus | L E/LUT | KOHAL
TlnRK Kännukuke lastekirjandus | L E/LUT | TÄHTAEG 01.12.26
TlnRK Nõmme lastekirjandus     | L E/LUT | KOHAL
TlnRK Nõmme lastekirjandus     | L E/LUT | VARUKOGUS
TlnRK Pelguranna lastekirjandus| L E/LUT | KOHAL
TlnRK Väike-Õismäe lastekirjandus | L E/LUT | TEEL
```

The record page (`https://www.ester.ee/record=b5206912~S8*est`) shows only
about ten rows. The holdings page shows them all, 87 for this edition. A page
is 40 to 75 KB of HTML.

**Z39.50.** ELNET publishes it as ESTER's machine interface: host
`www.ester.ee`, port 212 for UTF-8, database `innopac`, record syntaxes
MARC21, OPAC, SUTRS and XML. The OPAC syntax returns the MARC record and every
copy in `holdingsAndCirc` elements: `localLocation` is the branch,
`callNumber` the shelf mark, and `publicNote` the status. Sierra leaves the
structured `circulationData` empty, so the status is text.

```
search: bib-1 use 12 (local number) = "b1817924"   result count 1
present: 1 record, syntax OPAC (1.2.840.10003.5.102)

TlnL Kännukuke home lending | E/TAM c.2 | Returned
TlnL Nõmme home lending     | E/TAM c.2 | AVAILABLE
TlnL Nõmme home lending     | E/TAM c.3 | DUE 27.11.26
TlnL Väike-Õismäe home lending | E/TAM | DUE 03.12.26 IN RESERVE COLLECTION
```

It returned the same copies as the web page (87 for „Kevade“ 2025, 19 for
„Tõde ja õigus. I“ 2003) in 4 to 11 KB. Labels are English only. It is plain
TCP with no TLS.

`https://www.ester.ee/xrecord=b…` and the OAI-PMH feed carry the
bibliographic record only, with no copies.

### Tallinn Libraries

The library's own site links to ESTER as its catalogue and has no separate
one. Its locations page (`tallinnaraamatukogud.ee/asukohad/`) lists every
ESTER location label in both languages, such as
`TlnRK Kännukuke kojulaenutus / TlnL Kännukuke home lending`. There are 20
branches plus the bus and three small lending points.

### URRAM

URRAM is the system of many county, parish and school libraries. Tallinn does
not use it. It was not tested here.

## Matching an edition

Loe's `erb_id` is the ESTER record number with its check digit. Dropping the
last character gives the record, as `BookLinks.ester` already does. The web
catalogue refuses the 9-character form. Z39.50 accepts both forms.

ISBN search works too (`searchtype=i`), but it is not needed. Many old books
carry the ISBN of their digitised PDF, so an ISBN can point to an old
edition.

The catch is the edition. A library may hold one edition of a work and not
another. Tallinn holds dozens of copies of the 2025 „Kevade“ and none of some
older ones. Asking only about the edition on screen would say Puudub while
the book is on the shelf. Loe already lists the work's editions, so it can ask
about all of them. Z39.50 can likely do that in one search with OR, but that
was not tried.

## Mapping the status

| ESTER (Estonian) | Z39.50 (English) | Loe shows |
| --- | --- | --- |
| KOHAL | AVAILABLE | Kohal |
| TÄHTAEG 10.12.26 | DUE 10.12.26 | Tähtaeg 10.12.26 |
| TEEL | not seen | In transit between branches |
| Teavik tagastamisel | Returned | Being returned |
| VARUKOGUS | IN RESERVE COLLECTION | In storage, can be ordered |
| no row for the branch | no row | Puudub |

Due dates can be long past, such as 20.03.19, which likely marks a lost copy.
Reference collections (`teatmekogu`) and reading rooms are in-library use
only. The picker should list branches, and a branch's status should come from
its lending and children's collections.

## Bookshops

**Rahva Raamat.** The product page embeds each shop with a count:
`"shops":[{"id":9,"name":"Tallinna Viru Keskuse Rahva Raamat",…,"amount_available":1}]`.
Finding the product needs the site's search, which runs in the browser. There
is no public interface. robots.txt allows product pages.

**Apollo.** The "Saadavus kauplustes" panel calls a Next.js server action
(`getProductAvailability`) whose id changes with each deployment. Its code
reads `is_available` and `qty` per shop. robots.txt allows product pages and
blocks search.

Both would break without warning. Shops should stay links.

## Privacy

Loe now promises no tracking and no collected data. The only network use
is the catalogue download, which sends nothing about the reader.

A lookup tells ESTER which edition the reader is looking at, from the
reader's IP address. ESTER says it keeps web server logs and cookies to count
visits. Over Z39.50 the record number also crosses the network unencrypted.

Recommendation, for the maintainer to decide:

- Look up only when the reader taps "Check availability" on a book, never on
  opening the page. Remember the picked branches on the phone only.
- Prefer the HTTPS web catalogue over Z39.50, so the lookup is encrypted, and
  send no cookies.
- Say it next to the button: "Asks ESTER, the library catalogue, about this
  book. Loe sends nothing else." ESTER still sees the phone's IP address, as
  any website does, so the note does not promise more than that.
- Update the "Privacy" section of `docs/release.md` and the comment in
  `PrivacyInfo.xcprivacy`. The manifest itself likely stays as it is: Loe
  keeps nothing and ESTER is not a tracking domain. Check that against Apple's
  definition of collected data before shipping.

## Rules of use

- ESTER's `robots.txt` is `Disallow: /` for every agent. A lookup on a
  reader's tap is not a crawler, but it is the same web pages.
- The ESTER statutes say the catalogue is public and freely accessible
  (7.1), that anything giving internet access to it must use its name or logo
  (7.2), and that institutions other than Estonian libraries may copy the data
  only with ELNET's permission (7.3).
- Z39.50 is the interface ELNET documents for machines.
- No login, key or bot protection showed up in about 30 requests. Each
  response sets a session cookie, which is not needed.

Asking ELNET (ester@elnet.ee) before shipping is the safe course.

## Open questions

1. Is a tap-only lookup acceptable, and does the manifest stay unchanged?
2. Ask ELNET first, and use the web pages or Z39.50?
3. Ask about the edition on screen, or every edition of the work?
4. Which collections count for a branch: home lending and children's?
5. Offer only Tallinn branches first, or every ESTER library (Tartu City
   Library has branches too)?

## Decisions

Made by the maintainer after reading this note:

- **Availability shows as soon as a book's page opens**, with no button to
  tap. So every page view asks ESTER, and the privacy section of
  `docs/release.md` must say so. The lookup still goes over HTTPS with no
  cookies, and sends nothing but the record numbers.
- **Every edition of the book is checked.** When the edition on screen is not
  on a library's shelf but another edition is, the library's row says so and
  names that edition.
- **Every ESTER library can be picked**, not only Tallinn's. The picker needs
  the list of ESTER locations for all libraries, grouped by library.

- **A copy counts by the collection it is in.** Home lending and children's
  copies are Kohal when on the shelf. Storage copies (`varukogu`) show as able
  to be ordered. Reference and reading-room copies (`teatmekogu`) show as only
  to read in the library.
- **ELNET is asked before any public release.** Internal TestFlight testing
  goes ahead without it, and the going-public checklist in `docs/release.md`
  gets the step when availability ships.
