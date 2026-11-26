"""Builds Loe's offline catalogue from the Estonian National Bibliography.

    python3 -I tools/catalogue/build.py [--allow-small] OUT.sqlite ERB_eestikeelne_raamat.zip ERB_muukeelne_raamat.zip

Inputs are the National Library's MARC21XML exports, as a ZIP or plain XML.
docs/catalogue.md says where they come from and how each field is read.
A build that kept nothing, or under 90% of the editions in manifest.json, fails
and leaves no file. --allow-small turns the 90% check off for a sample.

Beside OUT.sqlite it writes fiction-headings.json: the headings on the
catalogue's fiction in Estonian, which the app's tests read.
"""
import datetime
import hashlib
import json
import os
import re
import sqlite3
import sys
import unicodedata
import xml.etree.ElementTree as ET
import zipfile
from dataclasses import dataclass, field

SCHEMA_VERSION = 1
SCHEMA = os.path.join(os.path.dirname(os.path.abspath(__file__)), "schema.sql")
MANIFEST = os.path.join(os.path.dirname(os.path.abspath(__file__)), "manifest.json")
HEADINGS = "fiction-headings.json"
# The app's genres are checked against fiction in Estonian: genre headings are rare
# in other languages.
HEADINGS_LANGUAGE = "est"
MINIMUM_SHARE = 0.9
MARC = "{http://www.loc.gov/MARC21/slim}"
SUBJECT, GENRE = 1, 2


class BuildError(Exception):
    """A build that must not be published."""


@dataclass
class Record:
    leader: str
    control: dict
    data: list  # (tag, ind1, ind2, [(code, value)])

    def fields(self, tag, ind2=None):
        return [d for d in self.data if d[0] == tag and (ind2 is None or d[2] == ind2)]

    def first(self, tag, code, ind2=None):
        for d in self.fields(tag, ind2):
            values = subfields(d, code)
            if values:
                return values[0]
        return None


@dataclass
class Edition:
    erb_id: str
    title: str
    subtitle: str = None
    authors: str = None
    translators: str = None
    year: int = None
    publisher: str = None
    place: str = None
    language: str = None
    original_title: str = None
    original_language: str = None
    edition_statement: str = None
    series: str = None
    series_number: str = None
    pages: int = None
    fiction: int = 0
    electronic: int = 0
    isbns: list = field(default_factory=list)  # (isbn13, qualifier)
    isbns_dropped: int = 0  # 020 $a values that held no valid ISBN
    headings: list = field(default_factory=list)  # (kind, name, ems_id)


def subfields(d, code):
    return [v for c, v in d[3] if c == code]


def read(path):
    """Yields every MARC record in a ZIP or XML file, streaming."""
    if path.endswith(".zip"):
        archive = zipfile.ZipFile(path)
        name = next((n for n in archive.namelist() if n.endswith(".xml")), None)
        if name is None:
            raise BuildError(f"{os.path.basename(path)} holds no XML file")
        source = archive.open(name)
    else:
        source = open(path, "rb")
    with source:
        root = None
        try:
            for event, element in ET.iterparse(source, events=("start", "end")):
                if root is None:
                    root = element
                if event != "end" or element.tag != MARC + "record":
                    continue
                leader, control, data = "", {}, []
                for child in element:
                    kind = child.tag.rsplit("}", 1)[-1]
                    if kind == "leader":
                        leader = child.text or ""
                    elif kind == "controlfield":
                        control[child.get("tag")] = child.text or ""
                    elif kind == "datafield":
                        subs = [(s.get("code"), s.text or "") for s in child]
                        data.append((child.get("tag"), child.get("ind1") or " ", child.get("ind2") or " ", subs))
                yield Record(leader, control, data)
                root.clear()
        except ET.ParseError as error:
            raise BuildError(f"{os.path.basename(path)} is not readable XML: {error}") from error


# Cleaning

