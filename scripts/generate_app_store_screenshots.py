#!/usr/bin/env python3
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import math

W, H = 2880, 1800
OUT = Path("AppStore/Screenshots/macOS")
OUT.mkdir(parents=True, exist_ok=True)
FONT = Path("/System/Library/Fonts/SFNS.ttf")
FONT_ROUNDED = Path("/System/Library/Fonts/SFNSRounded.ttf")
FONT_MONO = Path("/System/Library/Fonts/SFNSMono.ttf")
ICON = Path("Succeed AI/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png")

INK = (16, 35, 46, 255)
MUTED = (86, 108, 120, 255)
TEAL = (0, 176, 168, 255)
BLUE = (36, 118, 255, 255)
GREEN = (24, 164, 105, 255)
ORANGE = (230, 138, 36, 255)
WHITE = (255, 255, 255, 255)


def font(size, weight="regular", mono=False):
    path = FONT_MONO if mono else (FONT_ROUNDED if weight in {"bold", "heavy"} else FONT)
    return ImageFont.truetype(str(path), size=size)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3)) + (255,)


def gradient(size, c1, c2, c3=None):
    img = Image.new("RGBA", size)
    pix = img.load()
    for y in range(size[1]):
        for x in range(size[0]):
            t = (x / size[0] * 0.62) + (y / size[1] * 0.38)
            if c3 and t > 0.55:
                col = lerp(c2, c3, (t - 0.55) / 0.45)
            else:
                col = lerp(c1, c2, min(t / 0.55, 1))
            pix[x, y] = col
    return img


def draw_blob(img, xy, color, blur=90):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.ellipse(xy, fill=color)
    img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(blur)))


def rounded(draw, xy, radius, fill, outline=None, width=1):
    draw.rounded_rectangle(xy, radius=radius, fill=fill, outline=outline, width=width)


def shadowed_card(img, xy, radius=42, fill=(255, 255, 255, 225), shadow=(0, 72, 92, 36), blur=32, offset=(0, 22), outline=(255, 255, 255, 160)):
    x1, y1, x2, y2 = xy
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.rounded_rectangle((x1 + offset[0], y1 + offset[1], x2 + offset[0], y2 + offset[1]), radius=radius, fill=shadow)
    img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(blur)))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle(xy, radius=radius, fill=fill, outline=outline, width=2)


def text(draw, xy, value, size=54, fill=INK, weight="regular", mono=False, anchor=None):
    draw.text(xy, value, font=font(size, weight, mono), fill=fill, anchor=anchor)


def wrap(draw, value, max_width, size, weight="regular", mono=False):
    f = font(size, weight, mono)
    words = value.split()
    lines, line = [], ""
    for word in words:
        test = f"{line} {word}".strip()
        if draw.textbbox((0, 0), test, font=f)[2] <= max_width:
            line = test
        else:
            if line:
                lines.append(line)
            line = word
    if line:
        lines.append(line)
    return lines


def paragraph(draw, xy, value, max_width, size=40, fill=MUTED, leading=1.18, weight="regular"):
    x, y = xy
    for line in wrap(draw, value, max_width, size, weight=weight):
        text(draw, (x, y), line, size=size, fill=fill, weight=weight)
        y += int(size * leading)
    return y


def title_block(draw, kicker, title, subtitle):
    text(draw, (170, 165), kicker.upper(), size=30, fill=TEAL, weight="bold")
    y = 215
    lines = title.split("\n")
    if len(lines) == 1:
        lines = wrap(draw, title, 1180, 86, weight="heavy")
    for line in lines:
        text(draw, (170, y), line, size=86, fill=INK, weight="heavy")
        y += 98
    paragraph(draw, (174, y + 22), subtitle, 720, size=34, fill=MUTED)


def app_icon(size=96):
    if ICON.exists():
        im = Image.open(ICON).convert("RGBA").resize((size, size), Image.LANCZOS)
    else:
        im = Image.new("RGBA", (size, size), TEAL)
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size, size), radius=size // 5, fill=255)
    im.putalpha(mask)
    return im


