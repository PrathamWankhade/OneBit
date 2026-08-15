import os
import re
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# NOTE: Superseded by the PNG drop-in launcher icon. The Android launcher icon
# is now generated directly from assets/icons/OneBit.png (full-bleed bitmap,
# artwork untouched); the adaptive foreground/monochrome vector files this
# tool produced were removed. This script is kept for regenerating the legacy
# white-vector launcher from a black wordmark master, if ever needed again.
MASTER = os.path.join(ROOT, "assets", "icons", "onebit_logo_black.svg")
RES_DIR = os.path.join(ROOT, "android", "app", "src", "main", "res")

# True bounds of the white letter content in master SVG coords. The letter
# paths are authored so that (0,0) in path space is each glyph's left edge at
# its vertical centre, so the translate in the SVG marks the glyph's left
# edge / vertical centre, not its bounding-box centre. Content spans
# x [69.92, 722.72] and y [457.6, 697.6].
LOGO_W = 652.8
LOGO_H = 240.0
LOGO_OX = 69.92
LOGO_OY = 457.6
VIEWPORT = 108.0
SAFE = 60.0


def parse_transform(value):
    m = re.search(r"matrix\(([^)]+)\)", value or "")
    if m:
        parts = [float(p) for p in m.group(1).replace(" ", "").split(",")]
        return parts  # a, b, c, d, e, f
    m = re.search(r"translate\(([^)]+)\)", value or "")
    if m:
        x, y = (float(p) for p in m.group(1).split(","))
        return [1.0, 0.0, 0.0, 1.0, x, y]
    return [1.0, 0.0, 0.0, 1.0, 0.0, 0.0]


tree = ET.parse(MASTER)
root = tree.getroot()

paths = []
for el in root.iter():
    if el.tag != "{http://www.w3.org/2000/svg}path":
        continue
    style = el.get("style", "")
    if "fill:#000000" in style:
        continue
    stroke = "#ffffff" in style and "stroke:none" not in style
    stroke_width = None
    m = re.search(r"stroke-width:([0-9.]+)", style)
    if m:
        stroke_width = m.group(1)
    paths.append(
        {
            "d": el.get("d"),
            "fill": not ("fill:none" in style),
            "fill_rule": "evenodd" if "evenodd" in style else "nonzero",
            "stroke": stroke,
            "stroke_width": stroke_width,
            "matrix": parse_transform(el.get("transform")),
        }
    )

S = SAFE / LOGO_W
TX = (VIEWPORT - SAFE) / 2
TY = (VIEWPORT - LOGO_H * S) / 2


def fmt(value):
    return ("%.5f" % value).rstrip("0").rstrip(".")


def path_element(path):
    m = path["matrix"]
    sx = m[0] * S
    sy = m[3] * S
    txx = m[4] * S + TX - LOGO_OX * S
    tyy = m[5] * S + TY - LOGO_OY * S
    attrs = []
    if path["fill_rule"] == "evenodd":
        attrs.append('android:fillType="evenOdd"')
    if path["fill"]:
        attrs.append('android:fillColor="#FFFFFFFF"')
    else:
        attrs.append('android:fillColor="#00000000"')
    if path["stroke"]:
        attrs.append('android:strokeColor="#FFFFFFFF"')
        attrs.append('android:strokeWidth="%s"' % path["stroke_width"])
    attrs.append('android:pathData="%s"' % path["d"])
    group_open = (
        '    <group\n'
        '        android:translateX="%s"\n'
        '        android:translateY="%s"\n'
        '        android:scaleX="%s"\n'
        '        android:scaleY="%s">\n' % (fmt(txx), fmt(tyy), fmt(sx), fmt(sy))
    )
    body = "        <path\n" + "".join("            %s\n" % a for a in attrs if a) + "        />\n"
    return group_open + body + "    </group>"


vector_xml = (
    '<?xml version="1.0" encoding="utf-8"?>\n'
    '<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
    '    android:width="%ddp"\n'
    '    android:height="%ddp"\n'
    '    android:viewportWidth="%d"\n'
    '    android:viewportHeight="%d">\n'
    % (VIEWPORT, VIEWPORT, VIEWPORT, VIEWPORT)
    + "\n".join(path_element(p) for p in paths)
    + "</vector>\n"
)

drawable_dir = os.path.join(RES_DIR, "drawable")
for name in ("ic_launcher_foreground", "ic_launcher_monochrome"):
    with open(os.path.join(drawable_dir, name + ".xml"), "w", encoding="utf-8") as fh:
        fh.write(vector_xml)

print("regenerated from %s (%d logo paths, vector only)" % (os.path.basename(MASTER), len(paths)))