TRAILING = re.compile(r"[\s/:;=,]+$")
# A final full stop after these is part of the abbreviation, not ISBD punctuation.
ABBREVIATIONS = {
    "kd", "tr", "nr", "jt", "jne", "vms", "jm", "lk", "ill", "toim", "koost", "parand", "täiend",
    "ed", "vol", "bd", "aufl", "eds", "hrsg", "inc", "ltd", "co", "jr", "sr", "dr", "prof", "st", "т", "изд",
    "repr", "rev", "uppl", "opl", "wyd", "izd", "pain",
}
UNKNOWN_PUBLISHER = re.compile(r"(?i)^s\.\s?[nl]\.?$")


def clean(text):
    """Strips ISBD punctuation, cataloguer brackets and a final full stop."""
    if not text:
        return None
    text = unicodedata.normalize("NFC", text).strip().replace("[", "").replace("]", "")
    text = TRAILING.sub("", text)
    if re.fullmatch(r"\d+\.", text):
        return text[:-1]
    if text.endswith(".") and not text.endswith(".."):
        last = text[:-1].rsplit(" ", 1)[-1].rsplit(".", 1)[-1]
        if not (len(last) == 1 or last.lower() in ABBREVIATIONS):
            text = text[:-1]
    text = TRAILING.sub("", text).strip()
    return text or None


def person(name):
    """'Tammsaare, A. H.,' becomes 'A. H. Tammsaare'."""
    name = clean(name)
    if not name:
        return None
    if ", " in name:
        surname, given = name.split(", ", 1)
        return f"{given} {surname}"
    return name


SPACED_ISBN = re.compile(r"[0-9Xx\- ]+")


def isbn13(raw):
    """A valid ISBN-13 for an ISBN-10 or ISBN-13 in any punctuation, or None.

    The first token is read first. Only when it is no ISBN is the whole text before
    a "(" read, for a number written with spaces. Trailing text is never joined in.
    """
    text = raw.strip()
    number = checked_isbn13(text.split(" ")[0].split("(")[0])
    before = text.split("(")[0]
    if number is None and SPACED_ISBN.fullmatch(before):
        number = checked_isbn13(before)
    return number


def checked_isbn13(text):
    digits = re.sub(r"[^0-9Xx]", "", text).upper()
    if len(digits) == 10:
        if not digits[:9].isdigit():
            return None
        if sum((10 - i) * (10 if c == "X" else int(c)) for i, c in enumerate(digits)) % 11:
            return None
        core = "978" + digits[:9]
    elif len(digits) == 13 and digits.isdigit():
        core = digits[:12]
    else:
        return None
    check = (10 - sum((1 if i % 2 == 0 else 3) * int(c) for i, c in enumerate(core)) % 10) % 10
    full = core + str(check)
    if len(digits) == 13 and full != digits:
        return None
    return full


PAGE_UNIT = re.compile(r"(?i)\blk\b|lk\.|lehek|pages|\bp\.|\bpp\b|\bs\.|\bс\.|стр|\blpp\b|\bstr\b|sivua|sidor|stron")
NOT_PAGES = re.compile(r"(?i)\d+\s*(?:l\.|lehte|kd\.|köide|köidet|võrgu\w*|e-raamat|cm|cd|nummerdamata)")
PAGE_RANGE = re.compile(r"(?i)\b(?:lk|s|p)\.\s*\d+\s*-\s*\d+")


def pages(extent):
    """The page count in a 300 $a, preferring numbered pages over bracketed ones."""
    if not extent or not PAGE_UNIT.search(extent) or PAGE_RANGE.search(extent):
        return None
    extent = NOT_PAGES.sub(" ", extent)
    numbered = re.sub(r"\[[^\]]*\]", " ", extent)
    counts = [int(n) for n in re.findall(r"\d+", numbered) if int(n) < 20000]
    if not counts:
        counts = [int(n) for n in re.findall(r"\d+", extent) if int(n) < 20000]
    return max(counts) if counts else None


