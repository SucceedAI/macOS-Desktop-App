#!/usr/bin/env python3
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import math
import shutil

W, H = 2880, 1800
APPSTORE_OUT = Path("AppStore/Screenshots/macOS")
FASTLANE_OUT = Path("fastlane/screenshots/en-AU")
FONT = Path("/System/Library/Fonts/SFNS.ttf")
FONT_ROUNDED = Path("/System/Library/Fonts/SFNSRounded.ttf")
FONT_MONO = Path("/System/Library/Fonts/SFNSMono.ttf")
ICON = Path("Succeed AI/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png")

INK = (13, 28, 35, 255)
INK_2 = (31, 50, 58, 255)
MUTED = (83, 104, 113, 255)
SOFT = (247, 252, 250, 255)
TEAL = (95, 70, 238, 255)
BLUE = (0, 151, 255, 255)
GREEN = (24, 164, 105, 255)
ORANGE = (244, 116, 44, 255)
GOLD = (246, 178, 64, 255)
ROSE = (242, 82, 98, 255)
WHITE = (255, 255, 255, 255)


def ensure_dirs():
    for directory in [APPSTORE_OUT, FASTLANE_OUT]:
        directory.mkdir(parents=True, exist_ok=True)
        for existing in directory.glob("*.png"):
            existing.unlink()


def font(size, weight="regular", mono=False):
    if mono:
        path = FONT_MONO
    elif weight in {"bold", "heavy"}:
        path = FONT_ROUNDED
    else:
        path = FONT
    return ImageFont.truetype(str(path), size=size)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3)) + (255,)


def gradient(size, c1, c2, c3=None):
    img = Image.new("RGBA", size)
    pix = img.load()
    for y in range(size[1]):
        for x in range(size[0]):
            t = (x / size[0] * 0.58) + (y / size[1] * 0.42)
            if c3 and t > 0.55:
                col = lerp(c2, c3, min((t - 0.55) / 0.45, 1))
            else:
                col = lerp(c1, c2, min(t / 0.55, 1))
            pix[x, y] = col
    return img


def draw_blob(img, xy, color, blur=90):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.ellipse(xy, fill=color)
    img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(blur)))


def draw_grid(img, opacity=22):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for x in range(0, W, 96):
        d.line((x, 0, x, H), fill=(13, 28, 35, opacity), width=1)
    for y in range(0, H, 96):
        d.line((0, y, W, y), fill=(13, 28, 35, opacity), width=1)
    img.alpha_composite(layer)


def text(draw, xy, value, size=54, fill=INK, weight="regular", mono=False, anchor=None):
    draw.text(xy, value, font=font(size, weight, mono), fill=fill, anchor=anchor)


def wrap(draw, value, max_width, size, weight="regular", mono=False):
    f = font(size, weight, mono)
    lines = []
    for raw_line in value.split("\n"):
        words = raw_line.split()
        line = ""
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


def paragraph(draw, xy, value, max_width, size=40, fill=MUTED, leading=1.2, weight="regular"):
    x, y = xy
    for line in wrap(draw, value, max_width, size, weight=weight):
        text(draw, (x, y), line, size=size, fill=fill, weight=weight)
        y += int(size * leading)
    return y


def rounded_shadow(img, xy, radius=42, fill=(255, 255, 255, 235), shadow=(13, 44, 52, 42), blur=38, offset=(0, 24), outline=(255, 255, 255, 155)):
    x1, y1, x2, y2 = xy
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.rounded_rectangle((x1 + offset[0], y1 + offset[1], x2 + offset[0], y2 + offset[1]), radius=radius, fill=shadow)
    img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(blur)))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle(xy, radius=radius, fill=fill, outline=outline, width=2)


