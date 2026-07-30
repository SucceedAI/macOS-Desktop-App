#!/usr/bin/env python3
"""Create a use-case-led iPhone and iPad App Store screenshot campaign.

The source captures are kept separately from the generated Fastlane output so
the campaign can be regenerated without repeatedly compositing screenshots.
On the first run, the script preserves the existing raw captures automatically.
"""

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import shutil


ROOT = Path(__file__).resolve().parents[1]
RAW_DIR = ROOT / "AppStore/Screenshots/iOS/Raw"
OUT_DIR = ROOT / "fastlane/screenshots-ios/en-US"
ICON_PATH = ROOT / "iOS/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"

IPHONE_SIZE = (1320, 2868)
IPAD_SIZE = (2064, 2752)

FONT_REGULAR = Path("/System/Library/Fonts/SFNS.ttf")
FONT_ROUNDED = Path("/System/Library/Fonts/SFNSRounded.ttf")

INK = (10, 19, 42, 255)
INK_SOFT = (58, 68, 91, 255)
WHITE = (255, 255, 255, 255)
CYAN = (0, 198, 217, 255)
BLUE = (45, 113, 255, 255)
PURPLE = (104, 72, 255, 255)
PINK = (230, 76, 220, 255)
GREEN = (42, 202, 125, 255)

SOURCE_FILES = {
    "compose": "01-compose-1320x2868.png",
    "keyboard": "02-keyboard-1320x2868.png",
    "privacy": "03-privacy-1320x2868.png",
    "ipad": "01-compose-ipad-2064x2752.png",
}


def font(size, weight="regular"):
    path = FONT_ROUNDED if weight in {"bold", "heavy"} else FONT_REGULAR
    return ImageFont.truetype(str(path), size=size)


def text(draw, xy, value, size, fill, weight="regular", anchor=None):
    draw.text(xy, value, font=font(size, weight), fill=fill, anchor=anchor)


def wrapped_lines(draw, value, max_width, size, weight="regular"):
    selected_font = font(size, weight)
    lines = []
    for paragraph in value.splitlines():
        words = paragraph.split()
        line = ""
        for word in words:
            candidate = f"{line} {word}".strip()
            if draw.textbbox((0, 0), candidate, font=selected_font)[2] <= max_width:
                line = candidate
            else:
                if line:
                    lines.append(line)
                line = word
        if line:
            lines.append(line)
    return lines


def paragraph(draw, xy, value, max_width, size, fill, weight="regular", leading=1.15):
    x, y = xy
    for line in wrapped_lines(draw, value, max_width, size, weight):
        text(draw, (x, y), line, size, fill, weight)
        y += int(size * leading)
    return y


def linear_gradient(size, start, end):
    width, height = size
    strip = Image.new("RGBA", (1, height))
    pixels = strip.load()
    for y in range(height):
        amount = y / max(height - 1, 1)
        pixels[0, y] = tuple(
            int(start[index] + (end[index] - start[index]) * amount)
            for index in range(3)
        ) + (255,)
    return strip.resize((width, height))


def glow(image, box, color, blur=100):
    layer = Image.new("RGBA", image.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).ellipse(box, fill=color)
    image.alpha_composite(layer.filter(ImageFilter.GaussianBlur(blur)))


def campaign_background(size, theme="dark"):
    if theme == "dark":
        image = linear_gradient(size, (8, 15, 45), (34, 18, 83))
        glow(
            image,
            (size[0] * 0.48, -size[1] * 0.09, size[0] * 1.23, size[1] * 0.33),
            (48, 161, 255, 78),
            120,
        )
        glow(
            image,
            (-size[0] * 0.24, size[1] * 0.55, size[0] * 0.56, size[1] * 1.03),
            (215, 65, 255, 62),
            135,
        )
    elif theme == "cyan":
        image = linear_gradient(size, (235, 252, 255), (237, 237, 255))
        glow(
            image,
            (size[0] * 0.52, -size[1] * 0.08, size[0] * 1.18, size[1] * 0.32),
            (0, 188, 230, 48),
            120,
        )
        glow(
            image,
            (-size[0] * 0.25, size[1] * 0.55, size[0] * 0.56, size[1] * 1.04),
            (117, 72, 255, 48),
            135,
        )
    else:
        image = linear_gradient(size, (250, 248, 255), (237, 244, 255))
        glow(
            image,
            (size[0] * 0.52, -size[1] * 0.08, size[0] * 1.18, size[1] * 0.32),
            (164, 85, 255, 44),
            120,
        )
    return image


def app_icon(size):
    image = Image.open(ICON_PATH).convert("RGBA").resize((size, size), Image.Resampling.LANCZOS)
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size, size), radius=int(size * 0.23), fill=255)
    image.putalpha(mask)
    return image


