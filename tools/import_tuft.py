#!/usr/bin/env python3
"""Turn a supplied grass-tuft PNG into a Godot-ready alpha card.

    python3 tools/import_tuft.py <source.png> [dest.png]

Handles the two things generators get wrong:

* No alpha channel, with the "transparency checkerboard" drawn into the pixels
  (or a plain white/black backdrop). Keyed out by SATURATION: the backdrop is
  grey, grass is not.
* Backdrop bleeding into the antialiased blade edges. Removed by un-mixing
  against the measured backdrop colour, so no white or dark halo survives.

Then it crops to the artwork, keeps the aspect ratio (a tuft is taller than it
is wide) and resizes to 512 tall. Requires Pillow.
"""
import sys
from PIL import Image

SRC = sys.argv[1] if len(sys.argv) > 1 else "/tmp/tuft_source.png"
DST = sys.argv[2] if len(sys.argv) > 2 else "textures/grass_blade_tuft.png"
OUT_H = 512
SAT_LO, SAT_HI = 0.055, 0.16   # saturation ramp: below LO is backdrop
PAD = 6                        # pixels of margin kept around the artwork


def main() -> int:
    im = Image.open(SRC).convert("RGBA")
    w, h = im.size
    px = im.load()
    print(f"kaynak: {w}x{h} mod={Image.open(SRC).mode}")

    # Backdrop colour = average of the four corners (checker or flat, both work).
    corners = [px[0, 0], px[w - 1, 0], px[0, h - 1], px[w - 1, h - 1]]
    bg = tuple(sum(c[i] for c in corners) / 4.0 for i in range(3))
    print("olculen arka plan rengi: (%.0f, %.0f, %.0f)" % bg)

    out = Image.new("RGBA", (w, h))
    op = out.load()
    minx, miny, maxx, maxy = w, h, -1, -1
    keyed = 0

    for y in range(h):
        for x in range(w):
            r, g, b, _ = px[x, y]
            hi, lo = max(r, g, b), min(r, g, b)
            sat = (hi - lo) / 255.0
            if sat <= SAT_LO:
                a = 0.0
            elif sat >= SAT_HI:
                a = 1.0
            else:
                a = (sat - SAT_LO) / (SAT_HI - SAT_LO)
            if a <= 0.0:
                op[x, y] = (0, 0, 0, 0)
                keyed += 1
                continue
            # Un-mix the backdrop out of partially covered edge pixels.
            if a < 0.999:
                r = (r - (1.0 - a) * bg[0]) / a
                g = (g - (1.0 - a) * bg[1]) / a
                b = (b - (1.0 - a) * bg[2]) / a
            op[x, y] = (
                int(max(0.0, min(255.0, r))),
                int(max(0.0, min(255.0, g))),
                int(max(0.0, min(255.0, b))),
                int(round(a * 255)),
            )
            if a > 0.25:
                minx, miny = min(minx, x), min(miny, y)
                maxx, maxy = max(maxx, x), max(maxy, y)

    print("arka plan olarak silinen piksel: %.1f%%" % (100.0 * keyed / (w * h)))
    if maxx < 0:
        print("HATA: hic cim pikseli bulunamadi")
        return 1

    # Crop to the artwork. The roots run off the bottom edge, so the bottom is
    # only padded if the artwork does not already touch it.
    left = max(0, minx - PAD)
    right = min(w, maxx + 1 + PAD)
    top = max(0, miny - PAD)
    bottom = min(h, maxy + 1 + PAD)
    out = out.crop((left, top, right, bottom))
    cw, ch = out.size
    print(f"kirpma: {cw}x{ch}  (en/boy = {cw / ch:.2f})")

    out_w = max(4, int(round(OUT_H * cw / ch / 4)) * 4)
    out = out.resize((out_w, OUT_H), Image.LANCZOS)
    out.save(DST)
    print(f"{DST} -> {out_w}x{OUT_H} kaydedildi")
    print(f"KART_ENBOY={out_w / OUT_H:.4f}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
