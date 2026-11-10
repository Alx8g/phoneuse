"""A picture of how to start Screen Mirroring on the iPhone, in three steps, with this PC's
receiver name in the last one. Every shell shows it on the "Start Screen Mirroring" step:
the GTK window draws svg() itself, other shells load GET /api/mirroring-guide.svg?dark=1.

Layout: three 180-wide columns; each drawing fills the same 120-high box (y 8-128), and the
captions share two baselines under it.
"""
from xml.sax.saxutils import escape

W, H = 540, 172
TOP, BOX = 8, 120  # every drawing: y from TOP to TOP + BOX


def glyph(x, y, s, fg, bg):
    """The Screen Mirroring symbol in an s x s box at (x, y): as in Control Center, an outlined
    screen at the top left behind a solid one at the bottom right."""
    k = s / 16
    return (f'<g transform="translate({x} {y}) scale({k})">'
            f'<rect x="1.25" y="2" width="10" height="7.6" rx="1.8" fill="none" stroke="{fg}" stroke-width="1.5"/>'
            f'<rect x="4.75" y="6.4" width="10" height="7.6" rx="1.8" fill="{fg}" stroke="{bg}" stroke-width="1.5"/>'
            '</g>')


def fit(text, width, size, smallest, per_char):
    """(text, font size) that fits `width`: a smaller size first, then an ellipsis. Text widths are
    estimates (per_char x size per character), since renderers ignore textLength unevenly."""
    need = len(text) * per_char
    size = min(size, max(smallest, width / need)) if need else size
    keep = int(width / (per_char * size))
    return (text if len(text) <= keep else text[:keep - 1].rstrip() + "\u2026"), round(size, 1)


def svg(name, dark=True):
    fg = "#f2f2f7" if dark else "#1c1c1e"
    dim = "#aeaeb2" if dark else "#636366"
    line = "#636366" if dark else "#aeaeb2"
    tile = "#3a3a3c" if dark else "#e5e5ea"
    soft = "#48484a" if dark else "#d1d1d6"
    accent = "#0a84ff" if dark else "#007aff"
    font = 'font-family="Inter, Cantarell, -apple-system, sans-serif"'
    b = TOP + BOX
    row_name, row_size = fit(name, 100, 10.5, 7.5, 0.52)
    cap_name, cap_size = fit(name, 172, 12, 10, 0.56)

    def caption(cx, a, second, size=12, strong=False):
        w = f' font-weight="700" fill="{fg}"' if strong else f' fill="{dim}"'
        return (f'<text x="{cx}" y="{b + 24}" text-anchor="middle" font-size="12" fill="{dim}" {font}>{a}</text>'
                f'<text x="{cx}" y="{b + 40}" text-anchor="middle" font-size="{size}"{w} {font}>{second}</text>')

    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">']

    # 1. The iPhone, 60 x 120: swipe down from the top-right corner.
    parts += [
        f'<rect x="61" y="{TOP + 1}" width="58" height="{BOX - 2}" rx="13" fill="none" stroke="{line}" stroke-width="2"/>',
        f'<rect x="80" y="{TOP + 8}" width="20" height="6" rx="3" fill="{line}"/>',
        f'<circle cx="108" cy="{TOP + 12}" r="3.5" fill="{accent}"/>',
        f'<path d="M108 {TOP + 18}v26M103 {TOP + 39}l5 5 5-5" fill="none" stroke="{accent}" stroke-width="2" '
        'stroke-linecap="round" stroke-linejoin="round"/>',
        caption(90, "1. Swipe down from", "the top-right corner"),
    ]

    # 2. The Screen Mirroring button, as Control Center shows it.
    cy = TOP + BOX / 2
    parts += [
        f'<circle cx="270" cy="{cy}" r="32" fill="{tile}"/>',
        glyph(270 - 15, cy - 15, 30, fg, tile),
        caption(270, "2. Tap Screen", "Mirroring"),
    ]

    # 3. This PC, as the list of receivers names it.
    x0, w, h = 374, 152, 40
    parts += [
        f'<rect x="{x0}" y="{cy - h / 2}" width="{w}" height="{h}" rx="{h / 2}" fill="{tile}"/>',
        f'<rect x="{x0 + 15}" y="{cy - 6}" width="15" height="11" rx="2" fill="none" stroke="{fg}" stroke-width="1.5"/>',
        f'<path d="M{x0 + 19} {cy + 8.5}h7" stroke="{fg}" stroke-width="1.5" stroke-linecap="round"/>',
        f'<text x="{x0 + 38}" y="{cy + 3.5}" font-size="{row_size}" fill="{fg}" {font}>{escape(row_name)}</text>',
        caption(450, "3. Choose", escape(cap_name), cap_size, strong=True),
        "</svg>",
    ]
    return "".join(parts)
