"""Generate a 1024x500 Play Store feature graphic for Movo."""

from PIL import Image, ImageDraw, ImageFont
import math, os

WIDTH, HEIGHT = 1024, 500
PURPLE = (108, 99, 255)
PINK = (255, 101, 132)
DARK = (26, 26, 46)
WHITE = (255, 255, 255)
LIGHT_PURPLE = (230, 227, 255)


def lerp_color(c1, c2, t):
    return (
        int(c1[0] + (c2[0] - c1[0]) * t),
        int(c1[1] + (c2[1] - c1[1]) * t),
        int(c1[2] + (c2[2] - c1[2]) * t),
    )


def draw_rounded_rect(draw, xy, radius, fill):
    x1, y1, x2, y2 = xy
    draw.rounded_rectangle(xy, radius=radius, fill=fill)


def find_font(size, weight="Regular"):
    """Try to find a nice font on the system, fall back to default."""
    candidates = [
        # Windows
        f"C:/Windows/Fonts/seguiemj.ttf",
        f"C:/Windows/Fonts/segoeui.ttf",
        f"C:/Windows/Fonts/segoeuib.ttf",
        f"C:/Windows/Fonts/segoeuil.ttf",
        f"C:/Windows/Fonts/arial.ttf",
        f"C:/Windows/Fonts/arialbd.ttf",
        f"C:/Windows/Fonts/calibri.ttf",
        f"C:/Windows/Fonts/calibrib.ttf",
        f"C:/Windows/Fonts/consola.ttf",
        # macOS
        "/System/Library/Fonts/SFNS.ttf",
        "/System/Library/Fonts/SFNSBold.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
        "/System/Library/Fonts/HelveticaNeue.ttc",
        # Linux
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    ]
    # Prefer Segoe UI on Windows
    win_fonts = {
        "Regular": "C:/Windows/Fonts/segoeui.ttf",
        "Bold": "C:/Windows/Fonts/segoeuib.ttf",
        "Light": "C:/Windows/Fonts/segoeuil.ttf",
    }
    if weight in win_fonts and os.path.exists(win_fonts[weight]):
        try:
            return ImageFont.truetype(win_fonts[weight], size)
        except Exception:
            pass

    for path in candidates:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except Exception:
                continue
    return ImageFont.load_default()


def draw_star(draw, cx, cy, r, fill):
    """Draw a 4-pointed sparkle star."""
    points = []
    for i in range(8):
        angle = math.pi / 4 * i - math.pi / 4
        radius = r if i % 2 == 0 else r * 0.3
        points.append((cx + radius * math.cos(angle), cy + radius * math.sin(angle)))
    draw.polygon(points, fill=fill)