def year(record, latest):
    fixed = record.control.get("008", "")
    date = fixed[7:11] if len(fixed) >= 11 else ""
    if date.isdigit():
        value = int(date)
    else:
        statement = record.first("264", "c", "1") or record.first("260", "c") or ""
        match = re.search(r"1[5-9]\d\d|20\d\d", statement)
        value = int(match.group()) if match else None
    return value if value and value <= latest else None


# 008/33 literary form: novels, drama, humour, short stories, poetry, or fiction unspecified.
FICTION_FORMS = set("1dfhjp")
AUTHOR_ROLE = re.compile(r"(?i)^(kaas)?autor|^author")
COMPILER_ROLE = re.compile(r"(?i)^koostaja|^compiler")
TRANSLATOR_ROLE = re.compile(r"(?i)tõlkija|translator")
TRANSLATED_FROM = re.compile(r"Tõlgitud(?: \w+)?(?: raamatust| väljaandest| teosest)?:\s*([^.]+)")


def main_title(record):
    """The cleaned 245 $a, None for a record that has none."""
    return clean(" ".join(subfields(record.fields("245")[0], "a")))


def skip_reason(record):
    if record.leader[6:7] != "a":
        return "not text"
    if record.fields("502"):
        return "thesis"
    if any("Digikoopia" in v for d in record.fields("588") for v in subfields(d, "a")):
        return "digital copy of a print record"
    if not record.control.get("001") or not record.fields("245"):
        return "no id or title"
    if not main_title(record):
        return "no title proper"
    return None


def original_title(record):
    candidates = [record.first("240", "a")]
    candidates += [" ".join(subfields(d, "a")) for d in record.fields("246", "9")]
    for d in record.fields("500"):
        match = TRANSLATED_FROM.search(" ".join(subfields(d, "a")))
        if match:
            candidates.append(match.group(1))
    return next((clean(c) for c in candidates if clean(c)), None)


def series(record):
    for d in record.fields("490"):
        name = clean(" ".join(subfields(d, "a")))
        if name:
            return name, clean(" ".join(subfields(d, "v")))
    for d in record.fields("830") + record.fields("800"):
        name = clean(" ".join(subfields(d, "t") or subfields(d, "a")))
        if name:
            return name, clean(" ".join(subfields(d, "v")))
    return None, None


def convert(record, latest_year):
    title_field = record.fields("245")[0]
    title = main_title(record)
    parts = [clean(p) for p in subfields(title_field, "n") + subfields(title_field, "p")]
    title = ". ".join([title] + [p for p in parts if p])

    authors, compilers, translators = [], [], []
    for d in record.fields("100") + record.fields("700"):
        name = person(" ".join(subfields(d, "a")))
        if not name or subfields(d, "t"):
            continue
        role = " ".join(subfields(d, "e"))
        if TRANSLATOR_ROLE.search(role):
            translators.append(name)
        elif d[0] == "100" or AUTHOR_ROLE.search(role):
            authors.append(name)
        elif COMPILER_ROLE.search(role):
            compilers.append(name)

    edition = Edition(erb_id=record.control["001"], title=title)
    edition.subtitle = clean(" ".join(subfields(title_field, "b")))
    edition.authors = joined(authors or compilers)
    edition.translators = joined(translators)
    edition.year = year(record, latest_year)
    edition.publisher = known(record.first("264", "b", "1") or record.first("260", "b"))
    edition.place = known(record.first("264", "a", "1") or record.first("260", "a"))
    fixed = record.control.get("008", "")
    code = fixed[35:38].strip() if len(fixed) >= 38 else ""
    edition.language = None if code in ("", "|||") else code
    edition.fiction = int(len(fixed) > 33 and fixed[33] in FICTION_FORMS)
    edition.original_title = original_title(record)
    source_language = record.first("041", "h")
    edition.original_language = None if source_language in (None, "und", "mul") else source_language
    edition.edition_statement = clean(record.first("250", "a"))
    edition.series, edition.series_number = series(record)
    extent = " ".join(v for d in record.fields("300") for v in subfields(d, "a"))
    edition.pages = pages(extent)
    edition.electronic = int(
        (record.control.get("007", "")[:2] == "cr" and not record.fields("533"))
        or bool(re.search(r"(?i)võrguressurss|e-raamat|online", extent))
    )

    seen = set()
    for d in record.fields("020"):
        qualifier = clean(" ".join(subfields(d, "q")).strip("()"))
        for raw in subfields(d, "a"):
            number = isbn13(raw)
            if not number:
                edition.isbns_dropped += 1
            elif number not in seen:
                seen.add(number)
                inline = re.search(r"\(([^)]*)\)", raw)
                edition.isbns.append((number, qualifier or (clean(inline.group(1)) if inline else None)))

    for d in record.fields("650"):
        name = clean(" ".join(subfields(d, "a")))
        ems = next((v.rstrip(".").rsplit("/", 1)[-1] for v in subfields(d, "0") if "ems" in v), None)
        if name:
            edition.headings.append((SUBJECT, name, ems))
    for d in record.fields("655"):
        name = clean(" ".join(subfields(d, "a")).replace("(vormimärksõna)", ""))
        if name:
            edition.headings.append((GENRE, name, None))
    return edition


