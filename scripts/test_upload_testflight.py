"""python3 -I -m unittest discover -s scripts

Runs the upload script in a throwaway repository with a remote of its own.
`xcodebuild` is a stand-in that writes down how it was called, so nothing is
built or uploaded, and no key is read.
"""
import os
import pathlib
import shutil
import stat
import subprocess
import tempfile
import unittest

SCRIPT = pathlib.Path(__file__).resolve().parent / "upload-testflight.sh"

XCODEBUILD = """#!/usr/bin/env bash
echo "$*" >> "$STUB_CALLS"
case "$1" in
    -version)
        echo "Xcode 27.2"
        ;;
    archive)
        while [[ $# -gt 0 && "$1" != -project ]]; do shift; done
        (cd "$(dirname "$2")" && git rev-parse HEAD && find . -type f -not -path './.git') > "$STUB_ARCHIVED"
        exit "${STUB_ARCHIVE_STATUS:-0}"
        ;;
    -exportArchive)
        exit "${STUB_UPLOAD_STATUS:-0}"
        ;;
esac
"""


class Upload(unittest.TestCase):
    def setUp(self):
        self.tmp = pathlib.Path(tempfile.mkdtemp()).resolve()
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)
        self.origin = self.tmp / "origin.git"
        self.work = self.tmp / "work"
        self.calls = self.tmp / "calls"
        self.record = self.tmp / "archived"

        stubs = self.tmp / "stubs"
        stubs.mkdir()
        self.stub(stubs / "xcodebuild", XCODEBUILD)
        key = self.tmp / "key.p8"
        key.write_text("not a key")
        key.chmod(0o600)
        self.env = {
            "PATH": f"{stubs}{os.pathsep}{os.environ['PATH']}",
            "HOME": str(self.tmp),
            "GIT_CONFIG_GLOBAL": os.devnull,
            "GIT_CONFIG_SYSTEM": os.devnull,
            "GIT_AUTHOR_NAME": "Loe",
            "GIT_AUTHOR_EMAIL": "loe@example.com",
            "GIT_COMMITTER_NAME": "Loe",
            "GIT_COMMITTER_EMAIL": "loe@example.com",
            "ASC_KEY_ID": "KEYID",
            "ASC_ISSUER_ID": "issuer",
            "ASC_KEY_PATH": str(key),
            "STUB_CALLS": str(self.calls),
            "STUB_ARCHIVED": str(self.record),
        }

        self.git("init", "--quiet", "--bare", "--initial-branch=main", str(self.origin), cwd=self.tmp)
        self.git("clone", "--quiet", str(self.origin), str(self.work), cwd=self.tmp)
        self.git("switch", "--quiet", "-c", "main")
        self.write("scripts/upload-testflight.sh", SCRIPT.read_text())
        (self.work / "scripts/upload-testflight.sh").chmod(0o755)
        self.write("scripts/synced-models.txt", "ShelvedBook.title\n")
        self.write("scripts/synced-models.deployed.txt", "ShelvedBook.title\n")
        self.write("Loe.xcodeproj/project.pbxproj", "\t\t\t\tMARKETING_VERSION = 0.1.0;\n\t\t\t\tMARKETING_VERSION = 0.1.0;\n")
        self.write("ExportOptions.plist", "<plist/>\n")
        self.write(".gitignore", "build/\n")
        self.commit("first")
        self.write("Loe/App.swift", "// the app\n")
        self.commit("second")
        self.git("push", "--quiet", "origin", "main")

    def stub(self, path, text):
        path.write_text(text)
        path.chmod(path.stat().st_mode | stat.S_IXUSR)

    def git(self, *args, cwd=None):
        result = subprocess.run(
            ["git", *args], cwd=cwd or self.work, env=self.env, capture_output=True, text=True, check=True
        )
        return result.stdout.strip()

    def write(self, name, text):
        path = self.work / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)

    def commit(self, subject):
        self.git("add", "--all")
        self.git("commit", "--quiet", "-m", subject)

    def upload(self, *args, **env):
        return subprocess.run(
            [str(self.work / "scripts/upload-testflight.sh"), *args],
            cwd=self.tmp, env={**self.env, **env}, capture_output=True, text=True,
        )

    def refused(self, result, words):
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn(words, result.stderr)
        self.assertFalse(self.calls.exists(), "xcodebuild ran for an upload that was refused")

    def archived(self):
        commit, *files = self.record.read_text().split()
        return commit, files

    def test_a_dry_run_names_the_build_and_builds_nothing(self):
        result = self.upload("--dry-run")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(f"Loe 0.1.0 (2) from {self.git('rev-parse', '--short', 'main')}", result.stdout)
        self.assertFalse(self.calls.exists())
        self.assertFalse((self.work / "build").exists())

    def test_an_upload_archives_main_with_its_commit_count_as_the_build_number(self):
        result = self.upload()
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = self.calls.read_text().splitlines()
        self.assertEqual(calls[0], "-version")
        self.assertTrue(calls[1].startswith("archive "), calls)
        self.assertIn(" CURRENT_PROJECT_VERSION=2 ", calls[1])
        self.assertTrue(calls[2].startswith("-exportArchive "), calls)
        self.assertIn("Xcode 27.2", (self.work / "build/archive.log").read_text())

    def test_what_the_checkout_holds_stays_out_of_the_archive(self):
        self.git("switch", "--quiet", "-c", "feat/elsewhere")
        self.write("Loe/Unmerged.swift", "// not on main\n")
        self.commit("third")
        self.write("Loe/Stray.swift", "// never committed\n")
        self.write("Loe/App.swift", "// changed here\n")

        result = self.upload()
        self.assertEqual(result.returncode, 0, result.stderr)
        commit, files = self.archived()
        self.assertEqual(commit, self.git("rev-parse", "origin/main"))
        self.assertIn("./Loe/App.swift", files)
        self.assertNotIn("./Loe/Unmerged.swift", files)
        self.assertNotIn("./Loe/Stray.swift", files)
        self.assertIn(" CURRENT_PROJECT_VERSION=2 ", self.calls.read_text())

    def test_the_worktree_is_gone_after_an_upload_and_after_a_failed_one(self):
        self.assertEqual(self.upload().returncode, 0)
        self.assertEqual(len(self.git("worktree", "list").splitlines()), 1)
        self.assertNotEqual(self.upload(STUB_ARCHIVE_STATUS="65").returncode, 0)
        self.assertEqual(len(self.git("worktree", "list").splitlines()), 1)

    def test_a_script_that_is_not_the_one_on_main_is_refused(self):
        with open(self.work / "scripts/upload-testflight.sh", "a") as script:
            script.write("# changed here\n")
        self.refused(self.upload("--dry-run"), "This script is not the one on main")

    def test_synced_models_that_main_has_not_recorded_as_deployed_are_refused(self):
        self.write("scripts/synced-models.txt", "ShelvedBook.title\nShelvedBook.finished\n")
        self.commit("third")
        self.git("push", "--quiet", "origin", "main")
        result = self.upload("--dry-run")
        self.refused(result, "The synced models changed")
        self.assertIn("> ShelvedBook.finished", result.stderr)

    def test_the_deployed_record_is_read_from_main_and_not_from_the_checkout(self):
        self.write("scripts/synced-models.deployed.txt", "ShelvedBook.title\nShelvedBook.finished\n")
        self.assertEqual(self.upload("--dry-run").returncode, 0)

    def test_a_key_others_can_read_is_refused(self):
        pathlib.Path(self.env["ASC_KEY_PATH"]).chmod(0o644)
        self.refused(self.upload("--dry-run"), "chmod 600")


if __name__ == "__main__":
    unittest.main()