def draw_heart(draw, cx, cy, size, fill):
    """Draw a heart centered at (cx, cy)."""
    r = size // 2
    left_lobe = (cx - r, cy - r, cx, cy + r)
    right_lobe = (cx, cy - r, cx + r, cy + r)
    draw.ellipse(left_lobe, fill=fill)
    draw.ellipse(right_lobe, fill=fill)
    draw.polygon(
        [
            (cx - r - r // 8, cy + r // 4),
            (cx + r + r // 8, cy + r // 4),
            (cx, cy + size * 7 // 10),
        ],
        fill=fill,
    )


def generate():
    img = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # --- Background gradient (left to right) ---
    for x in range(WIDTH):
        t = x / WIDTH
        r = int(PURPLE[0] + (PINK[0] - PURPLE[0]) * t)
        g = int(PURPLE[1] + (PINK[1] - PURPLE[1]) * t)
        b = int(PURPLE[2] + (PINK[2] - PURPLE[2]) * t)
        draw.line([(x, 0), (x, HEIGHT)], fill=(r, g, b))

    # --- Decorative circles (subtle) ---
    draw.ellipse(
        [(-100, -100), (200, 200)],
        fill=(255, 255, 255, 20),
    )
    draw.ellipse(
        [(WIDTH - 250, -80), (WIDTH + 50, 220)],
        fill=(255, 255, 255, 15),
    )
    draw.ellipse(
        [(-50, HEIGHT - 180), (180, HEIGHT + 50)],
        fill=(255, 255, 255, 18),
    )
    draw.ellipse(
        [(WIDTH - 180, HEIGHT - 120), (WIDTH + 30, HEIGHT + 40)],
        fill=(255, 255, 255, 12),
    )

    # --- Sparkle stars ---
    draw_star(draw, 120, 100, 12, (255, 255, 255, 100))
    draw_star(draw, 900, 110, 8, (255, 255, 255, 80))
    draw_star(draw, 850, 380, 10, (255, 255, 255, 90))
    draw_star(draw, 180, 420, 7, (255, 255, 255, 70))
    draw_star(draw, 500, 60, 6, (255, 255, 255, 60))

    # --- App icon placeholder (circle with "M") ---
    icon_cx, icon_cy = 160, 250
    icon_r = 65
    # White circle
    draw.ellipse(
        [icon_cx - icon_r, icon_cy - icon_r, icon_cx + icon_r, icon_cy + icon_r],
        fill=WHITE,
    )
    # "M" letter
    font_m = find_font(58, "Bold")
    bbox = draw.textbbox((0, 0), "M", font=font_m)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    # Draw M with purple-pink gradient
    for char in "M":
        char_bbox = draw.textbbox((0, 0), char, font=font_m)
        char_w = char_bbox[2] - char_bbox[0]
        char_x = icon_cx - char_w // 2
        char_y = icon_cy - th // 2 + 2
        # Draw M with purple color
        draw.text((char_x, char_y), char, fill=PURPLE, font=font_m)

    # --- "Movo" title ---
    font_title = find_font(72, "Bold")
    title = "Movo"
    bbox = draw.textbbox((0, 0), title, font=font_title)
    title_w = bbox[2] - bbox[0]
    title_x = icon_cx + icon_r + 30

    # Draw each character with a slight gradient
    total_w = 0
    char_widths = []
    for ch in title:
        cb = draw.textbbox((0, 0), ch, font=font_title)
        cw = cb[2] - cb[0]
        char_widths.append(cw)
        total_w += cw

    x_offset = title_x
    for i, ch in enumerate(title):
        t = i / (len(title) - 1) if len(title) > 1 else 0.5
        color = lerp_color(WHITE, LIGHT_PURPLE, t)
        draw.text((x_offset, icon_cy - 6), ch, fill=color, font=font_title)
        x_offset += char_widths[i] + 2

    # --- Tagline ---
    font_tagline = find_font(18, "Light")
    tagline = "Habit Tracker & Mood Journal"
    bbox = draw.textbbox((0, 0), tagline, font=font_tagline)
    tagline_w = bbox[2] - bbox[0]
    tagline_x = title_x
    draw.text(
        (tagline_x, icon_cy + 40),
        tagline,
        fill=(255, 255, 255, 210),
        font=font_tagline,
    )

    # --- Feature badges ---
    features = ["Track Habits", "Mood Journal", "No Account", "Privacy First"]
    badge_y = icon_cy + 75
    badge_r = 18

    total_badge_w = 0
    badge_gap = 12
    single_badge_w = 0
    for f in features:
        bbox = draw.textbbox((0, 0), f, font=find_font(13, "Regular"))
        fw = bbox[2] - bbox[0]
        single_badge_w = max(single_badge_w, fw)

    # Make badges a fixed width
    badge_pad_x = 16
    badge_pad_y = 6
    badge_h = 30
    badge_w = single_badge_w + badge_pad_x * 2

    total_badges_w = len(features) * badge_w + (len(features) - 1) * badge_gap
    badges_start_x = icon_cx + icon_r + 30

    for i, f in enumerate(features):
        bx = badges_start_x + i * (badge_w + badge_gap)
        by = badge_y

        # Badge background
        draw_rounded_rect(
            draw, (bx, by, bx + badge_w, by + badge_h), 15, (255, 255, 255, 35)
        )

        # Checkmark icon
        check_size = 8
        check_cx = bx + 20
        check_cy = by + badge_h // 2

        # Draw small checkmark
        draw.line(
            [
                (check_cx - 4, check_cy),
                (check_cx - 1, check_cy + 4),
                (check_cx + 5, check_cy - 3),
            ],
            fill=WHITE,
            width=2,
        )

        # Badge text
        bbox = draw.textbbox((0, 0), f, font=find_font(13, "Regular"))
        fw = bbox[2] - bbox[0]
        draw.text(
            (bx + 34, by + (badge_h - (bbox[3] - bbox[1])) // 2),
            f,
            fill=WHITE,
            font=find_font(13, "Regular"),
        )

    # --- Right side: decorative heart + checkmark (matching app icon) ---
    heart_cx, heart_cy = 820, 220
    draw_heart(draw, heart_cx, heart_cy, 55, (255, 255, 255, 35))

    # Small purple heart inside
    draw_heart(draw, heart_cx, heart_cy, 35, (255, 255, 255, 60))

    # Checkmark (large, subtle)
    chk_color = (255, 255, 255, 30)
    chk_pts = [(760, 240), (800, 280), (870, 200)]
    draw.line(chk_pts[:2], fill=chk_color, width=8)
    draw.line(chk_pts[1:], fill=chk_color, width=8)

    # --- Rating stars ---
    star_y = icon_cy + 115
    stars_text = "\u2605 \u2605 \u2605 \u2605 \u2605"
    font_stars = find_font(14, "Regular")
    draw.text(
        (title_x, star_y + 2),
        stars_text,
        fill=(255, 215, 0, 200),
        font=font_stars,
    )
    draw.text(
        (title_x + 110, star_y + 2),
        "Coming Soon",
        fill=(255, 255, 255, 150),
        font=find_font(12, "Light"),
    )

    # --- Bottom-right "Movo" watermark ---
    font_watermark = find_font(14, "Light")
    draw.text(
        (WIDTH - 150, HEIGHT - 30),
        "Movo \u00b7 Privacy First",
        fill=(255, 255, 255, 60),
        font=font_watermark,
    )

    # --- Save ---
    out_dir = "assets/feature_graphic"
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, "play_store_feature_graphic.png")
    img.save(out_path, "PNG", optimize=True)
    print(f"Saved: {out_path} ({WIDTH}x{HEIGHT})")


if __name__ == "__main__":
    import time

    t0 = time.time()
    generate()
    print(f"Done in {time.time() - t0:.1f}s")