def rounded_paste(canvas, source, box, radius, shadow=True, border=None):
    x1, y1, x2, y2 = [int(value) for value in box]
    width, height = x2 - x1, y2 - y1
    fitted = source.resize((width, height), Image.Resampling.LANCZOS)
    mask = Image.new("L", (width, height), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, width, height), radius=radius, fill=255)
    if shadow:
        shadow_layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
        shadow_draw = ImageDraw.Draw(shadow_layer)
        shadow_draw.rounded_rectangle(
            (x1, y1 + 34, x2, y2 + 34),
            radius=radius,
            fill=(4, 10, 35, 92),
        )
        canvas.alpha_composite(shadow_layer.filter(ImageFilter.GaussianBlur(42)))
    canvas.paste(fitted, (x1, y1), mask)
    if border:
        ImageDraw.Draw(canvas).rounded_rectangle(
            (x1, y1, x2, y2),
            radius=radius,
            outline=border,
            width=3,
        )


def crop_to_ratio(source, ratio, focus_y=0.5):
    width, height = source.size
    current_ratio = width / height
    if current_ratio > ratio:
        new_width = int(height * ratio)
        left = (width - new_width) // 2
        return source.crop((left, 0, left + new_width, height))
    new_height = int(width / ratio)
    top = int((height - new_height) * focus_y)
    top = max(0, min(top, height - new_height))
    return source.crop((0, top, width, top + new_height))


def pill(draw, xy, label, dark=True, accent=CYAN):
    x, y = xy
    selected_font = font(32, "bold")
    width = draw.textbbox((0, 0), label, font=selected_font)[2] + 58
    fill = (255, 255, 255, 30) if dark else (255, 255, 255, 205)
    outline = (255, 255, 255, 65) if dark else accent[:3] + (65,)
    draw.rounded_rectangle((x, y, x + width, y + 64), radius=32, fill=fill, outline=outline, width=2)
    text(draw, (x + 29, y + 15), label, 32, accent, "bold")


def header(canvas, kicker, title_value, subtitle, dark=True, compact=False):
    draw = ImageDraw.Draw(canvas)
    primary = WHITE if dark else INK
    secondary = (210, 221, 246, 255) if dark else INK_SOFT
    pill(draw, (88, 88), kicker.upper(), dark)
    title_size = 82 if compact else 92
    y = 184
    for line in wrapped_lines(draw, title_value, 1140, title_size, "heavy"):
        text(draw, (88, y), line, title_size, primary, "heavy")
        y += int(title_size * 1.02)
    paragraph(draw, (92, y + 16), subtitle, 1120, 39, secondary, leading=1.2)
    return y


def iphone_screen_frame(canvas, source, top=665, crop_focus=0.0, height=2190):
    x1, x2 = 116, 1204
    cropped = crop_to_ratio(source, (x2 - x1) / height, crop_focus)
    rounded_paste(
        canvas,
        cropped,
        (x1, top, x2, top + height),
        radius=74,
        border=(255, 255, 255, 95),
    )


def iphone_shot_write(sources):
    canvas = campaign_background(IPHONE_SIZE, "dark")
    header(
        canvas,
        "PRIVATE AI WRITING",
        "Write better.\nMove faster.",
        "Polish replies, plans and everyday writing without learning how to prompt.",
        dark=True,
        compact=True,
    )
    iphone_screen_frame(canvas, sources["compose"], top=735, crop_focus=0.05, height=2160)
    return canvas


def iphone_shot_keyboard(sources):
    canvas = campaign_background(IPHONE_SIZE, "cyan")
    header(
        canvas,
        "SUCCEEDAI KEYBOARD",
        "AI right where\nyou type.",
        "Run a writing command, keep the cursor in place, and undo whenever you need.",
        dark=False,
        compact=True,
    )
    iphone_screen_frame(canvas, sources["keyboard"], top=735, crop_focus=0.0, height=2160)
    return canvas


