# -*- coding: utf-8 -*-
"""Regenerate achievement icon sheets with native transparent background.

Uses the OpenAI-compatible images/edits endpoint with:
  model=gpt-image-2.5-sunburst, background=transparent, output_format=png,
  size=2048x2048 (2K). The style reference (#1) is the original icon sheet.
Prompts follow the "subject-focused cutout" guideline: no scene, no shadows,
no "transparent background" wording (the API parameter handles it)."""
import argparse
import base64
import json
import os
import pathlib
import ssl
import sys
import time
import urllib.error
import urllib.request
import uuid

BASE = os.path.dirname(os.path.abspath(__file__))
REF = "C:/Users/Administrator/Downloads/original-52b79381e4caafd86dcd4021cc1f96f9.jpg"
MODEL = "gpt-image-2.5-sunburst"
SIZE = "2048x2048"
QUALITY = "medium"

SSL_CONTEXT = ssl.create_default_context()
SSL_CONTEXT.options |= getattr(ssl, "OP_IGNORE_UNEXPECTED_EOF", 0)
SSL_CONTEXT.check_hostname = False
SSL_CONTEXT.verify_mode = ssl.CERT_NONE

STYLE = ("Flat cartoon style icon set: {layout} evenly spaced on a fully transparent canvas. "
         "Each badge is a perfect smooth regular hexagon with a plain even solid white border, "
         "soft pastel gradient fill inside, bright cheerful colors, cute minimal vector "
         "illustration, sharp smooth clean edges, no torn paper texture, no rough edges, no "
         "speckles, no shadows, no reflections, no backdrop, no readable text or letters in any "
         "icon. The {count} badge subjects, in reading order, are: {subjects}.")

LAYOUT_3X3 = "9 hexagonal badges arranged in a 3x3 grid"
LAYOUT_7 = "7 hexagonal badges arranged as a top row of 3, a middle row of 3, and 1 centered badge on the bottom row"
LAYOUT_2X2 = "4 hexagonal badges arranged in a 2x2 grid"

SUBJECTS = {
    "sheet_01": (
        LAYOUT_3X3,
        ["a tall stack of overlapping chat bubbles in blue and purple",
         "a row of small retro TV screens in cyan",
         "colorful sticky label tags in candy colors",
         "chat bubbles floating up from a deep well in dark blue",
         "a person and a cute robot sitting face to face chatting in warm orange",
         "a retro telephone handset with sound waves in pink and purple",
         "a robotic arm holding a wrench in silver gray",
         "glowing golden chess pieces on a board",
         "an artist palette with stacked cards in multicolor"],
    ),
    "sheet_02": (
        LAYOUT_3X3,
        ["a photo wall grid with floating hearts in pink",
         "a cute robot holding a glowing letter in cyan blue",
         "a crystal ball containing a cute character silhouette in pink and blue",
         "a megaphone with a speech bubble in orange",
         "an open diary with a quill pen in warm yellow",
         "a calendar page with a row of green check marks in grass green",
         "an ink bottle with a thick manuscript in brown",
         "a stopwatch with a flowing timeline in sky blue",
         "an hourglass with sand flowing into a small river in amber"],
    ),
    "sheet_03": (
        LAYOUT_3X3,
        ["colorful luggage tags in rainbow colors",
         "a chain made of interlocking gears in steel blue",
         "a glowing branching skill tree in emerald green",
         "a cute juggler tossing colorful balls in orange red",
         "a card covered with red seal stamps in chinese red",
         "a golden star medal in shiny gold",
         "a bulletin board with pinned checklist papers in blue gray",
         "a checklist paper with big red check marks in white and red",
         "a warm sunset over a tidy empty desk in orange yellow"],
    ),
    "sheet_04": (
        LAYOUT_3X3,
        ["an arrow hitting the bullseye of a target in red and white",
         "flying sticky notes in bright yellow",
         "colorful folders arranged in a fan shape in multicolor",
         "a glowing tree-shaped network diagram in teal green",
         "a green check mark inside a closed ring in green",
         "a text formatting toolbar with a quill pen in violet",
         "a calendar page circled in red with a silk ribbon in rose red",
         "a flip countdown clock in black and gold",
         "a month calendar full of colorful event blocks in cheerful multi colors"],
    ),
    "sheet_05": (
        LAYOUT_3X3,
        ["a rocket launching with a small schedule chart in red and blue",
         "a wall of polaroid photos in retro white",
         "photo corners with colorful labels in macaron colors",
         "a twin-bell alarm clock in lake blue",
         "a clock face pointing straight up at twelve in white and gold",
         "an account book with an abacus in brown and gold",
         "a chain of linked gold coins in gold and green",
         "three stacked bank cards in blue and silver",
         "an open treasure chest with a grid of glowing items in game item style"],
    ),
    "sheet_06": (
        LAYOUT_3X3,
        ["warehouse shelves with cardboard boxes in gray and orange",
         "a magnifying glass inspecting a glowing item in blue purple",
         "a pile of gold coins with a small bucket in rich gold",
         "bulging shopping bags with a gift box in rose red and gold",
         "a stamp collection album with prize badges in kraft paper color",
         "a circle of cute people silhouettes in sky cyan",
         "a friendly handshake with speech bubbles in warm orange",
         "a butterfly resting on an address book in purple pink",
         "a red flag planted on a snowy mountain top at sunrise"],
    ),
    "sheet_07": (
        LAYOUT_3X3,
        ["a rising line chart with glowing dots in mint green",
         "a stack of three classic database cylinders in classic blue",
         "a glowing spreadsheet grid with flowing data streams in cyan",
         "an open toolbox with form input components in red and silver",
         "an hourglass with flowing golden sand in amber",
         "a cute person wearing headphones next to a clock in calm blue",
         "a big loudspeaker blowing sound waves in orange yellow",
         "three sound wave tracks in red blue and green",
         "a smartphone touching an NFC tag with signal ripples in tech blue"],
    ),
    "sheet_08": (
        LAYOUT_7,
        ["a blank tag card with a glowing writing pen in fluorescent green",
         "a globe with a surfboard in ocean blue",
         "an open book with small flag bookmarks in red",
         "stacked overlapping browser windows in gray blue",
         "a dark terminal window with abstract glowing green code symbols, symbols must be abstract dashes and dots",
         "a fountain pen with an unrolled paper scroll in blue and black",
         "a set of high speed rotating gears in steel gray"],
    ),
    "sheet_09": (
        LAYOUT_2X2,
        ["colorful puzzle pieces assembling into a circle in rainbow colors",
         "four colored light streams converging into a bright star in white and gold",
         "a row of burning torches in fire orange",
         "a royal crown trophy with confetti in purple and gold"],
    ),
}