def known(value):
    """Cleans a publisher or place, and drops the "s.n." and "S.l." placeholders."""
    value = clean(value)
    return None if not value or UNKNOWN_PUBLISHER.match(value) else value


def joined(names):
    return "; ".join(dict.fromkeys(n for n in names if n)) or None


EDITION_COLUMNS = [
    "erb_id", "title", "subtitle", "authors", "translators", "year", "publisher", "place", "language",
    "original_title", "original_language", "edition_statement", "series", "series_number", "pages",
    "fiction", "electronic",
]


def sha256(path):
    digest = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def built_at():
    """The build time, or SOURCE_DATE_EPOCH when set so that a build can be repeated."""
    epoch = os.environ.get("SOURCE_DATE_EPOCH")
    try:
        moment = datetime.datetime.fromtimestamp(int(epoch), datetime.timezone.utc) if epoch else None
    except (ValueError, OverflowError, OSError) as error:
        raise BuildError(f"SOURCE_DATE_EPOCH is not a timestamp: {epoch!r}") from error
    return (moment or datetime.datetime.now(datetime.timezone.utc)).strftime("%Y-%m-%dT%H:%M:%SZ")


def check_integrity(db):
    """Fails unless SQLite says the file is sound."""
    try:
        answer = [row[0] for row in db.execute("PRAGMA integrity_check")]
    except sqlite3.DatabaseError as error:
        raise BuildError(f"the catalogue file is damaged: {error}") from error
    if answer != ["ok"]:
        raise BuildError("the catalogue file failed its integrity check: " + "; ".join(answer[:5]))


def check_size(kept, allow_small):
    """Fails a build that kept nothing, or far fewer editions than the published one."""
    if not kept:
        raise BuildError("kept no records: the input is empty or is not MARC21 XML")
    if allow_small:
        return
    with open(MANIFEST, encoding="utf-8") as manifest:
        published = json.load(manifest)["editions"]
    if kept < published * MINIMUM_SHARE:
        raise BuildError(
            f"kept {kept} records, under {MINIMUM_SHARE:.0%} of the {published} last published "
            "(--allow-small skips this check for a sample)"
        )


def headings_path(out):
    """Where a build writes the headings on its fiction: beside the catalogue."""
    return os.path.join(os.path.dirname(out), HEADINGS)


def fiction_headings(db):
    """Each heading name on fiction in Estonian, and how many editions carry it.

    The app's genres find their books by these names, as subjects or as genres, so
    an edition that carries a name as both counts once.
    """
    rows = db.execute(
        "SELECT h.name, COUNT(DISTINCT e.id) FROM heading h "
        "JOIN edition_heading eh ON eh.heading_id = h.id JOIN edition e ON e.id = eh.edition_id "
        "WHERE e.fiction = 1 AND e.language = ? GROUP BY h.name",
        (HEADINGS_LANGUAGE,),
    )
    return dict(sorted(rows))