def mac_window(img, xy, title="SucceedAI", fill=(250, 255, 253, 245)):
    x1, y1, x2, y2 = xy
    shadowed_card(img, xy, radius=34, fill=fill, shadow=(0, 48, 72, 46), blur=42, offset=(0, 28))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((x1, y1, x2, y1 + 82), radius=34, fill=(247, 251, 252, 245))
    d.rectangle((x1, y1 + 48, x2, y1 + 82), fill=(247, 251, 252, 245))
    for i, c in enumerate([(255, 95, 87, 255), (255, 189, 46, 255), (39, 201, 63, 255)]):
        d.ellipse((x1 + 34 + i * 34, y1 + 31, x1 + 52 + i * 34, y1 + 49), fill=c)
    text(d, ((x1 + x2) // 2, y1 + 43), title, size=26, fill=(85, 96, 104, 255), weight="bold", anchor="mm")


def menu_bar(img):
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((80, 58, W - 80, 128), radius=24, fill=(255, 255, 255, 150), outline=(255, 255, 255, 130), width=1)
    img.alpha_composite(app_icon(42), (118, 72))
    text(d, (176, 84), "SucceedAI", size=28, fill=INK, weight="bold")
    text(d, (W - 430, 84), "Wed 6 May  20:06", size=28, fill=(75, 90, 98, 255))
    d.ellipse((W - 140, 78, W - 110, 108), fill=TEAL)


def menu_panel(img, xy, configured=True, running=True):
    x1, y1, x2, y2 = xy
    d = ImageDraw.Draw(img)
    shadowed_card(img, xy, radius=42, fill=(255, 255, 255, 238), shadow=(0, 56, 72, 60), blur=42, offset=(0, 24))
    img.alpha_composite(app_icon(90), (x1 + 42, y1 + 42))
    text(d, (x1 + 154, y1 + 54), "SucceedAI", size=48, fill=INK, weight="heavy")
    text(d, (x1 + 154, y1 + 112), "Instant AI in any macOS text field", size=28, fill=MUTED)
    badge = "Live" if running else "Ready"
    bfill = (229, 250, 241, 255) if running else (229, 249, 248, 255)
    bcol = GREEN if running else TEAL
    d.rounded_rectangle((x2 - 160, y1 + 58, x2 - 62, y1 + 100), radius=20, fill=bfill)
    text(d, (x2 - 111, y1 + 79), badge, size=24, fill=bcol, weight="bold", anchor="mm")
    card_y = y1 + 170
    d.rounded_rectangle((x1 + 42, card_y, x2 - 42, card_y + 160), radius=28, fill=(238, 253, 250, 255), outline=(188, 236, 230, 255), width=2)
    text(d, (x1 + 78, card_y + 36), "Service running", size=34, fill=INK, weight="bold")
    paragraph(d, (x1 + 78, card_y + 84), "SucceedAI is listening for /ai commands across macOS.", x2 - x1 - 156, size=25)
    y = card_y + 205
    for n, row in enumerate([("1", "Open any app"), ("2", "Type /ai plus your task"), ("3", "Press Return")]):
        cy = y + n * 64
        d.ellipse((x1 + 50, cy, x1 + 90, cy + 40), fill=BLUE)
        text(d, (x1 + 70, cy + 21), row[0], size=22, fill=WHITE, weight="bold", anchor="mm")
        text(d, (x1 + 112, cy + 5), row[1], size=25, fill=INK, weight="bold")
    for i, label in enumerate(["Settings", "Support"]):
        bx = x1 + 42 + i * ((x2 - x1 - 104) // 2 + 20)
        by = min(y2 - 106, y1 + 610)
        bw = (x2 - x1 - 124) // 2
        d.rounded_rectangle((bx, by, bx + bw, by + 66), radius=20, fill=(245, 249, 250, 255), outline=(222, 233, 236, 255), width=2)
        text(d, (bx + bw // 2, by + 34), label, size=25, fill=INK, weight="bold", anchor="mm")


def prompt_window(img, xy, before=True):
    x1, y1, x2, y2 = xy
    d = ImageDraw.Draw(img)
    mac_window(img, xy, "Notes")
    text(d, (x1 + 76, y1 + 142), "Campaign brief", size=44, fill=INK, weight="bold")
    if before:
        body = "/ai turn this rough launch note into a crisp\ncustomer email"
        fill = (6, 118, 112, 255)
    else:
        body = "Subject: Your faster way to write on Mac\n\nHi team,\n\nSucceedAI helps you turn rough ideas into polished text without leaving the app you are already using. Type a short /ai command, press Return, and keep moving."
        fill = INK
    y = y1 + 230
    for line in body.split("\n"):
        if line:
            y = paragraph(d, (x1 + 76, y), line, x2 - x1 - 152, size=34, fill=fill if line.startswith("/ai") else INK, weight="regular")
        y += 18


def settings_window(img, xy):
    x1, y1, x2, y2 = xy
    d = ImageDraw.Draw(img)
    mac_window(img, xy, "SucceedAI Settings")
    img.alpha_composite(app_icon(110), (x1 + 70, y1 + 130))
    text(d, (x1 + 210, y1 + 132), "SucceedAI Settings", size=54, fill=INK, weight="heavy")
    paragraph(d, (x1 + 214, y1 + 205), "Tune the menu bar assistant for a fast, focused macOS workflow.", x2 - x1 - 290, size=30)
    cards = [
        ("Launch", "Start SucceedAI at login", GREEN),
        ("Command Trigger", "/ai  Example: rewrite this note more clearly", TEAL),
        ("macOS Permission", "Accessibility enables command detection and response insertion.", ORANGE),
    ]
    y = y1 + 335
    for title, desc, col in cards:
        d.rounded_rectangle((x1 + 70, y, x2 - 70, y + 145), radius=28, fill=(255, 255, 255, 232), outline=col[:3] + (55,), width=2)
        d.rounded_rectangle((x1 + 104, y + 34, x1 + 158, y + 88), radius=18, fill=col[:3] + (28,))
        d.ellipse((x1 + 120, y + 50, x1 + 142, y + 72), fill=col)
        text(d, (x1 + 185, y + 36), title, size=34, fill=INK, weight="bold")
        text(d, (x1 + 185, y + 86), desc, size=28, fill=MUTED, mono=title == "Command Trigger")
        y += 176


def feature_chips(d, x, y, items):
    for item, col in items:
        w = d.textbbox((0, 0), item, font=font(28, "bold"))[2] + 54
        d.rounded_rectangle((x, y, x + w, y + 56), radius=28, fill=(255, 255, 255, 205), outline=col[:3] + (95,), width=2)
        text(d, (x + 27, y + 16), item, size=28, fill=col, weight="bold")
        x += w + 18


def base():
    img = gradient((W, H), (235, 253, 249), (230, 243, 255), (255, 248, 236))
    draw_blob(img, (2050, -210, 2920, 640), (0, 190, 170, 60), 105)
    draw_blob(img, (-250, 1080, 720, 2100), (47, 120, 255, 42), 120)
    draw_blob(img, (1200, 1120, 2180, 2140), (255, 185, 75, 34), 140)
    menu_bar(img)
    return img


def save(img, name):
    path = OUT / name
    img.convert("RGB").save(path, quality=96)
    print(path)


def shot1():
    img = base(); d = ImageDraw.Draw(img)
    title_block(d, "Menu bar AI", "Instant AI anywhere\non your Mac", "Write, rewrite, summarize, and polish inside the app you are already using. No context switching, no extra window management.")
    feature_chips(d, 174, 630, [("Works in any text field", TEAL), ("Press Return to replace", BLUE)])
    prompt_window(img, (900, 500, 2210, 1400), before=True)
    menu_panel(img, (1820, 250, 2660, 1060), running=True)
    save(img, "01-instant-ai-anywhere-2880x1800.png")


def shot2():
    img = base(); d = ImageDraw.Draw(img)
    title_block(d, "Control center", "A calm home in your menu bar", "See service status, permission state, usage guidance, settings, support, and product news in one polished macOS panel.")
    menu_panel(img, (1440, 260, 2450, 1040), running=True)
    shadowed_card(img, (250, 760, 1180, 1290), radius=44, fill=(255, 255, 255, 226))
    text(d, (320, 835), "Built for focus", size=54, fill=INK, weight="heavy")
    paragraph(d, (324, 915), "SucceedAI stays out of the way until you need it, then gives you a direct path from rough thought to finished text.", 760, size=36)
    save(img, "02-menu-bar-control-center-2880x1800.png")


def shot3():
    img = base(); d = ImageDraw.Draw(img)
    title_block(d, "In-place writing", "Replace rough prompts with finished text", "Type a natural-language request, press Return, and SucceedAI replaces the command with the response directly in your active editor.")
    prompt_window(img, (250, 650, 1320, 1330), before=True)
    prompt_window(img, (1500, 550, 2640, 1430), before=False)
    d.line((1370, 980, 1470, 980), fill=TEAL, width=10)
    d.polygon([(1470, 980), (1438, 958), (1438, 1002)], fill=TEAL)
    save(img, "03-in-place-ai-rewrite-2880x1800.png")


def shot4():
    img = base(); d = ImageDraw.Draw(img)
    title_block(d, "macOS first", "Clear permissions. Minimal entitlements.", "SucceedAI asks for Accessibility only because macOS requires it to detect your /ai command and type the generated answer into the active app.")
    shadowed_card(img, (1160, 390, 2520, 1290), radius=52, fill=(255, 255, 255, 232))
    text(d, (1250, 500), "Privacy-conscious design", size=64, fill=INK, weight="heavy")
    rows = [("Accessibility", "Detect /ai commands and insert responses", ORANGE), ("Network Client", "Connect to the configured AI service", BLUE), ("Sandboxed", "Runs with a reduced App Store entitlement set", GREEN)]
    y = 635
    for title, detail, col in rows:
        d.rounded_rectangle((1250, y, 2425, y + 150), radius=30, fill=(248, 253, 252, 255), outline=col[:3] + (95,), width=2)
        d.ellipse((1298, y + 48, 1352, y + 102), fill=col)
        text(d, (1390, y + 38), title, size=38, fill=INK, weight="bold")
        text(d, (1390, y + 92), detail, size=30, fill=MUTED)
        y += 185
    save(img, "04-privacy-permissions-2880x1800.png")


def shot5():
    img = base(); d = ImageDraw.Draw(img)
    title_block(d, "Settings", "A friendlier setup\nexperience", "The redesigned settings panel explains the command trigger, launch behavior, macOS permission, and support path without burying users in defaults.")
    settings_window(img, (1220, 285, 2640, 1460))
    save(img, "05-settings-experience-2880x1800.png")


if __name__ == "__main__":
    for fn in [shot1, shot2, shot3, shot4, shot5]:
        fn()