def credentials():
    key = os.environ.get("IMAGEGEN_OPENAI_API_KEY")
    base = os.environ.get("IMAGEGEN_OPENAI_BASE_URL")
    if not key or not base:
        raise RuntimeError("Set IMAGEGEN_OPENAI_API_KEY and IMAGEGEN_OPENAI_BASE_URL.")
    return key, base


def request_json(url, headers, body):
    attempt = 0
    while True:
        req = urllib.request.Request(url, data=body, headers=headers, method="POST")
        try:
            with urllib.request.urlopen(req, timeout=300, context=SSL_CONTEXT) as resp:
                return json.loads(resp.read().decode("utf-8"))
        except urllib.error.HTTPError as exc:
            detail = exc.read().decode("utf-8", errors="replace")
            # 524: Cloudflare proxy gave up (origin >120s). Back off per retry_after and retry.
            if exc.code == 524 and attempt < 3:
                attempt += 1
                print("HTTP 524 (proxy timeout), backing off 125s (attempt {}/3)...".format(attempt), file=sys.stderr)
                time.sleep(125)
                continue
            if (exc.code >= 500 or exc.code == 429) and attempt < 2:
                attempt += 1
                print("HTTP {}, retrying...".format(exc.code), file=sys.stderr)
                time.sleep(5)
                continue
            raise RuntimeError("HTTP {}: {}".format(exc.code, detail))
        except (urllib.error.URLError, OSError) as exc:
            if attempt < 2:
                attempt += 1
                print("network error, retry...", file=sys.stderr)
                time.sleep(5)
                continue
            raise RuntimeError("network error: {}".format(exc))


def save_result(payload, out):
    items = payload.get("data") or []
    if not items:
        raise RuntimeError("response has no data[0]")
    item = items[0]
    if item.get("b64_json"):
        raw = base64.b64decode(item["b64_json"])
    else:
        req = urllib.request.Request(item["url"], headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=300, context=SSL_CONTEXT) as resp:
            raw = resp.read()
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(raw)


def gen_sheet(name, dry_run=False):
    layout, subjects = SUBJECTS[name]
    prompt = STYLE.format(layout=layout, count=len(subjects),
                          subjects="; ".join("{}.) {}".format(i + 1, s) for i, s in enumerate(subjects)))
    out = pathlib.Path(BASE) / (name + ".png")
    if dry_run:
        print("DRY {} -> {} model={} size={} background=transparent".format(name, out, MODEL, SIZE))
        return
    key, base = credentials()
    url = base.rstrip("/") + ("/v1" if not base.rstrip("/").endswith("/v1") else "") + "/images/generations"
    payload = {"model": MODEL, "prompt": prompt, "size": SIZE, "background": "transparent",
               "output_format": "png", "quality": QUALITY, "n": 1}
    result = request_json(url, {"User-Agent": "Mozilla/5.0", "Accept": "application/json",
                                "Authorization": "Bearer " + key, "Content-Type": "application/json"},
                          json.dumps(payload).encode())
    save_result(result, out)
    print("SAVED {}".format(out))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--sheet", default="all", help="sheet_01..sheet_09 or all")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    names = list(SUBJECTS) if args.sheet == "all" else [args.sheet]
    for n in names:
        gen_sheet(n, args.dry_run)


if __name__ == "__main__":
    main()