def iphone_shot_reply(sources):
    canvas = campaign_background(IPHONE_SIZE, "light")
    draw = ImageDraw.Draw(canvas)
    header(
        canvas,
        "A REPLY WORTH SENDING",
        "Rough draft in.\nClear reply out.",
        "Choose Polish and get a confident result while the original meaning stays intact.",
        dark=False,
        compact=True,
    )

    before_box = (84, 775, 1236, 1150)
    after_box = (84, 1215, 1236, 1680)
    for box, accent in [(before_box, (112, 121, 144, 255)), (after_box, PURPLE)]:
        shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
        shadow_draw = ImageDraw.Draw(shadow)
        shadow_draw.rounded_rectangle(
            (box[0], box[1] + 24, box[2], box[3] + 24),
            radius=44,
            fill=(23, 28, 62, 40),
        )
        canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(30)))
        draw.rounded_rectangle(box, radius=44, fill=WHITE, outline=accent[:3] + (65,), width=3)

    pill(draw, (124, 820), "ROUGH DRAFT", dark=False, accent=(104, 113, 135, 255))
    paragraph(
        draw,
        (124, 930),
        "hey jamie, thanks for waiting. we fixed it and your account should work now.",
        1060,
        43,
        INK_SOFT,
        leading=1.25,
    )
    pill(draw, (124, 1260), "POLISHED LOCALLY", dark=False, accent=PURPLE)
    paragraph(
        draw,
        (124, 1370),
        "Hi Jamie, thanks for your patience. We have fixed the issue, and your account is ready to use.",
        1060,
        46,
        INK,
        "bold",
        1.23,
    )

    draw.ellipse((566, 1124, 754, 1312), fill=PURPLE)
    text(draw, (660, 1218), "↓", 84, WHITE, "heavy", anchor="mm")

    ipad_crop = sources["ipad"].crop((50, 1080, 2014, 2240))
    rounded_paste(
        canvas,
        ipad_crop,
        (84, 1780, 1236, 2460),
        radius=46,
        border=(104, 72, 255, 70),
    )
    draw.rounded_rectangle(
        (228, 2510, 1092, 2604),
        radius=47,
        fill=(14, 24, 55, 238),
    )
    text(draw, (660, 2557), "Nothing leaves your device", 34, WHITE, "bold", anchor="mm")
    return canvas


def iphone_shot_privacy(sources):
    canvas = campaign_background(IPHONE_SIZE, "dark")
    header(
        canvas,
        "PRIVACY FIRST",
        "Your words\nstay yours.",
        "On-device processing. No account, no prompt uploads and no cloud history.",
        dark=True,
        compact=True,
    )
    iphone_screen_frame(canvas, sources["privacy"], top=735, crop_focus=0.0, height=2160)
    return canvas


def iphone_shot_outcomes(sources):
    canvas = campaign_background(IPHONE_SIZE, "cyan")
    header(
        canvas,
        "NO PROMPT ENGINEERING",
        "10 useful outcomes.\nOne simple choice.",
        "Proofread, shorten, reply, summarize, plan, translate and more in a tap.",
        dark=False,
        compact=True,
    )
    action_crop = sources["compose"].crop((50, 770, 1270, 2380))
    rounded_paste(
        canvas,
        action_crop,
        (84, 770, 1236, 2290),
        radius=58,
        border=(104, 72, 255, 70),
    )
    draw = ImageDraw.Draw(canvas)
    benefits = [
        ("10", "practical actions"),
        ("9", "languages"),
        ("0", "cloud uploads"),
    ]
    for index, (number, label) in enumerate(benefits):
        left = 84 + index * 392
        draw.rounded_rectangle(
            (left, 2380, left + 360, 2670),
            radius=42,
            fill=(255, 255, 255, 220),
            outline=(103, 72, 255, 60),
            width=2,
        )
        text(draw, (left + 180, 2476), number, 70, PURPLE, "heavy", anchor="mm")
        paragraph(draw, (left + 42, 2540), label, 276, 30, INK_SOFT, "bold", 1.05)
    return canvas


def ipad_header(canvas, kicker, title_value, subtitle, dark=True):
    draw = ImageDraw.Draw(canvas)
    primary = WHITE if dark else INK
    secondary = (210, 221, 246, 255) if dark else INK_SOFT
    pill(draw, (112, 88), kicker.upper(), dark)
    y = 188
    for line in wrapped_lines(draw, title_value, 1800, 98, "heavy"):
        text(draw, (112, y), line, 98, primary, "heavy")
        y += 102
    paragraph(draw, (118, y + 8), subtitle, 1740, 41, secondary, leading=1.18)


def ipad_screen_frame(canvas, source, top=590, focus_y=0.0, height=2210):
    x1, x2 = 112, 1952
    cropped = crop_to_ratio(source, (x2 - x1) / height, focus_y)
    rounded_paste(
        canvas,
        cropped,
        (x1, top, x2, top + height),
        radius=54,
        border=(255, 255, 255, 95),
    )


def ipad_shot_write(sources):
    canvas = campaign_background(IPAD_SIZE, "dark")
    ipad_header(
        canvas,
        "PRIVATE AI FOR IPAD",
        "A focused workspace for better writing.",
        "Choose the outcome, add your draft and keep every step on device.",
        dark=True,
    )
    ipad_screen_frame(canvas, sources["ipad"], top=610, height=2185)
    return canvas


