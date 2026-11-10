#!/usr/bin/env python3
"""Check committed changes against the PR, previous push, or default-branch base."""

import argparse
import re
import subprocess
import sys


def unavailable(reason):
    print(f"::notice::Committed whitespace range unavailable for branch creation: {reason}")
    return 0


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("base", help="pull-request base SHA or push event's before SHA")
    parser.add_argument("head", help="checked-out GitHub commit SHA")
    parser.add_argument("--default-branch", help="repository default branch, fetched by checkout")
    parser.add_argument("--head-ref", help="GitHub ref for the push, such as refs/heads/v2")
    args = parser.parse_args(argv)
    if not all(re.fullmatch(r"[0-9a-fA-F]{40}", value) for value in (args.base, args.head)):
        parser.error("base and head must be full commit SHAs")
    try:
        subprocess.run(["git", "cat-file", "-e", f"{args.head}^{{commit}}"], check=True)
        base = args.base
        if base == "0" * 40:
            # An existing repository's inherited files are not new changes.
            if not args.default_branch:
                return unavailable("no default branch was provided")
            default_ref = f"refs/remotes/origin/{args.default_branch}"
            subprocess.run(["git", "check-ref-format", default_ref], check=True)
            if args.head_ref == f"refs/heads/{args.default_branch}":
                return unavailable("the new default branch has no previous ref")
            default = subprocess.run(["git", "rev-parse", "--verify", "--quiet",
                                      "--end-of-options", f"{default_ref}^{{commit}}"],
                                     capture_output=True, text=True, check=False)
            if default.returncode == 1:
                return unavailable("the fetched default-branch ref does not exist")
            default.check_returncode()
            ancestor = subprocess.run(["git", "merge-base", default.stdout.strip(), args.head],
                                      capture_output=True, text=True, check=False)
            if ancestor.returncode == 1:
                return unavailable("the new branch and default branch have unrelated histories")
            ancestor.check_returncode()
            base = ancestor.stdout.strip()
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
