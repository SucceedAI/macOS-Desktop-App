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


def shot1():
    img = base("mint")
    d = ImageDraw.Draw(img)
    title_block(
        d,
        "No context switching",
        "Type. Press Return. Keep writing.",
        "Turn a rough /ai command into finished text inside the app you are already using.",
        width=920,
    )
    command_editor(img, (220, 690, 1340, 1420), before=True)
    command_editor(img, (1510, 535, 2670, 1475), before=False)
    d.line((1390, 1010, 1490, 1010), fill=TEAL, width=12)
    d.polygon([(1490, 1010), (1448, 982), (1448, 1038)], fill=TEAL)
    save(img, "01-type-return-done-2880x1800.png")


def shot2():
    img = base("mint")
    d = ImageDraw.Draw(img)
    title_block(
        d,
        "Privacy first",
        "Private AI writing in every Mac app",
        "Succeed AI uses Apple’s local model directly in Mail, Notes, browsers, documents, and other editable fields.",
        width=950,
    )
    x = 174
    for label, col in [("Works offline", TEAL), ("No account", BLUE), ("No cloud", ORANGE)]:
        x = badge(d, (x, 655), label, col)
    book_cover(img, (2060, 302, 2680, 1328))
    command_editor(img, (840, 720, 1980, 1500), before=True)
    save(img, "02-private-ai-in-every-app-2880x1800.png")


def shot3():
    img = base("mint")
    d = ImageDraw.Draw(img)
    title_block(
        d,
        "One tap from the menu bar",
        "Select text. Choose an outcome. Stay in flow.",
        "Proofread, polish, change tone, reply, summarize, plan, or translate without writing a prompt or leaving the app you are using.",
        width=980,
    )
    menu_panel(img, (1390, 220, 2690, 1510))
    rounded_shadow(img, (226, 835, 1190, 1305), radius=46, fill=(255, 255, 255, 226))
    text(d, (302, 912), "No prompt to write", size=54, fill=INK, weight="heavy")
    paragraph(d, (306, 990), "Select existing text in Mail, Notes, a browser, or a document. SucceedAI steps aside while the local model works, then changes only the selection you left untouched.", 790, size=35)
    save(img, "03-menu-bar-control-center-2880x1800.png")


def shot4():
    img = base("mint")
    d = ImageDraw.Draw(img)
    title_block(
        d,
        "Private by architecture",
        "Your words never leave your Mac",
        "No cloud processing, prompt uploads, user account, API bill, analytics profile, or tracking SDK.",
        width=930,
    )
    privacy_panel(img, (1160, 292, 2585, 1430))
    save(img, "04-on-device-privacy-2880x1800.png")


def shot5():
    img = base("mint")
    d = ImageDraw.Draw(img)
    title_block(
        d,
        "Made to fit your flow",
        "Customize the trigger and launch behavior",
        "Keep the app quiet in the menu bar, choose your own command, and see exactly what macOS needs during setup.",
        width=900,
    )
    settings_window(img, (1190, 284, 2640, 1480))
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