def ipad_shot_outcomes(sources):
    canvas = campaign_background(IPAD_SIZE, "cyan")
    ipad_header(
        canvas,
        "TEN PRACTICAL OUTCOMES",
        "Go from intent to result in a tap.",
        "Proofread, polish, shorten, reply, summarize, plan, translate and more.",
        dark=False,
    )
    crop = sources["ipad"].crop((30, 590, 2034, 1930))
    rounded_paste(
        canvas,
        crop,
        (112, 650, 1952, 1880),
        radius=54,
        border=(104, 72, 255, 70),
    )
    draw = ImageDraw.Draw(canvas)
    cards = [
        ("POLISH", "Make a rough message clear and confident."),
        ("PLAN", "Turn loose notes into ordered next steps."),
        ("TRANSLATE", "Move between nine useful languages."),
    ]
    for index, (title_value, detail) in enumerate(cards):
        left = 112 + index * 620
        draw.rounded_rectangle(
            (left, 1990, left + 580, 2520),
            radius=48,
            fill=(255, 255, 255, 225),
            outline=(104, 72, 255, 58),
            width=3,
        )
        text(draw, (left + 54, 2050), title_value, 34, PURPLE, "bold")
        paragraph(draw, (left + 54, 2145), detail, 470, 44, INK, "bold", 1.2)
    return canvas


def ipad_shot_privacy(sources):
    canvas = campaign_background(IPAD_SIZE, "dark")
    draw = ImageDraw.Draw(canvas)
    ipad_header(
        canvas,
        "LOCAL BY DESIGN",
        "Powerful writing help. Private by default.",
        "Apple’s on-device model works without an account, backend or prompt history.",
        dark=True,
    )
    privacy_crop = sources["privacy"].crop((45, 390, 1275, 2460))
    rounded_paste(
        canvas,
        privacy_crop,
        (112, 650, 1030, 2400),
        radius=60,
        border=(255, 255, 255, 85),
    )
    statements = [
        ("NOTHING UPLOADED", "Prompts and results stay on your device.", CYAN),
        ("WORKS OFFLINE", "Keep writing after Apple Intelligence is ready.", BLUE),
        ("NO ACCOUNT", "No sign-up, subscription or tracking profile.", GREEN),
    ]
    for index, (title_value, detail, accent) in enumerate(statements):
        top = 710 + index * 465
        draw.rounded_rectangle(
            (1100, top, 1952, top + 390),
            radius=48,
            fill=(255, 255, 255, 24),
            outline=accent[:3] + (105,),
            width=3,
        )
        draw.ellipse((1154, top + 54, 1242, top + 142), fill=accent)
        text(draw, (1198, top + 98), "✓", 42, WHITE, "heavy", anchor="mm")
        text(draw, (1280, top + 62), title_value, 34, accent, "bold")
        paragraph(draw, (1154, top + 180), detail, 710, 43, WHITE, "bold", 1.2)
    text(draw, (1526, 2315), "Your words stay yours.", 48, WHITE, "heavy", anchor="mm")
    return canvas


def bootstrap_sources():
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    for filename in SOURCE_FILES.values():
        destination = RAW_DIR / filename
        if destination.exists():
            continue
        existing = OUT_DIR / filename
        if not existing.exists():
            raise FileNotFoundError(
                f"Missing raw source {filename}. Add the simulator capture to {RAW_DIR}."
            )
        shutil.copy2(existing, destination)


def load_sources():
    return {
        key: Image.open(RAW_DIR / filename).convert("RGBA")
        for key, filename in SOURCE_FILES.items()
    }


def save(image, filename):
    path = OUT_DIR / filename
    image.convert("RGB").save(path, format="PNG", optimize=True)
    print(path.relative_to(ROOT))


def main():
    bootstrap_sources()
    sources = load_sources()
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for existing in OUT_DIR.glob("*.png"):
        existing.unlink()

    iphone_campaign = [
        ("01-write-better-1320x2868.png", iphone_shot_write),
        ("02-ai-keyboard-1320x2868.png", iphone_shot_keyboard),
        ("03-polish-a-reply-1320x2868.png", iphone_shot_reply),
        ("04-private-by-design-1320x2868.png", iphone_shot_privacy),
        ("05-ten-useful-outcomes-1320x2868.png", iphone_shot_outcomes),
    ]
    ipad_campaign = [
        ("01-focused-writing-ipad-2064x2752.png", ipad_shot_write),
        ("02-useful-outcomes-ipad-2064x2752.png", ipad_shot_outcomes),
        ("03-private-local-ai-ipad-2064x2752.png", ipad_shot_privacy),
    ]

    for filename, renderer in iphone_campaign + ipad_campaign:
        save(renderer(sources), filename)


if __name__ == "__main__":
    main()
