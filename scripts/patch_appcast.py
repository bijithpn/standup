#!/usr/bin/env python3
"""
Patch appcast.xml with a new or updated version entry for BreakMate.
Matches the logic in scripts/create_dmg.sh.
"""

import argparse
import datetime
import html
import os
import re
import sys

INSTALL_NOTE = """<h4>Installation Note (macOS)</h4>
                <p>Since BreakMate is not notarized by Apple, macOS may show a security
                warning on first launch. Open System Settings &gt; Privacy and Security
                and click Allow Anyway next to BreakMate.</p>"""


def _inline(text):
    """Escape HTML, then apply inline Markdown (code, bold, italic, links)."""
    text = html.escape(text, quote=False)
    codes = []

    def stash(m):
        codes.append(m.group(1))
        return f"\x00{len(codes) - 1}\x00"

    text = re.sub(r"`([^`]+)`", stash, text)
    text = re.sub(r"\*\*(.+?)\*\*|__(.+?)__", lambda m: f"<strong>{m.group(1) or m.group(2)}</strong>", text)
    text = re.sub(r"(?<![\w*])\*(?!\s)(.+?)(?<!\s)\*(?![\w*])", r"<em>\1</em>", text)
    text = re.sub(r"\[([^\]]+)\]\((https?://[^)\s]+)\)", r'<a href="\2">\1</a>', text)
    text = re.sub(r"(?<![\"'>=])(https?://[^\s<]+[^\s<.,;:!?)])", r'<a href="\1">\1</a>', text)
    return re.sub(r"\x00(\d+)\x00", lambda m: f"<code>{codes[int(m.group(1))]}</code>", text)


def markdown_to_html(md):
    """Minimal dependency-free Markdown -> HTML for Sparkle release notes."""
    out, para, items, kind = [], [], [], None

    def flush_para():
        if para:
            out.append("<p>" + "<br>".join(_inline(l) for l in para) + "</p>")
            para.clear()

    def flush_list():
        nonlocal kind
        if items:
            out.append(f"<{kind}>" + "".join(f"<li>{_inline(i)}</li>" for i in items) + f"</{kind}>")
            items.clear()
        kind = None

    for line in md.replace("\r\n", "\n").split("\n"):
        line = line.rstrip()
        h = re.match(r"^(#{1,6})\s+(.*)$", line)
        b = re.match(r"^\s*[-*+]\s+(.*)$", line)
        n = re.match(r"^\s*\d+[.)]\s+(.*)$", line)
        if not line.strip():
            flush_para(); flush_list()
        elif h:
            flush_para(); flush_list()
            out.append(f"<h{4 if len(h.group(1)) <= 2 else 5}>{_inline(h.group(2))}</h{4 if len(h.group(1)) <= 2 else 5}>")
        elif re.match(r"^\s*([-*_])\1{2,}\s*$", line):
            flush_para(); flush_list(); out.append("<hr>")
        elif b or n:
            flush_para()
            want = "ul" if b else "ol"
            if kind != want:
                flush_list(); kind = want
            items.append((b or n).group(1))
        elif items and line.startswith(("  ", "\t")):
            items[-1] += " " + line.strip()
        else:
            flush_list(); para.append(line)
    flush_para(); flush_list()
    return "\n                ".join(out)


def rerender_existing(content):
    """Repair legacy release-note layouts so every entry is clean HTML.

    Handles: raw Markdown inside <p>, bare Markdown with no HTML wrapper, and
    HTML tags that were entity-escaped (&lt;li&gt;) by older release scripts.
    """
    notes_pat = re.compile(r"(<h3>BreakMate v[^<]*</h3>\s*)<p>(.*?)</p>(\s*<h4>Installation Note)", re.DOTALL)
    escaped_tag = re.compile(r"&lt;(/?(?:p|ul|ol|li|h[1-6]|strong|em|code|a|br)\b[^&]*?)&gt;")
    md_hint = re.compile(r"^\s*(#|[-*]\s)|\n", re.M)

    def fix_notes(m):
        raw = html.unescape(m.group(2))
        if not md_hint.search(raw):
            return m.group(0)
        return m.group(1) + markdown_to_html(raw) + m.group(3)

    def fix_description(m):
        body = m.group(1)
        if escaped_tag.search(body):
            body = re.sub(r"<br>\s*", "\n                ", body)
            body = escaped_tag.sub(r"<\1>", body)
            body = body.replace("&amp;", "&amp;")
        elif not re.search(r"<(h[1-6]|p|ul|ol)\b", body, re.I):
            body = "\n                " + markdown_to_html(html.unescape(body).strip()) + "\n            "
        return "<description><![CDATA[" + notes_pat.sub(fix_notes, body) + "]]></description>"

    return re.sub(r"<description><!\[CDATA\[(.*?)\]\]></description>", fix_description, content, flags=re.DOTALL)


def parse_args():
    parser = argparse.ArgumentParser(description="Update appcast.xml for Sparkle")
    parser.add_argument("--appcast", default="appcast.xml", help="Path to appcast.xml")
    parser.add_argument("--version", help="Short version (e.g. 1.8.0)")
    parser.add_argument("--build", help="Build number (e.g. 38)")
    parser.add_argument("--signature", default="", help="Sparkle Ed25519 signature")
    parser.add_argument("--size", default="0", help="DMG file size in bytes")
    parser.add_argument("--url", help="DMG download URL")
    parser.add_argument("--rerender", action="store_true", help="Only convert existing Markdown notes to HTML")
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

    if args.rerender:
        with open(appcast_path, "r", encoding="utf-8") as f:
            old = f.read()
        new = rerender_existing(old)
        if not args.dry_run:
            with open(appcast_path, "w", encoding="utf-8") as f:
                f.write(new)
        print("[OK] Existing release notes re-rendered." if new != old else "[OK] Nothing to re-render.")
        return

    if not (args.version and args.build and args.url):
        print("[ERROR] --version, --build and --url are required.", file=sys.stderr)
        sys.exit(1)

    raw_notes = "Bug fixes and performance improvements."
    if args.notes_file and os.path.isfile(args.notes_file):
        with open(args.notes_file, "r", encoding="utf-8") as f:
            content = f.read().strip()
            if content:
                raw_notes = content
    elif args.notes:
        raw_notes = args.notes.strip()

    # The item already renders an <h3> title; drop a duplicate "## BreakMate vX" heading.
    raw_notes = re.sub(r"\A\s*#+\s*BreakMate v?[\d.]+\s*\n", "", raw_notes)
    notes_html = markdown_to_html(raw_notes)

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
                {notes_html}
                {INSTALL_NOTE}
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
