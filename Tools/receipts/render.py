#!/usr/bin/env python3
"""Render the receipt fixtures into PNG (and, for kind "pdf", a text PDF).

Usage: python3 Tools/receipts/render.py   (from anywhere; paths are repo-relative)
Output: TestData/Receipts/<name>.png and, for "pdf" fixtures, <name>.pdf
"""
import json, random, glob, os, re
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
FIXTURES = os.path.join(ROOT, "BifazKit/Tests/BifazReadingTests/Fixtures")
OUT = os.path.join(ROOT, "TestData/Receipts")
MONO = "/System/Library/Fonts/Menlo.ttc"
SANS = "/System/Library/Fonts/Helvetica.ttc"


def split_cols(line):
    """'LABEL  amount' -> (label, rest); the OCR joins columns with two spaces."""
    if "  " in line:
        a, b = line.split("  ", 1)
        return a, b
    return line, None


def render_ticket(lines, rng):
    font = ImageFont.truetype(MONO, 21)
    w, lh, pad = 600, 30, 36
    cw = font.getlength("M")
    cols = int((w - 2 * pad) / cw)
    rows = []
    for l in lines:
        a, b = split_cols(l)
        if b is None:
            rows.append(a.center(cols) if len(a) < cols and a.isupper() else a)
        else:
            gap = cols - len(a) - len(b)
            rows.append(a + " " * max(gap, 2) + b)
    h = pad * 2 + lh * len(rows)
    img = Image.new("L", (w, h), 250)
    d = ImageDraw.Draw(img)
    for i, r in enumerate(rows):
        d.text((pad, pad + i * lh), r, font=font, fill=35)
    # grey noise
    px = img.load()
    for _ in range(w * h // 18):
        x, y = rng.randrange(w), rng.randrange(h)
        px[x, y] = max(0, px[x, y] - rng.randrange(10, 60))
    img = img.filter(ImageFilter.GaussianBlur(0.5))
    img = img.rotate(rng.uniform(-1.5, 1.5), expand=True, fillcolor=255, resample=Image.BICUBIC)
    return img.convert("RGB")


def render_invoice(lines, rng):
    w, h = 1240, 1754  # A4 at 150 dpi
    img = Image.new("L", (w, h), 255)
    d = ImageDraw.Draw(img)
    f = ImageFont.truetype(SANS, 28)
    fb = ImageFont.truetype(SANS, 42)
    x0, x1, y = 110, w - 110, 120
    for i, l in enumerate(lines):
        a, b = split_cols(l)
        font = fb if i == 0 else f
        if b is None:
            d.text((x0, y), a, font=font, fill=20)
        else:
            d.text((x0, y), a, font=font, fill=20)
            d.text((x1 - d.textlength(b, font=f), y), b, font=f, fill=20)
        y += 62 if i == 0 else 46
    px = img.load()
    for _ in range(w * h // 60):
        px[rng.randrange(w), rng.randrange(h)] = rng.randrange(215, 245)
    img = img.rotate(rng.uniform(-0.6, 0.6), expand=False, fillcolor=255, resample=Image.BICUBIC)
    return img.convert("RGB")


def pdf_escape(s):
    return s.replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)")


def write_text_pdf(path, lines):
    """Minimal valid one-page PDF with real text in Helvetica (WinAnsi)."""
    ops = ["BT", "/F1 11 Tf", "14 TL", "56 790 Td"]
    for l in lines:
        a, b = split_cols(l)
        t = a if b is None else f"{a}    {b}"
        ops.append("(" + pdf_escape(t) + ") Tj T*")
    ops.append("ET")
    stream = "\n".join(ops).encode("cp1252", errors="replace")
    objs = [
        b"<< /Type /Catalog /Pages 2 0 R >>",
        b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
        b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Contents 4 0 R "
        b"/Resources << /Font << /F1 5 0 R >> >> >>",
        b"<< /Length %d >>\nstream\n" % len(stream) + stream + b"\nendstream",
        b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>",
    ]
    out = bytearray(b"%PDF-1.4\n")
    offsets = []
    for i, o in enumerate(objs, 1):
        offsets.append(len(out))
        out += b"%d 0 obj\n" % i + o + b"\nendobj\n"
    xref = len(out)
    out += b"xref\n0 %d\n0000000000 65535 f \n" % (len(objs) + 1)
    for off in offsets:
        out += b"%010d 00000 n \n" % off
    out += b"trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n" % (len(objs) + 1, xref)
    with open(path, "wb") as fh:
        fh.write(out)


def main():
    os.makedirs(OUT, exist_ok=True)
    for path in sorted(glob.glob(os.path.join(FIXTURES, "*.json"))):
        fx = json.load(open(path, encoding="utf-8"))
        rng = random.Random(fx["name"])  # deterministic
        if fx["name"].endswith("_ocr"):
            # The fixture simulates OCR mistakes; the image shows the clean print.
            fx["lines"] = [re.sub(r"(?<=[\d,%])O|O(?=[\d,%])", "0", l) for l in fx["lines"]]
        kind = fx["kind"]
        img = render_ticket(fx["lines"], rng) if kind == "ticket" else render_invoice(fx["lines"], rng)
        img.save(os.path.join(OUT, fx["name"] + ".png"))
        if kind == "pdf":
            write_text_pdf(os.path.join(OUT, fx["name"] + ".pdf"), fx["lines"])
        print("rendered", fx["name"], kind)


if __name__ == "__main__":
    main()
