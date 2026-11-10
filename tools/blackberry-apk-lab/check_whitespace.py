#!/usr/bin/env python3
"""Check the committed PR or push range, including a newly created branch."""

import argparse
import re
import subprocess
import sys


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("base", help="pull-request base SHA or push event's before SHA")
    parser.add_argument("head", help="checked-out GitHub commit SHA")
    args = parser.parse_args(argv)
    if not all(re.fullmatch(r"[0-9a-fA-F]{40}", value) for value in (args.base, args.head)):
        parser.error("base and head must be full commit SHAs")
    try:
        subprocess.run(["git", "cat-file", "-e", f"{args.head}^{{commit}}"], check=True)
        base = args.base
        if base == "0" * 40:
            # A branch-creation push has no previous commit; check its whole tree.
            base = subprocess.run(["git", "hash-object", "-w", "-t", "tree", "--stdin"],
                                  input="", capture_output=True, text=True, check=True).stdout.strip()
        else:
            present = subprocess.run(["git", "cat-file", "-e", f"{base}^{{commit}}"],
                                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
            if present.returncode:
                # A force-push's previous tip may be outside the checked-out history.
                subprocess.run(["git", "fetch", "--no-tags", "--depth=1", "origin", base], check=True)
            subprocess.run(["git", "cat-file", "-e", f"{base}^{{commit}}"], check=True)
        return subprocess.run(["git", "diff", "--check", base, args.head, "--"], check=False).returncode
    except (OSError, subprocess.CalledProcessError) as error:
        print(f"apk-research whitespace check: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
