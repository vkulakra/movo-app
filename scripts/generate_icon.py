"""Generate a 1024x1024 app icon with transparent background."""

from PIL import Image, ImageDraw
import math, time

SIZE = 1024
PURPLE = (108, 99, 255)
PINK = (255, 101, 132)


def lerp_color(c1, c2, t):
    return (
        int(c1[0] + (c2[0] - c1[0]) * t),
        int(c1[1] + (c2[1] - c1[1]) * t),
        int(c1[2] + (c2[2] - c1[2]) * t),
        255,
    )


def make_icon():
    # Fully transparent canvas
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    cx, cy = SIZE // 2, SIZE // 2 - 8
    sw = 38

    def thick_line(d, p1, p2, w, col):
        x1, y1 = p1
        x2, y2 = p2
        l = math.hypot(x2 - x1, y2 - y1)
        steps = max(int(l), 1)
        for i in range(steps + 1):
            t = i / steps
            x = int(x1 + (x2 - x1) * t)
            y = int(y1 + (y2 - y1) * t)
            d.ellipse([x - w // 2, y - w // 2, x + w // 2, y + w // 2], fill=col)
        for p in (p1, p2):
            d.ellipse(
                [p[0] - w // 2, p[1] - w // 2, p[0] + w // 2, p[1] + w // 2], fill=col
            )

    def heart(d, cx_, cy_, s, col):
        r = s // 2
        d.ellipse([cx_ - s, cy_ - r, cx_, cy_ + r], fill=col)
        d.ellipse([cx_, cy_ - r, cx_ + s, cy_ + r], fill=col)
        d.polygon(
            [
                (cx_ - s - r // 6, cy_ + r // 5),
                (cx_ + s + r // 6, cy_ + r // 5),
                (cx_, cy_ + s * 14 // 10),
            ],
            fill=col,
        )

    # Checkmark: bottom-left -> middle -> heart (top-right)
    x1, y1 = cx - 72, cy + 12
    x2, y2 = cx - 20, cy + 64
    hx, hy = cx + 78, cy - 36
    hs = 28

    # Draw checkmark — gradient from purple to pink
    # First segment (bottom-left to middle)
    seg1_len = math.hypot(x2 - x1, y2 - y1)
    seg1_steps = max(int(seg1_len), 1)
    for i in range(seg1_steps + 1):
        t = i / seg1_steps
        x = int(x1 + (x2 - x1) * t)
        y = int(y1 + (y2 - y1) * t)
        color = lerp_color(PURPLE, lerp_color(PURPLE, PINK, 0.4), t)
        draw.ellipse([x - sw // 2, y - sw // 2, x + sw // 2, y + sw // 2], fill=color)
    for p in ((x1, y1), (x2, y2)):
        draw.ellipse(
            [p[0] - sw // 2, p[1] - sw // 2, p[0] + sw // 2, p[1] + sw // 2],
            fill=PURPLE if p == (x1, y1) else lerp_color(PURPLE, PINK, 0.4),
        )

    # Second segment (middle to heart) — more pink
    sw2 = int(sw * 0.9)
    seg2_len = math.hypot(hx - x2, hy - y2)
    seg2_steps = max(int(seg2_len), 1)
    for i in range(seg2_steps + 1):
        t = i / seg2_steps
        x = int(x2 + (hx - x2) * t)
        y = int(y2 + (hy - y2) * t)
        color = lerp_color(lerp_color(PURPLE, PINK, 0.4), PINK, t)
        draw.ellipse([x - sw2 // 2, y - sw2 // 2, x + sw2 // 2, y + sw2 // 2], fill=color)
    for p in ((x2, y2), (hx, hy)):
        draw.ellipse(
            [p[0] - sw2 // 2, p[1] - sw2 // 2, p[0] + sw2 // 2, p[1] + sw2 // 2],
            fill=lerp_color(PURPLE, PINK, 0.4) if p == (x2, y2) else PINK,
        )

    # Heart in pink
    heart(draw, hx, hy, hs, PINK)

    # Sparkle dots — semi-transparent purple
    for dx, dy, r in [(-100, -76, 5), (108, 68, 4), (-116, 84, 3)]:
        draw.ellipse(
            [cx + dx - r, cy + dy - r, cx + dx + r, cy + dy + r],
            fill=(*PURPLE, 160),
        )

    out = "assets/icon/app_icon.png"
    img.save(out, "PNG", optimize=True)
    print(f"Saved: {out} ({SIZE}x{SIZE})")


if __name__ == "__main__":
    t0 = time.time()
    make_icon()
    print(f"Done in {time.time() - t0:.1f}s")