def app_icon(size=120):
    if ICON.exists():
        im = Image.open(ICON).convert("RGBA").resize((size, size), Image.LANCZOS)
    else:
        im = Image.new("RGBA", (size, size), TEAL)
        d = ImageDraw.Draw(im)
        text(d, (size // 2, size // 2), "S", size=size // 2, fill=WHITE, weight="heavy", anchor="mm")
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size, size), radius=size // 4, fill=255)
    im.putalpha(mask)
    return im


def badge(draw, xy, label, color=TEAL, fill_alpha=28):
    x, y = xy
    f = font(28, "bold")
    w = draw.textbbox((0, 0), label, font=f)[2] + 56
    draw.rounded_rectangle((x, y, x + w, y + 58), radius=29, fill=color, outline=color[:3] + (105,), width=2)
    text(draw, (x + 28, y + 15), label, size=28, fill=WHITE, weight="bold")
    return x + w + 18


def title_block(draw, kicker, title, subtitle, width=900, x=170, y=164, title_size=86):
    text(draw, (x, y), kicker.upper(), size=30, fill=TEAL, weight="bold")
    y += 54
    for line in wrap(draw, title, width, title_size, weight="heavy"):
        text(draw, (x, y), line, size=title_size, fill=INK, weight="heavy")
        y += int(title_size * 1.05)
    paragraph(draw, (x + 4, y + 22), subtitle, width - 70, size=34, fill=MUTED)


def mac_menu_bar(img):
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((76, 56, W - 76, 126), radius=26, fill=(255, 255, 255, 150), outline=(255, 255, 255, 135), width=1)
    img.alpha_composite(app_icon(42), (118, 70))
    text(d, (176, 84), "SucceedAI", size=28, fill=INK, weight="bold")
    for i, label in enumerate(["File", "Edit", "Window", "Help"]):
        text(d, (338 + i * 112, 86), label, size=25, fill=(72, 91, 100, 255))
    text(d, (W - 520, 84), "Fri 17 Jul  9:41", size=28, fill=(72, 91, 100, 255))
    d.rounded_rectangle((W - 192, 72, W - 112, 112), radius=20, fill=(229, 252, 248, 255), outline=(180, 232, 224, 255), width=1)
    d.ellipse((W - 166, 82, W - 142, 106), fill=TEAL)


def base(theme="mint"):
    if theme == "night":
        img = gradient((W, H), (19, 38, 48), (21, 83, 92), (255, 247, 222))
        draw_blob(img, (1870, -260, 2990, 820), (0, 214, 194, 82), 130)
        draw_blob(img, (-390, 1070, 790, 2180), (36, 104, 255, 48), 140)
        draw_grid(img, 12)
    else:
        img = gradient((W, H), (245, 247, 255), (229, 244, 255), (255, 239, 252))
        draw_blob(img, (2040, -250, 2990, 690), (129, 82, 255, 64), 125)
        draw_blob(img, (-310, 1040, 770, 2140), (0, 151, 255, 48), 125)
        draw_blob(img, (1180, 1110, 2220, 2180), (245, 96, 220, 32), 140)
        draw_grid(img, 18)
    mac_menu_bar(img)
    return img


def mac_window(img, xy, title="SucceedAI", fill=(252, 255, 253, 244)):
    x1, y1, x2, y2 = xy
    rounded_shadow(img, xy, radius=36, fill=fill, shadow=(0, 50, 70, 54), blur=44, offset=(0, 30))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((x1, y1, x2, y1 + 86), radius=36, fill=(248, 252, 252, 244))
    d.rectangle((x1, y1 + 50, x2, y1 + 86), fill=(248, 252, 252, 244))
    for i, c in enumerate([(255, 95, 87, 255), (255, 189, 46, 255), (39, 201, 63, 255)]):
        d.ellipse((x1 + 34 + i * 36, y1 + 32, x1 + 54 + i * 36, y1 + 52), fill=c)
    text(d, ((x1 + x2) // 2, y1 + 44), title, size=26, fill=(82, 96, 104, 255), weight="bold", anchor="mm")


def command_editor(img, xy, before=True):
    x1, y1, x2, y2 = xy
    d = ImageDraw.Draw(img)
    mac_window(img, xy, "Mail")
    text(d, (x1 + 74, y1 + 142), "New customer reply", size=44, fill=INK, weight="heavy")
    d.rounded_rectangle((x1 + 72, y1 + 220, x2 - 72, y1 + 580), radius=28, fill=(255, 255, 255, 218), outline=(224, 236, 238, 255), width=2)
    if before:
        lines = [
            "/ai rewrite this reply so it sounds clear, warm,",
            "and confident:",
            "",
            "thanks for waiting. we fixed it and you can try again",
        ]
        colors = [TEAL, TEAL, INK, MUTED]
    else:
        lines = [
            "Thanks for your patience.",
            "",
            "We have fixed the issue on our side, so you can try again now. If anything still feels off, reply here and I will take another look right away.",
        ]
        colors = [INK, INK, INK]
    y = y1 + 266
    for idx, line in enumerate(lines):
        if line:
            y = paragraph(d, (x1 + 112, y), line, x2 - x1 - 224, size=34, fill=colors[min(idx, len(colors) - 1)])
        y += 18


def menu_panel(img, xy):
    x1, y1, x2, y2 = xy
    d = ImageDraw.Draw(img)
    rounded_shadow(img, xy, radius=44, fill=(255, 255, 255, 240), shadow=(0, 50, 64, 66), blur=46, offset=(0, 26))
    img.alpha_composite(app_icon(92), (x1 + 44, y1 + 44))
    text(d, (x1 + 158, y1 + 56), "SucceedAI", size=48, fill=INK, weight="heavy")
    text(d, (x1 + 158, y1 + 114), "Private AI, right where you type", size=28, fill=MUTED)
    d.rounded_rectangle((x2 - 292, y1 + 60, x2 - 54, y1 + 104), radius=22, fill=(228, 251, 248, 255))
    text(d, (x2 - 173, y1 + 82), "PRIVACY FIRST", size=21, fill=BLUE, weight="bold", anchor="mm")

    ready_y = y1 + 176
    d.rounded_rectangle((x1 + 44, ready_y, x2 - 44, ready_y + 116), radius=28, fill=(244, 253, 248, 255), outline=GREEN[:3] + (80,), width=2)
    d.ellipse((x1 + 80, ready_y + 36, x1 + 124, ready_y + 80), fill=GREEN)
    text(d, (x1 + 152, ready_y + 24), "Ready in every app", size=32, fill=INK, weight="bold")
    text(d, (x1 + 152, ready_y + 69), "Select text, open SucceedAI, and choose an outcome.", size=25, fill=MUTED)

    card_y = ready_y + 146
    card_bottom = card_y + 590
    d.rounded_rectangle((x1 + 44, card_y, x2 - 44, card_bottom), radius=32, fill=(252, 248, 255, 255), outline=TEAL[:3] + (92,), width=3)
    text(d, (x1 + 82, card_y + 34), "Selection ready", size=34, fill=TEAL, weight="heavy")
    d.rounded_rectangle((x2 - 232, card_y + 24, x2 - 78, card_y + 66), radius=21, fill=(241, 232, 255, 255))
    text(d, (x2 - 155, card_y + 45), "ONE TAP", size=21, fill=TEAL, weight="bold", anchor="mm")

    selected_y = card_y + 94
    d.rounded_rectangle((x1 + 78, selected_y, x2 - 78, selected_y + 82), radius=20, fill=(246, 239, 252, 255))
    text(d, (x1 + 108, selected_y + 26), "thanks for waiting. we fixed it and you can try again", size=25, fill=INK_2)
    text(d, (x1 + 82, selected_y + 108), "Choose an outcome. Only this exact unchanged selection is replaced.", size=23, fill=MUTED)

    actions = [
        ("Check Before Sending", "✓"),
        ("Improve Clarity", "✓"),
        ("Make It Shorter", "↙"),
        ("Write a Reply", "↩"),
        ("Summarize It", "≡"),
        ("Find Next Steps", "☑"),
        ("Build a Plan", "1."),
        ("Set the Right Tone", "A"),
    ]
    action_top = selected_y + 158
    action_gap = 18
    action_width = (x2 - x1 - 174 - action_gap) // 2
    action_height = 54
    for index, (label, symbol) in enumerate(actions):
        column = index % 2
        row = index // 2
        left = x1 + 78 + column * (action_width + action_gap)
        top = action_top + row * (action_height + 10)
        d.rounded_rectangle((left, top, left + action_width, top + action_height), radius=18, fill=WHITE, outline=(221, 211, 236, 255), width=2)
        text(d, (left + 22, top + 12), symbol, size=24, fill=TEAL, weight="bold")
        text(d, (left + 62, top + 11), label, size=24, fill=INK_2, weight="bold")

    translate_y = action_top + 4 * (action_height + 10)
    d.rounded_rectangle((x1 + 78, translate_y, x2 - 78, translate_y + 54), radius=18, fill=(243, 237, 255, 255), outline=TEAL[:3] + (72,), width=2)
    text(d, ((x1 + x2) // 2, translate_y + 27), "Translate  ·  9 languages", size=24, fill=TEAL, weight="bold", anchor="mm")

    compose_y = card_bottom + 28
    d.rounded_rectangle((x1 + 44, compose_y, x2 - 44, compose_y + 116), radius=28, fill=(242, 249, 255, 255), outline=BLUE[:3] + (70,), width=2)
    text(d, (x1 + 82, compose_y + 20), "Finish a writing task", size=29, fill=INK, weight="bold")
    text(d, (x1 + 82, compose_y + 63), "Choose an outcome, paste the source, and let SucceedAI handle the prompt.", size=23, fill=MUTED)
    text(d, ((x1 + x2) // 2, compose_y + 154), "The panel steps aside while SucceedAI works locally.", size=22, fill=TEAL, weight="bold", anchor="mm")

    footer_y = y2 - 136
    d.rounded_rectangle((x1 + 44, footer_y, x2 - 44, y2 - 42), radius=26, fill=(242, 249, 255, 255), outline=BLUE[:3] + (65,), width=2)
    text(d, (x1 + 82, footer_y + 18), "Nothing uploaded", size=28, fill=INK, weight="bold")
    text(d, (x1 + 82, footer_y + 57), "Apple’s model runs here. No backend, account, API key, or prompt logs.", size=23, fill=MUTED)


def outcome_panel(img, xy):
    x1, y1, x2, y2 = xy
    d = ImageDraw.Draw(img)
    rounded_shadow(img, xy, radius=40, fill=(255, 255, 255, 248), shadow=(8, 23, 55, 72), blur=48, offset=(0, 28))

    img.alpha_composite(app_icon(82), (x1 + 44, y1 + 40))
    text(d, (x1 + 150, y1 + 44), "SucceedAI", size=43, fill=INK, weight="heavy")
    text(d, (x1 + 152, y1 + 96), "Private AI, right where you type", size=25, fill=MUTED)
    label_pill(d, (x2 - 244, y1 + 52), "PRIVACY FIRST", BLUE, (230, 250, 250, 255))

    ready_y = y1 + 154
    d.rounded_rectangle((x1 + 44, ready_y, x2 - 44, ready_y + 94), radius=25, fill=(242, 253, 247, 255), outline=GREEN[:3] + (86,), width=2)
    d.ellipse((x1 + 72, ready_y + 25, x1 + 116, ready_y + 69), fill=GREEN)
    text(d, (x1 + 144, ready_y + 19), "Ready in every app", size=29, fill=INK, weight="bold")
    text(d, (x1 + 144, ready_y + 56), "Choose an outcome for the selected text.", size=23, fill=MUTED)

    card_y = ready_y + 120
    card_bottom = y2 - 154
    d.rounded_rectangle((x1 + 44, card_y, x2 - 44, card_bottom), radius=30, fill=(252, 248, 255, 255), outline=TEAL[:3] + (98,), width=3)
    text(d, (x1 + 78, card_y + 28), "Selection ready", size=33, fill=TEAL, weight="heavy")
    label_pill(d, (x2 - 210, card_y + 22), "ONE TAP", TEAL)

    selected_y = card_y + 82
    d.rounded_rectangle((x1 + 76, selected_y, x2 - 76, selected_y + 78), radius=19, fill=(244, 237, 252, 255))
    text(d, (x1 + 104, selected_y + 25), "we can still ship Friday if the final copy arrives today", size=24, fill=INK_2)

    actions = [
        ("Check Before Sending", "✓"),
        ("Improve Clarity", "✓"),
        ("Make It Shorter", "↙"),
        ("Write a Reply", "↩"),
        ("Summarize It", "≡"),
        ("Find Next Steps", "☑"),
        ("Build a Plan", "1."),
        ("Set the Right Tone", "A"),
    ]
    action_top = selected_y + 110
    gap = 16
    action_width = (x2 - x1 - 168 - gap) // 2
    for index, (label, symbol) in enumerate(actions):
        column = index % 2
        row = index // 2
        left = x1 + 76 + column * (action_width + gap)
        top = action_top + row * 62
        d.rounded_rectangle((left, top, left + action_width, top + 52), radius=16, fill=WHITE, outline=(220, 210, 235, 255), width=2)
        text(d, (left + 19, top + 12), symbol, size=22, fill=TEAL, weight="bold")
        text(d, (left + 54, top + 11), label, size=22, fill=INK_2, weight="bold")

    translate_y = action_top + 4 * 62
    d.rounded_rectangle((x1 + 76, translate_y, x2 - 76, translate_y + 52), radius=17, fill=(242, 235, 255, 255), outline=TEAL[:3] + (75,), width=2)
    text(d, ((x1 + x2) // 2, translate_y + 26), "Translate  ·  9 languages", size=23, fill=TEAL, weight="bold", anchor="mm")

    safety_y = card_bottom - 116
    d.rounded_rectangle((x1 + 76, safety_y, x2 - 76, safety_y + 78), radius=20, fill=(245, 241, 255, 255), outline=TEAL[:3] + (52,), width=2)
    text(d, (x1 + 104, safety_y + 15), "Context-safe replacement", size=24, fill=INK, weight="bold")
    text(d, (x1 + 104, safety_y + 47), "Only the exact unchanged selection is replaced. Undo stays ready.", size=20, fill=MUTED)

    footer_y = y2 - 118
    d.rounded_rectangle((x1 + 44, footer_y, x2 - 44, y2 - 38), radius=24, fill=(239, 248, 255, 255), outline=BLUE[:3] + (62,), width=2)
    text(d, (x1 + 76, footer_y + 14), "Nothing uploaded", size=25, fill=INK, weight="bold")
    text(d, (x1 + 76, footer_y + 47), "Apple’s model runs on this Mac.", size=21, fill=MUTED)


def settings_window(img, xy):
    x1, y1, x2, y2 = xy
    d = ImageDraw.Draw(img)
    mac_window(img, xy, "Settings")
    img.alpha_composite(app_icon(106), (x1 + 74, y1 + 126))
    text(d, (x1 + 210, y1 + 130), "Settings", size=58, fill=INK, weight="heavy")
    paragraph(d, (x1 + 214, y1 + 202), "Model readiness, privacy, permissions, launch behavior, and your replacement trigger in one place.", x2 - x1 - 300, size=30)

    tab_y = y1 + 315
    d.rounded_rectangle((x1 + 72, tab_y, x1 + 424, tab_y + 64), radius=26, fill=(229, 247, 244, 255))
    d.rounded_rectangle((x1 + 78, tab_y + 6, x1 + 248, tab_y + 58), radius=22, fill=WHITE)
    text(d, (x1 + 163, tab_y + 33), "General", size=25, fill=INK, weight="bold", anchor="mm")
    text(d, (x1 + 337, tab_y + 33), "Keys", size=25, fill=MUTED, weight="bold", anchor="mm")

    rows = [
        ("Launch at login", "Start automatically when your Mac starts.", GREEN, True),
        ("Local AI", "Ready. Processing stays on this Mac.", GREEN, True),
        ("Replacement trigger", "/ai  - customize in Settings > Trigger.", TEAL, False),
    ]
    y = y1 + 430
    for title, desc, col, checked in rows:
        d.rounded_rectangle((x1 + 72, y, x2 - 72, y + 150), radius=30, fill=(255, 255, 255, 235), outline=col[:3] + (65,), width=2)
        d.rounded_rectangle((x1 + 108, y + 45, x1 + 166, y + 103), radius=18, fill=col[:3] + (32,))
        if checked:
            text(d, (x1 + 137, y + 75), "OK", size=21, fill=col, weight="heavy", anchor="mm")
        else:
            text(d, (x1 + 137, y + 75), "/", size=34, fill=col, weight="heavy", anchor="mm")
        text(d, (x1 + 196, y + 36), title, size=34, fill=INK, weight="bold")
        text(d, (x1 + 196, y + 86), desc, size=27, fill=MUTED, mono=title == "Replacement trigger")
        y += 178


def permission_dialog(img, xy):
    x1, y1, x2, y2 = xy
    d = ImageDraw.Draw(img)
    rounded_shadow(img, xy, radius=54, fill=(255, 255, 255, 244), shadow=(0, 42, 62, 58), blur=48, offset=(0, 30))
    img.alpha_composite(app_icon(128), ((x1 + x2) // 2 - 64, y1 + 78))
    text(d, ((x1 + x2) // 2, y1 + 250), "Authorize SucceedAI", size=58, fill=INK, weight="heavy", anchor="mm")
    paragraph(d, (x1 + 130, y1 + 310), "Input Monitoring detects your trigger. Accessibility replaces the command in the active app. SucceedAI explains both before asking.", x2 - x1 - 260, size=32, fill=MUTED)
    steps = ["System Settings", "Privacy & Security", "Input Monitoring + Accessibility", "Enable SucceedAI in both"]
    y = y1 + 515
    center = (x1 + x2) // 2
    for idx, step in enumerate(steps):
        d.rounded_rectangle((center - 310, y, center + 310, y + 70), radius=35, fill=(236, 249, 247, 255), outline=(84, 185, 210, 255), width=3)
        text(d, (center, y + 36), step, size=30, fill=INK_2, weight="bold", anchor="mm")
        if idx < len(steps) - 1:
            d.line((center, y + 70, center, y + 118), fill=(84, 185, 210, 255), width=5)
            d.ellipse((center - 8, y + 92, center + 8, y + 108), fill=(84, 185, 210, 255))
        y += 118


def privacy_panel(img, xy):
    x1, y1, x2, y2 = xy
    d = ImageDraw.Draw(img)
    rounded_shadow(img, xy, radius=52, fill=(255, 255, 255, 242), shadow=(35, 26, 90, 58), blur=48, offset=(0, 30))
    img.alpha_composite(app_icon(132), (x1 + 72, y1 + 70))
    text(d, (x1 + 238, y1 + 82), "Local by design", size=56, fill=INK, weight="heavy")
    text(d, (x1 + 240, y1 + 148), "Your writing stays on your Mac.", size=30, fill=MUTED)

    rows = [
        ("Nothing uploaded", "No backend, API key, analytics, or prompt logs.", "cloud.slash", TEAL),
        ("Works offline", "Apple’s on-device model is ready without a connection.", "wifi.slash", BLUE),
        ("No account", "No sign-up, subscription, or license server.", "person.crop.circle.badge.xmark", GREEN),
    ]
    y = y1 + 255
    for title, detail, symbol, color in rows:
        d.rounded_rectangle((x1 + 70, y, x2 - 70, y + 150), radius=30, fill=(247, 248, 255, 255), outline=color[:3] + (72,), width=2)
        d.rounded_rectangle((x1 + 104, y + 42, x1 + 172, y + 110), radius=20, fill=color[:3] + (30,))
        text(d, (x1 + 138, y + 76), "✓", size=35, fill=color, weight="heavy", anchor="mm")
        text(d, (x1 + 206, y + 34), title, size=34, fill=INK, weight="bold")
        text(d, (x1 + 206, y + 86), detail, size=26, fill=MUTED)
        y += 180


def book_cover(img, xy):
    x1, y1, x2, y2 = xy
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.rounded_rectangle((x1 + 40, y1 + 54, x2 + 40, y2 + 54), radius=60, fill=(16, 48, 58, 52))
    img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(48)))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((x1, y1, x2, y2), radius=58, fill=(10, 43, 50, 255), outline=(255, 255, 255, 95), width=2)
    draw_blob(img, (x1 + 360, y1 - 190, x2 + 260, y1 + 680), (0, 210, 188, 75), 80)
    draw_blob(img, (x1 - 190, y2 - 620, x1 + 650, y2 + 220), (255, 173, 51, 54), 85)
    img.alpha_composite(app_icon(150), (x1 + 90, y1 + 92))
    text(d, (x1 + 90, y1 + 300), "AI writing", size=74, fill=WHITE, weight="heavy")
    text(d, (x1 + 90, y1 + 386), "that stays", size=74, fill=WHITE, weight="heavy")
    text(d, (x1 + 90, y1 + 472), "inside your", size=74, fill=WHITE, weight="heavy")
    text(d, (x1 + 90, y1 + 558), "flow.", size=74, fill=(165, 255, 244, 255), weight="heavy")
    paragraph(d, (x1 + 94, y2 - 220), "Type a command, press Return, and keep writing where the work already is.", x2 - x1 - 190, size=30, fill=(214, 237, 236, 255))


def campaign_base(theme="light"):
    if theme == "dark":
        img = gradient((W, H), (5, 12, 38), (10, 31, 83), (39, 18, 85))
        draw_blob(img, (1760, -430, 3220, 930), (119, 73, 255, 78), 150)
        draw_blob(img, (-420, 980, 940, 2250), (0, 190, 255, 48), 150)
    else:
        img = gradient((W, H), (246, 248, 252), (235, 241, 250), (246, 238, 253))
        draw_blob(img, (2050, -520, 3230, 650), (123, 85, 255, 34), 155)
        draw_blob(img, (-500, 1150, 820, 2300), (0, 174, 255, 28), 155)

    stripe = gradient((W, 18), (0, 191, 255), (93, 64, 255), (244, 77, 214))
    img.alpha_composite(stripe, (0, 0))
    return img


def campaign_header(draw, kicker, title, subtitle, dark=False):
    primary = WHITE if dark else INK
    secondary = (204, 214, 239, 255) if dark else MUTED
    accent = (92, 220, 255, 255) if dark else TEAL

    text(draw, (150, 92), kicker.upper(), size=29, fill=accent, weight="bold")
    y = 146
    for line in wrap(draw, title, 1800, 64, weight="heavy"):
        text(draw, (150, y), line, size=64, fill=primary, weight="heavy")
        y += 69

    paragraph(
        draw,
        (1960, 126),
        subtitle,
        760,
        size=31,
        fill=secondary,
        leading=1.24,
        weight="regular",
    )


def label_pill(draw, xy, label, color=TEAL, fill=(242, 238, 255, 255)):
    x, y = xy
    f = font(24, "bold")
    width = draw.textbbox((0, 0), label, font=f)[2] + 50
    draw.rounded_rectangle((x, y, x + width, y + 52), radius=26, fill=fill, outline=color[:3] + (78,), width=2)
    text(draw, (x + 25, y + 13), label, size=24, fill=color, weight="bold")
    return width


def result_check(draw, xy, label, detail, color=TEAL):
    x, y = xy
    draw.rounded_rectangle((x, y, x + 575, y + 104), radius=25, fill=(249, 250, 255, 255), outline=color[:3] + (58,), width=2)
    draw.ellipse((x + 25, y + 28, x + 73, y + 76), fill=color)
    text(draw, (x + 49, y + 52), "✓", size=27, fill=WHITE, weight="heavy", anchor="mm")
    text(draw, (x + 94, y + 21), label, size=28, fill=INK, weight="bold")
    text(draw, (x + 94, y + 60), detail, size=23, fill=MUTED)


def transformation_workspace(img, xy):
    x1, y1, x2, y2 = xy
    d = ImageDraw.Draw(img)
    mac_window(img, xy, "Mail · Customer Reply")

    toolbar_y = y1 + 86
    d.rectangle((x1, toolbar_y, x2, toolbar_y + 82), fill=(245, 247, 251, 255))
    for index, label in enumerate(["Send", "Attach", "Format"]):
        left = x1 + 44 + index * 126
        d.rounded_rectangle((left, toolbar_y + 17, left + 108, toolbar_y + 65), radius=17, fill=WHITE, outline=(217, 224, 232, 255), width=2)
        text(d, (left + 54, toolbar_y + 41), label, size=21, fill=INK_2, weight="bold", anchor="mm")
    text(d, (x2 - 54, toolbar_y + 41), "To: Jamie · Subject: Your account is ready", size=23, fill=MUTED, anchor="rm")

    content_y = toolbar_y + 116
    midpoint = (x1 + x2) // 2
    left_card = (x1 + 66, content_y, midpoint - 82, y2 - 72)
    right_card = (midpoint + 82, content_y, x2 - 66, y2 - 72)

    d.rounded_rectangle(left_card, radius=30, fill=(251, 252, 254, 255), outline=(216, 223, 232, 255), width=2)
    d.rounded_rectangle(right_card, radius=30, fill=(255, 255, 255, 255), outline=TEAL[:3] + (86,), width=3)
    label_pill(d, (left_card[0] + 38, left_card[1] + 34), "ROUGH DRAFT", MUTED, (239, 242, 246, 255))
    label_pill(d, (right_card[0] + 38, right_card[1] + 34), "READY TO SEND", TEAL)

    paragraph(
        d,
        (left_card[0] + 44, left_card[1] + 128),
        "/ai make this clear, warm and confident",
        left_card[2] - left_card[0] - 88,
        size=31,
        fill=TEAL,
        weight="bold",
    )
    paragraph(
        d,
        (left_card[0] + 44, left_card[1] + 250),
        "hey jamie, thanks for waiting. we fixed it and your account should work now. try again and tell us if it doesn't.",
        left_card[2] - left_card[0] - 88,
        size=35,
        fill=(68, 81, 91, 255),
        leading=1.38,
    )

    paragraph(
        d,
        (right_card[0] + 44, right_card[1] + 128),
        "Hi Jamie,",
        right_card[2] - right_card[0] - 88,
        size=35,
        fill=INK,
        weight="bold",
    )
    paragraph(
        d,
        (right_card[0] + 44, right_card[1] + 218),
        "Thanks for your patience. We have fixed the issue, and your account is ready to use.",
        right_card[2] - right_card[0] - 88,
        size=35,
        fill=INK_2,
        leading=1.38,
    )
    paragraph(
        d,
        (right_card[0] + 44, right_card[1] + 405),
        "Please try again. If anything still feels off, reply here and I will take another look right away.",
        right_card[2] - right_card[0] - 88,
        size=35,
        fill=INK_2,
        leading=1.38,
    )
    text(d, (right_card[0] + 44, right_card[3] - 104), "Best,\nAlex", size=31, fill=MUTED)

    d.ellipse((midpoint - 58, content_y + 320, midpoint + 58, content_y + 436), fill=TEAL)
    text(d, (midpoint, content_y + 378), "→", size=58, fill=WHITE, weight="heavy", anchor="mm")


def notes_to_plan_workspace(img, xy):
    x1, y1, x2, y2 = xy
    d = ImageDraw.Draw(img)
    mac_window(img, xy, "Notes · Product Launch")

    sidebar_w = 360
    d.rectangle((x1, y1 + 86, x1 + sidebar_w, y2), fill=(245, 246, 250, 255))
    text(d, (x1 + 42, y1 + 132), "Folders", size=26, fill=MUTED, weight="bold")
    folders = [("All iCloud", "18"), ("Work", "7"), ("Ideas", "11")]
    for index, (name, count) in enumerate(folders):
        top = y1 + 188 + index * 82
        selected = index == 1
        if selected:
            d.rounded_rectangle((x1 + 22, top - 12, x1 + sidebar_w - 22, top + 52), radius=18, fill=(233, 227, 255, 255))
        text(d, (x1 + 48, top), name, size=26, fill=TEAL if selected else INK_2, weight="bold" if selected else "regular")
        text(d, (x1 + sidebar_w - 52, top + 2), count, size=22, fill=MUTED, anchor="ra")

    content_x = x1 + sidebar_w
    midpoint = content_x + (x2 - content_x) // 2
    d.line((midpoint, y1 + 136, midpoint, y2 - 54), fill=(219, 224, 233, 255), width=2)

    text(d, (content_x + 60, y1 + 138), "Launch meeting notes", size=39, fill=INK, weight="heavy")
    text(d, (content_x + 62, y1 + 194), "Today, 10:30", size=23, fill=MUTED)
    rough_notes = [
        "launch maybe next Thursday",
        "Maya needs final screenshots",
        "pricing page still unfinished",
        "email customers before launch",
        "ask Sam about App Store copy",
        "support guide needs review",
    ]
    for index, note in enumerate(rough_notes):
        top = y1 + 280 + index * 105
        d.ellipse((content_x + 66, top + 12, content_x + 80, top + 26), fill=(133, 145, 155, 255))
        text(d, (content_x + 106, top), note, size=30, fill=(75, 86, 95, 255))

    label_pill(d, (midpoint + 52, y1 + 126), "SUCCEEDAI PLAN", TEAL)
    text(d, (midpoint + 54, y1 + 202), "Launch plan", size=43, fill=INK, weight="heavy")
    text(d, (midpoint + 56, y1 + 258), "Clear owners, priorities and next steps", size=25, fill=MUTED)

    tasks = [
        ("Today", "Maya · Export final App Store screenshots", True),
        ("Today", "Sam · Approve product page copy", True),
        ("Tomorrow", "Alex · Finish pricing page", False),
        ("Before launch", "Team · Review customer email", False),
        ("Before launch", "Support · Publish setup guide", False),
    ]
    for index, (when, task, done) in enumerate(tasks):
        top = y1 + 332 + index * 128
        d.rounded_rectangle((midpoint + 52, top, x2 - 54, top + 104), radius=24, fill=WHITE, outline=(220, 224, 236, 255), width=2)
        box_fill = GREEN if done else WHITE
        d.rounded_rectangle((midpoint + 78, top + 28, midpoint + 124, top + 74), radius=13, fill=box_fill, outline=GREEN, width=3)
        if done:
            text(d, (midpoint + 101, top + 51), "✓", size=26, fill=WHITE, weight="heavy", anchor="mm")
        text(d, (midpoint + 150, top + 20), when.upper(), size=19, fill=TEAL, weight="bold")
        text(d, (midpoint + 150, top + 53), task, size=27, fill=INK_2, weight="bold")

    d.rounded_rectangle((content_x + 58, y2 - 134, midpoint - 58, y2 - 60), radius=26, fill=(244, 239, 255, 255))
    text(d, ((content_x + midpoint) // 2, y2 - 97), "SucceedAI turns the selection into a plan", size=25, fill=TEAL, weight="bold", anchor="mm")


def selection_workspace(img, xy):
    x1, y1, x2, y2 = xy
    d = ImageDraw.Draw(img)
    mac_window(img, xy, "Mail · Inbox")

    sidebar = x1 + 410
    d.rectangle((x1, y1 + 86, sidebar, y2), fill=(242, 245, 249, 255))
    text(d, (x1 + 40, y1 + 136), "Mailboxes", size=25, fill=MUTED, weight="bold")
    for index, label in enumerate(["Inbox  12", "VIP", "Sent", "Drafts  3", "Archive"]):
        top = y1 + 202 + index * 74
        if index == 0:
            d.rounded_rectangle((x1 + 20, top - 12, sidebar - 22, top + 48), radius=18, fill=(230, 225, 255, 255))
        text(d, (x1 + 48, top), label, size=27, fill=TEAL if index == 0 else INK_2, weight="bold" if index == 0 else "regular")

    content_x = sidebar + 54
    text(d, (content_x, y1 + 142), "Re: Project timeline", size=42, fill=INK, weight="heavy")
    text(d, (content_x, y1 + 202), "From Jamie Chen · 9:17 AM", size=25, fill=MUTED)
    paragraph(d, (content_x, y1 + 286), "Hi team,\n\nCan you send a concise update on what is complete, what is blocked, and what you need from me before Friday?", 1020, size=34, fill=INK_2, leading=1.36)

    selected_top = y1 + 650
    d.rounded_rectangle((content_x - 12, selected_top - 18, content_x + 1040, selected_top + 174), radius=22, fill=(230, 222, 255, 255), outline=TEAL[:3] + (90,), width=2)
    paragraph(
        d,
        (content_x + 20, selected_top + 12),
        "we finished the prototype but onboarding is blocked because we need the final copy. i think we can still ship friday if it arrives today.",
        970,
        size=31,
        fill=INK,
        leading=1.35,
    )
    text(d, (content_x, selected_top + 226), "Selected text stays in place until you choose an outcome.", size=25, fill=MUTED)

    outcome_panel(img, (1510, y1 + 112, x2 - 48, y2 - 38))


def privacy_workspace(img, xy):
    x1, y1, x2, y2 = xy
    d = ImageDraw.Draw(img)
    rounded_shadow(img, xy, radius=42, fill=(10, 19, 48, 244), shadow=(0, 0, 0, 110), blur=56, offset=(0, 28), outline=(116, 135, 255, 80))

    img.alpha_composite(app_icon(128), (x1 + 72, y1 + 68))
    text(d, (x1 + 236, y1 + 78), "Private by architecture", size=52, fill=WHITE, weight="heavy")
    text(d, (x1 + 238, y1 + 144), "Local intelligence. No data pipeline.", size=29, fill=(181, 197, 228, 255))

    center_x = (x1 + x2) // 2
    source_x = x1 + 160
    model_x = center_x - 280
    cloud_x = x2 - 620
    card_y = y1 + 340
    card_w = 560
    card_h = 330

    for left, title, detail, color in [
        (source_x, "Your writing", "Mail, Notes, documents\nand browser text fields", BLUE),
        (model_x, "Apple local model", "Runs directly on your Mac\nwith Foundation Models", TEAL),
        (cloud_x, "The cloud", "No prompt upload\nNo account or API key", ROSE),
    ]:
        d.rounded_rectangle((left, card_y, left + card_w, card_y + card_h), radius=36, fill=(23, 36, 75, 255), outline=color[:3] + (115,), width=3)
        d.ellipse((left + 42, card_y + 42, left + 112, card_y + 112), fill=color)
        symbol = "✓" if title != "The cloud" else "×"
        text(d, (left + 77, card_y + 77), symbol, size=39, fill=WHITE, weight="heavy", anchor="mm")
        text(d, (left + 42, card_y + 148), title, size=38, fill=WHITE, weight="heavy")
        paragraph(d, (left + 42, card_y + 205), detail, card_w - 84, size=27, fill=(194, 206, 233, 255), leading=1.25)

    d.line((source_x + card_w, card_y + card_h // 2, model_x - 24, card_y + card_h // 2), fill=(92, 220, 255, 255), width=8)
    d.polygon([(model_x - 24, card_y + card_h // 2), (model_x - 58, card_y + card_h // 2 - 20), (model_x - 58, card_y + card_h // 2 + 20)], fill=(92, 220, 255, 255))
    d.line((model_x + card_w, card_y + card_h // 2, cloud_x - 32, card_y + card_h // 2), fill=(242, 82, 98, 255), width=7)
    text(d, ((model_x + card_w + cloud_x) // 2, card_y + card_h // 2 - 28), "NEVER SENT", size=22, fill=(255, 127, 143, 255), weight="bold", anchor="mm")
    d.line((cloud_x - 174, card_y + 80, cloud_x - 52, card_y + 250), fill=(255, 94, 119, 255), width=13)

    benefits_y = y1 + 810
    result_check(d, (x1 + 150, benefits_y), "Works offline", "No connection required", BLUE)
    result_check(d, (x1 + 765, benefits_y), "No prompt logs", "Nothing stored remotely", TEAL)
    result_check(d, (x1 + 1380, benefits_y), "No account", "Open the app and write", GREEN)
    result_check(d, (x1 + 1995, benefits_y), "No API bill", "No token fees or keys", ORANGE)

    text(d, (center_x, y2 - 92), "Your words stay yours.", size=39, fill=(169, 238, 255, 255), weight="heavy", anchor="mm")


def settings_showcase(img, xy):
    x1, y1, x2, y2 = xy
    d = ImageDraw.Draw(img)
    settings_window(img, (x1, y1, x2 - 740, y2))

    panel_x1 = x2 - 650
    rounded_shadow(img, (panel_x1, y1 + 36, x2, y2 - 36), radius=42, fill=(13, 23, 58, 248), shadow=(14, 18, 50, 80), blur=46, offset=(0, 28), outline=(118, 91, 255, 105))
    img.alpha_composite(app_icon(126), (panel_x1 + 58, y1 + 104))
    text(d, (panel_x1 + 58, y1 + 270), "Ready when you are", size=45, fill=WHITE, weight="heavy")
    paragraph(d, (panel_x1 + 60, y1 + 338), "Keep SucceedAI in the menu bar and use it wherever you write.", x2 - panel_x1 - 120, size=28, fill=(194, 207, 235, 255), leading=1.3)

    steps = [
        ("1", "Select text"),
        ("2", "Choose an outcome"),
        ("3", "Keep writing"),
    ]
    for index, (number, label) in enumerate(steps):
        top = y1 + 540 + index * 150
        d.ellipse((panel_x1 + 60, top, panel_x1 + 126, top + 66), fill=TEAL if index < 2 else BLUE)
        text(d, (panel_x1 + 93, top + 34), number, size=29, fill=WHITE, weight="heavy", anchor="mm")
        text(d, (panel_x1 + 154, top + 14), label, size=31, fill=WHITE, weight="bold")

    d.rounded_rectangle((panel_x1 + 58, y2 - 260, x2 - 58, y2 - 150), radius=30, fill=(33, 49, 93, 255), outline=(118, 201, 255, 100), width=2)
    text(d, ((panel_x1 + x2) // 2, y2 - 224), "PRIVACY FIRST", size=22, fill=(108, 222, 255, 255), weight="bold", anchor="mm")
    text(d, ((panel_x1 + x2) // 2, y2 - 184), "Nothing uploaded", size=29, fill=WHITE, weight="heavy", anchor="mm")


def shot1():
    img = campaign_base("light")
    d = ImageDraw.Draw(img)
    campaign_header(
        d,
        "AI writing assistant · built for macOS",
        "Turn rough thoughts into writing worth sending",
        "Rewrite, proofread and refine inside the Mac apps you already use.",
    )
    transformation_workspace(img, (150, 370, 2730, 1690))
    save(img, "01-type-return-done-2880x1800.png")


def shot2():
    img = campaign_base("light")
    d = ImageDraw.Draw(img)
    campaign_header(
        d,
        "From notes to next steps",
        "Turn meeting notes into a plan you can act on",
        "Find actions, assign owners and create structure without writing a complicated prompt.",
    )
    notes_to_plan_workspace(img, (150, 370, 2730, 1690))
    save(img, "02-private-ai-in-every-app-2880x1800.png")


def shot3():
    img = campaign_base("light")
    d = ImageDraw.Draw(img)
    campaign_header(
        d,
        "One selection · every writing task",
        "Proofread, rewrite and reply without leaving your app",
        "Choose a useful outcome from the menu bar. SucceedAI handles the prompt for you.",
    )
    selection_workspace(img, (150, 370, 2730, 1690))
    save(img, "03-menu-bar-control-center-2880x1800.png")


def shot4():
    img = campaign_base("dark")
    d = ImageDraw.Draw(img)
    campaign_header(
        d,
        "Privacy first · by design",
        "Private AI that never sends your words away",
        "Apple Foundation Models run on your Mac. No backend, prompt uploads, account or API key.",
        dark=True,
    )
    privacy_workspace(img, (150, 370, 2730, 1690))
    save(img, "04-on-device-privacy-2880x1800.png")


def shot5():
    img = campaign_base("light")
    d = ImageDraw.Draw(img)
    campaign_header(
        d,
        "Designed to disappear into your workflow",
        "Set it once. Use it everywhere you write.",
        "Choose your trigger, launch at login and keep practical local AI one selection away.",
    )
    settings_showcase(img, (150, 370, 2730, 1690))
    save(img, "05-customize-your-flow-2880x1800.png")


def save(img, filename):
    appstore_path = APPSTORE_OUT / filename
    fastlane_path = FASTLANE_OUT / filename.replace(".png", "_DESKTOP.png")
    rgb = img.convert("RGB")
    rgb.save(appstore_path, quality=96, optimize=True)
    shutil.copyfile(appstore_path, fastlane_path)
    print(appstore_path)
    print(fastlane_path)


if __name__ == "__main__":
    ensure_dirs()
    for fn in [shot1, shot2, shot3, shot4, shot5]:
        fn()
