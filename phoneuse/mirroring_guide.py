"""A picture of how to start Screen Mirroring on the iPhone, in three steps, with this PC's
receiver name in the last one. Every shell shows it on the "Start Screen Mirroring" step:
the GTK window draws svg() itself, other shells load GET /api/mirroring-guide.svg?dark=1.
"""
from xml.sax.saxutils import escape

W, H = 540, 200


def glyph(x, y, s, fg, bg):
    """The Screen Mirroring symbol (two overlapping screens) in an s x s box at (x, y)."""
    k = s / 16
    return (f'<g transform="translate({x} {y}) scale({k})">'
            f'<rect x="5" y="1.5" width="9.5" height="7.5" rx="1.8" fill="none" stroke="{fg}" stroke-width="1.5"/>'
            f'<rect x="1.5" y="6.2" width="9.5" height="7.5" rx="1.8" fill="{fg}" stroke="{bg}" stroke-width="1.4"/>'
            '</g>')


def svg(name, dark=True):
    fg = "#f2f2f7" if dark else "#1c1c1e"
    dim = "#aeaeb2" if dark else "#636366"
    line = "#636366" if dark else "#aeaeb2"
    tile = "#3a3a3c" if dark else "#e5e5ea"
    accent = "#0a84ff" if dark else "#007aff"
    font = 'font-family="Inter, Cantarell, -apple-system, sans-serif"'
    n = escape(name)
    fit = ' textLength="94" lengthAdjust="spacingAndGlyphs"' if len(name) * 5.6 > 94 else ""  # fit the row

    def caption(cx, a, b, bold_b=False):
        w = ' font-weight="700"' if bold_b else ""
        return (f'<text x="{cx}" y="174" text-anchor="middle" font-size="12.5" fill="{dim}" {font}>{a}</text>'
                f'<text x="{cx}" y="191" text-anchor="middle" font-size="12.5" fill="{fg if bold_b else dim}"'
                f'{w} {font}>{b}</text>')

    tap = f'<circle r="9" fill="{accent}" opacity=".35"/><circle r="4.5" fill="{accent}"/>'
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">']

    # 1. The iPhone: swipe down from the top-right corner.
    parts += [
        f'<rect x="55" y="12" width="70" height="138" rx="15" fill="none" stroke="{line}" stroke-width="2.5"/>',
        f'<rect x="78" y="19" width="24" height="7" rx="3.5" fill="{line}"/>',  # the Dynamic Island
        f'<path d="M113 34v30" stroke="{accent}" stroke-width="2.5" stroke-linecap="round"/>',
        f'<path d="M107 58l6 7 6-7" fill="none" stroke="{accent}" stroke-width="2.5" stroke-linecap="round" '
        'stroke-linejoin="round"/>',
        f'<g transform="translate(113 30)">{tap}</g>',
        caption(90, "1. Swipe down from", "the top-right corner"),
    ]

    # 2. Control Center: the Screen Mirroring tile.
    parts += [
        f'<rect x="228" y="14" width="84" height="84" rx="20" fill="{tile}"/>',
        *(f'<circle cx="{cx}" cy="{cy}" r="12" fill="{line}" opacity=".7"/>'
          for cx in (251, 289) for cy in (37, 75)),
        f'<rect x="228" y="106" width="38" height="38" rx="11" fill="{tile}" stroke="{accent}" stroke-width="2.5"/>',
        glyph(236, 114, 22, fg, tile),
        f'<rect x="274" y="106" width="38" height="38" rx="11" fill="{tile}"/>',
        f'<g transform="translate(258 136)">{tap}</g>',
        caption(270, "2. Tap Screen", "Mirroring"),
    ]

    # 3. The list of receivers: this PC.
    parts += [
        f'<rect x="368" y="12" width="164" height="132" rx="18" fill="{tile}"/>',
        glyph(386, 24, 14, fg, tile),
        f'<text x="406" y="36" font-size="12.5" font-weight="700" fill="{fg}" {font}>Screen Mirroring</text>',
        f'<rect x="378" y="52" width="144" height="34" rx="10" fill="none" stroke="{accent}" stroke-width="2.5"/>',
        f'<rect x="388" y="62" width="17" height="12" rx="2.5" fill="none" stroke="{fg}" stroke-width="1.6"/>',
        f'<path d="M392 78h9" stroke="{fg}" stroke-width="1.6" stroke-linecap="round"/>',
        f'<text x="412" y="73" font-size="11" fill="{fg}" {font}{fit}>{n}</text>',
        f'<rect x="388" y="98" width="17" height="12" rx="2.5" fill="none" stroke="{line}" stroke-width="1.6"/>',
        f'<rect x="412" y="100" width="80" height="8" rx="4" fill="{line}" opacity=".6"/>',
        f'<rect x="388" y="120" width="17" height="12" rx="2.5" fill="none" stroke="{line}" stroke-width="1.6"/>',
        f'<rect x="412" y="122" width="60" height="8" rx="4" fill="{line}" opacity=".6"/>',
        caption(450, "3. Choose", n, bold_b=True),
        "</svg>",
    ]
    return "".join(parts)