def write_headings(path, kept, headings):
    """Writes the headings with the catalogue's edition count, which says whose they are."""
    with open(path, "w", encoding="utf-8") as f:
        json.dump({"editions": kept, "language": HEADINGS_LANGUAGE, "headings": headings}, f, ensure_ascii=False, indent=2)
        f.write("\n")


def remove(*paths):
    for path in paths:
        if os.path.exists(path):
            os.remove(path)


def build(out, inputs, latest_year=None, log=print, allow_small=False):
    """Writes the catalogue to out and raises BuildError, leaving no file, if it is not fit to publish."""
    remove(out)
    try:
        kept, skipped = write(out, inputs, latest_year, log)
        check_size(kept, allow_small)
    except BaseException:
        remove(out, headings_path(out))
        raise
    return kept, skipped


def write(out, inputs, latest_year, log):
    latest_year = latest_year or datetime.date.today().year + 1
    db = sqlite3.connect(out)
    with open(SCHEMA, encoding="utf-8") as schema:
        db.executescript(schema.read())
    insert = f"INSERT OR IGNORE INTO edition ({','.join(EDITION_COLUMNS)}) VALUES ({','.join('?' * len(EDITION_COLUMNS))})"
    headings = {}
    kept, skipped, isbns_dropped = 0, {}, 0
    for path in inputs:
        for record in read(path):
            reason = skip_reason(record)
            if reason:
                skipped[reason] = skipped.get(reason, 0) + 1
                continue
            edition = convert(record, latest_year)
            cursor = db.execute(insert, [getattr(edition, c) for c in EDITION_COLUMNS])
            if not cursor.rowcount:
                skipped["duplicate id"] = skipped.get("duplicate id", 0) + 1
                continue
            edition_id = cursor.lastrowid
            kept += 1
            isbns_dropped += edition.isbns_dropped
            db.executemany("INSERT INTO isbn VALUES (?, ?, ?)", [(n, edition_id, q) for n, q in edition.isbns])
            for kind, name, ems in edition.headings:
                key = (kind, name)
                if key not in headings:
                    headings[key] = db.execute(
                        "INSERT INTO heading (kind, name, ems_id) VALUES (?, ?, ?)", (kind, name, ems)
                    ).lastrowid
                db.execute("INSERT OR IGNORE INTO edition_heading VALUES (?, ?)", (edition_id, headings[key]))
    db.execute(
        "INSERT INTO edition_search (rowid, title, authors, series, original_title) "
        "SELECT id, title, authors, series, original_title FROM edition"
    )
    db.execute("INSERT INTO edition_search (edition_search) VALUES ('optimize')")
    meta = {
        "schema_version": str(SCHEMA_VERSION),
        "built": built_at(),
        "editions": str(kept),
        "source": "Eesti rahvusbibliograafia, Eesti Rahvusraamatukogu",
    }
    for number, path in enumerate(inputs, 1):
        meta[f"source_{number}"] = os.path.basename(path)
        meta[f"source_{number}_sha256"] = sha256(path)
    db.executemany("INSERT INTO meta VALUES (?, ?)", meta.items())
    db.commit()
    db.execute("VACUUM")
    check_integrity(db)
    write_headings(headings_path(out), kept, fiction_headings(db))
    db.close()
    log(f"kept {kept}")
    for reason, count in sorted(skipped.items()):
        log(f"skipped {count} ({reason})")
    log(f"dropped {isbns_dropped} ISBN values that were not valid")
    return kept, skipped


if __name__ == "__main__":
    arguments = [a for a in sys.argv[1:] if a != "--allow-small"]
    if len(arguments) < 2:
        sys.exit(__doc__)
    try:
        build(arguments[0], arguments[1:], allow_small="--allow-small" in sys.argv)
    except BuildError as error:
        sys.exit(f"error: {error}")
