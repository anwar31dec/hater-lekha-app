"""Extract glyph outlines from a TTF into a 100x100 box (matra top at y=20, baseline y=78)."""
import json, sys
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.boundsPen import BoundsPen

font_path, out_path, chars = sys.argv[1], sys.argv[2], sys.argv[3]
f = TTFont(font_path)
cmap = f.getBestCmap()
gs = f.getGlyphSet()
upem = f['head'].unitsPerEm

def bounds(gname):
    bp = BoundsPen(gs); gs[gname].draw(bp); return bp.bounds

# reference: top of ক = matra top -> y=20 ; baseline -> y=78
ref = cmap[ord('ক')]
_, _, _, ktop = bounds(ref)
scale = 58.0 / ktop
# Latin reference: cap height of H -> y=22..78
hb = bounds(cmap[ord('H')])
lat_scale = 56.0 / hb[3]

out = {}
for ch in chars:
    cp = ord(ch)
    if cp not in cmap:
        print('MISSING', ch, hex(cp)); continue
    g = cmap[cp]
    b = bounds(g)
    if b is None: print('EMPTY', ch); continue
    xmin, ymin, xmax, ymax = b
    is_latin = cp < 0x0980
    s = lat_scale if is_latin else scale
    w = (xmax - xmin) * s
    tx = 50 - (xmin * s) - w / 2
    ty = 78
    # y flips: y_box = 78 - y*s
    pen = SVGPathPen(gs)
    tp = TransformPen(pen, (s, 0, 0, -s, tx, ty))
    gs[g].draw(tp)
    out[ch] = {"d": pen.getCommands(), "w": round(w, 2),
               "top": round(78 - ymax * s, 2), "bottom": round(78 - ymin * s, 2)}
json.dump(out, open(out_path, 'w'), ensure_ascii=False, indent=0)
print('wrote', len(out), 'glyphs; scale', scale, 'lat', lat_scale)
