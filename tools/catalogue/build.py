"""Builds Loe's offline catalogue from the Estonian National Bibliography.

    python3 -I tools/catalogue/build.py OUT.sqlite ERB_eestikeelne_raamat.zip ERB_muukeelne_raamat.zip

Inputs are the National Library's MARC21XML exports, as a ZIP or plain XML.
docs/catalogue.md says where they come from and how each field is read.
"""
import datetime
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
MARC = "{http://www.loc.gov/MARC21/slim}"
SUBJECT, GENRE = 1, 2


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
    headings: list = field(default_factory=list)  # (kind, name, ems_id)


def subfields(d, code):
    return [v for c, v in d[3] if c == code]


def read(path):
    """Yields every MARC record in a ZIP or XML file, streaming."""
    if path.endswith(".zip"):
        archive = zipfile.ZipFile(path)
        source = archive.open(next(n for n in archive.namelist() if n.endswith(".xml")))
    else:
        source = open(path, "rb")
    with source:
        root = None
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


# Cleaning

TRAILING = re.compile(r"[\s/:;=,]+$")
# A final full stop after these is part of the abbreviation, not ISBD punctuation.
ABBREVIATIONS = {
    "kd", "tr", "nr", "jt", "jne", "vms", "jm", "lk", "ill", "toim", "koost", "parand", "täiend",
    "ed", "vol", "bd", "aufl", "eds", "hrsg", "inc", "ltd", "co", "jr", "sr", "dr", "prof", "st", "т", "изд",
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


def isbn13(raw):
    """A valid ISBN-13 for an ISBN-10 or ISBN-13 in any punctuation, or None."""
    digits = re.sub(r"[^0-9Xx]", "", raw.strip().split(" ")[0].split("(")[0]).upper()
    if len(digits) == 10:
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


def skip_reason(record):
    if record.leader[6:7] != "a":
        return "not text"
    if record.fields("502"):
        return "thesis"
    if any("Digikoopia" in v for d in record.fields("588") for v in subfields(d, "a")):
        return "digital copy of a print record"
    if not record.control.get("001") or not record.fields("245"):
        return "no id or title"
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
    title = clean(" ".join(subfields(title_field, "a"))) or ""
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
    edition.language = fixed[35:38].strip() or None if len(fixed) >= 38 else None
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
            if number and number not in seen:
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


def build(out, inputs, latest_year=None, log=print):
    latest_year = latest_year or datetime.date.today().year + 1
    if os.path.exists(out):
        os.remove(out)
    db = sqlite3.connect(out)
    with open(SCHEMA, encoding="utf-8") as schema:
        db.executescript(schema.read())
    insert = f"INSERT OR IGNORE INTO edition ({','.join(EDITION_COLUMNS)}) VALUES ({','.join('?' * len(EDITION_COLUMNS))})"
    headings = {}
    kept, skipped = 0, {}
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
        "built": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "editions": str(kept),
        "source": "Eesti rahvusbibliograafia, Eesti Rahvusraamatukogu",
    }
    db.executemany("INSERT INTO meta VALUES (?, ?)", meta.items())
    db.commit()
    db.execute("VACUUM")
    db.close()
    log(f"kept {kept}")
    for reason, count in sorted(skipped.items()):
        log(f"skipped {count} ({reason})")
    return kept, skipped


if __name__ == "__main__":
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    build(sys.argv[1], sys.argv[2:])
