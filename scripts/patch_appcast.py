#!/usr/bin/env python3
"""
Patch appcast.xml with a new or updated version entry for BreakMate.
Matches the logic in scripts/create_dmg.sh.
"""

import argparse
import datetime
import os
import re
import sys


def parse_args():
    parser = argparse.ArgumentParser(description="Update appcast.xml for Sparkle")
    parser.add_argument("--appcast", default="appcast.xml", help="Path to appcast.xml")
    parser.add_argument("--version", required=True, help="Short version (e.g. 1.8.0)")
    parser.add_argument("--build", required=True, help="Build number (e.g. 38)")
    parser.add_argument("--signature", default="", help="Sparkle Ed25519 signature")
    parser.add_argument("--size", default="0", help="DMG file size in bytes")
    parser.add_argument("--url", required=True, help="DMG download URL")
    parser.add_argument("--notes-file", default="", help="Path to release notes file")
    parser.add_argument("--notes", default="", help="Inline release notes")
    parser.add_argument("--dry-run", action="store_true", help="Print preview without writing")
    return parser.parse_args()


def main():
    args = parse_args()

    appcast_path = args.appcast
    if not os.path.isfile(appcast_path):
        print(f"[ERROR] {appcast_path} not found.", file=sys.stderr)
        sys.exit(1)

    raw_notes = "Bug fixes and performance improvements."
    if args.notes_file and os.path.isfile(args.notes_file):
        with open(args.notes_file, "r", encoding="utf-8") as f:
            content = f.read().strip()
            if content:
                raw_notes = content
    elif args.notes:
        raw_notes = args.notes.strip()

    notes_html = (
        raw_notes.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
    )

    pub_date = datetime.datetime.now(datetime.timezone.utc).strftime("%a, %d %b %Y %H:%M:%S +0000")

    with open(appcast_path, "r", encoding="utf-8") as f:
        content = f.read()

    version_exists = bool(re.search(rf'sparkle:shortVersionString="{re.escape(args.version)}"', content))

    if version_exists:
        print(f"[PATCH] Updating existing v{args.version} entry — signature + length.")
        if args.signature:
            content = re.sub(
                r'(sparkle:shortVersionString="' + re.escape(args.version) + r'"[^>]*?)sparkle:edSignature="[^"]*"',
                r'\g<1>' + f'sparkle:edSignature="{args.signature}"',
                content,
                flags=re.DOTALL,
            )
        if args.size and args.size != "0":
            content = re.sub(
                r'(sparkle:shortVersionString="' + re.escape(args.version) + r'"[^>]*?)length="[^"]*"',
                r'\g<1>' + f'length="{args.size}"',
                content,
                flags=re.DOTALL,
            )
        new_content = content
    else:
        print(f"[PATCH] Inserting new v{args.version} entry at top of feed.")
        new_item = f"""        <item>
            <title>Version {args.version}</title>
            <pubDate>{pub_date}</pubDate>
            <description><![CDATA[
                <h3>BreakMate v{args.version}</h3>
                <p>{notes_html}</p>
                <h4>Installation Note (macOS)</h4>
                <p>Since BreakMate is not notarized by Apple, macOS may show a security
                warning on first launch. Open System Settings &gt; Privacy and Security
                and click Allow Anyway next to BreakMate.</p>
            ]]></description>
            <enclosure url="{args.url}"
                       sparkle:version="{args.build}"
                       sparkle:shortVersionString="{args.version}"
                       sparkle:edSignature="{args.signature}"
                       length="{args.size}"
                       type="application/octet-stream" />
        </item>
"""
        m = re.search(r"<language>[^<]+</language>\s*", content)
        if m:
            new_content = content[: m.end()] + new_item + content[m.end() :]
        else:
            new_content = content.replace("</channel>", new_item + "    </channel>")

    if args.dry_run:
        print("[DRY-RUN] Previewing patched appcast.xml:")
        print(new_content[:1000])
    else:
        with open(appcast_path, "w", encoding="utf-8") as f:
            f.write(new_content)
        print("[OK] appcast.xml patched successfully.")


if __name__ == "__main__":
    main()
