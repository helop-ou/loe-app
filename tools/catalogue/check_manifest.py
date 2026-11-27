"""Checks that every catalogue in manifest.json is published as the manifest says.

    python3 -I tools/catalogue/check_manifest.py

Asks GitHub for the release each catalogue's address names. It fails unless
that release is immutable and holds a file at the address, with the manifest's
SHA-256 and size. It needs the network, so CI runs it as a step of its own and
the build's tests never do. GITHUB_TOKEN, when set, is sent with each request.
"""
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build  # noqa: E402

REPOSITORY = "helop-ou/loe-app"
API = "https://api.github.com"
ADDRESS = re.compile(rf"https://github\.com/{re.escape(REPOSITORY)}/releases/download/([^/]+)/[^/]+")


def release(tag):
    """The published release with a tag, as GitHub describes it, or None when there is none."""
    request = urllib.request.Request(
        f"{API}/repos/{REPOSITORY}/releases/tags/{urllib.parse.quote(tag, safe='')}",
        headers={"Accept": "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28"},
    )
    token = os.environ.get("GITHUB_TOKEN")
    if token:
        request.add_header("Authorization", f"Bearer {token}")
    try:
        with urllib.request.urlopen(request, timeout=30) as answer:
            return json.load(answer)
    except urllib.error.HTTPError as error:
        with error:
            if error.code == 404:
                return None
            raise OSError(f"{error.code} {error.reason}") from None


def problem(catalogue, release_for):
    """What stops an app from trusting a catalogue's entry, or None."""
    address = catalogue.get("url", "")
    match = ADDRESS.fullmatch(address)
    if not match:
        return f"its address is not a file of a release of {REPOSITORY}: {address!r}"
    tag = urllib.parse.unquote(match.group(1))
    published = release_for(tag)
    if published is None:
        return f"the release {tag} is not published"
    if published.get("immutable") is not True:
        return f"the release {tag} is not immutable, so its file can be replaced"
    file = next((a for a in published.get("assets", []) if a.get("browser_download_url") == address), None)
    if file is None:
        return f"the release {tag} has no file at {address}"
    if file.get("digest") != f"sha256:{catalogue.get('sha256')}":
        return f"the manifest's sha256 is {catalogue.get('sha256')} and the file's is {file.get('digest')}"
    if file.get("size") != catalogue.get("size"):
        return f"the manifest's size is {catalogue.get('size')} and the file's is {file.get('size')}"
    return None


def problems(manifest, release_for):
    """One line for each catalogue in a manifest that is not published as it says."""
    return [
        f"the catalogue of schema {catalogue.get('schema_version')}: {found}"
        for catalogue in build.catalogues(manifest)
        if (found := problem(catalogue, release_for))
    ]


def main():
    with open(build.MANIFEST, encoding="utf-8") as f:
        manifest = json.load(f)
    try:
        found = problems(manifest, release)
    except OSError as error:
        sys.exit(f"error: could not read a release from GitHub: {error}")
    for line in found:
        print(f"error: {line}", file=sys.stderr)
    if found:
        sys.exit(1)
    print(f"Every catalogue in the manifest is published as it says: {len(build.catalogues(manifest))} checked")


if __name__ == "__main__":
    main()
