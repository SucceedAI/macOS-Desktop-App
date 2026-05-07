#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageOps
import math
import os

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "ProductHunt"
GALLERY = OUT / "gallery"
SOCIAL = OUT / "social"
ICONS = OUT / "icons"
BRAND = OUT / "brand"
BANNERS = OUT / "banners"

SCREENSHOT_DIR = ROOT / "AppStore" / "Screenshots" / "macOS"
APP_ICON = ROOT / "Succeed AI" / "Assets.xcassets" / "AppIcon.appiconset" / "icon_512x512@2x.png"

SF = Path("/System/Library/Fonts/SFNS.ttf")
SF_ROUNDED = Path("/System/Library/Fonts/SFNSRounded.ttf")
SF_MONO = Path("/System/Library/Fonts/SFNSMono.ttf")
AVENIR = Path("/System/Library/Fonts/Avenir Next.ttc")

INK = (11, 30, 37)
MUTED = (73, 93, 101)
TEAL = (18, 191, 178)
BLUE = (34, 118, 255)
ORANGE = (255, 97, 53)
CREAM = (250, 247, 238)
WHITE = (255, 255, 255)
DARK = (5, 20, 25)

screens = {
    "hero": SCREENSHOT_DIR / "01-instant-ai-anywhere-2880x1800.png",
    "menu": SCREENSHOT_DIR / "02-menu-bar-control-center-2880x1800.png",
    "rewrite": SCREENSHOT_DIR / "03-in-place-ai-rewrite-2880x1800.png",
    "privacy": SCREENSHOT_DIR / "04-privacy-permissions-2880x1800.png",
    "settings": SCREENSHOT_DIR / "05-settings-experience-2880x1800.png",
}


def font(size: int, bold: bool = False, mono: bool = False):
    path = SF_MONO if mono else (SF_ROUNDED if SF_ROUNDED.exists() else SF)
    if AVENIR.exists() and bold:
        path = AVENIR
    return ImageFont.truetype(str(path), size=size)


def ensure_dirs():
    for d in [OUT, GALLERY, SOCIAL, ICONS, BRAND, BANNERS]:
        d.mkdir(parents=True, exist_ok=True)


def gradient(size, start, end, radial=None):
    w, h = size
    img = Image.new("RGB", size, start)
    pix = img.load()
    for y in range(h):
        for x in range(w):
            t = (x / max(1, w - 1) * 0.55) + (y / max(1, h - 1) * 0.45)
            c = tuple(int(start[i] * (1 - t) + end[i] * t) for i in range(3))
            pix[x, y] = c
    if radial:
        overlay = Image.new("RGBA", size, (0, 0, 0, 0))
        od = ImageDraw.Draw(overlay)
        for cx, cy, r, color, alpha in radial:
            for rr in range(r, 0, -8):
                a = int(alpha * (rr / r) ** 2)
                od.ellipse((cx - rr, cy - rr, cx + rr, cy + rr), fill=(*color, a))
        img = Image.alpha_composite(img.convert("RGBA"), overlay).convert("RGB")
    return img


def add_noise(img, opacity=10):
    w, h = img.size
    noise = Image.effect_noise((w, h), 24).convert("L")
    noise = ImageOps.colorize(noise, (0, 0, 0), (255, 255, 255)).convert("RGBA")
    noise.putalpha(opacity)
    return Image.alpha_composite(img.convert("RGBA"), noise).convert("RGB")


def rounded_rect_mask(size, radius):
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0], size[1]), radius=radius, fill=255)
    return mask


def paste_shadow(base, layer, xy, radius=22, opacity=90, offset=(0, 16)):
    shadow = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    alpha = layer.getchannel("A") if layer.mode == "RGBA" else Image.new("L", layer.size, 255)
    shadow.putalpha(alpha.point(lambda p: int(p * opacity / 255)))
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius))
    sx, sy = xy[0] + offset[0], xy[1] + offset[1]
    base.alpha_composite(shadow, (sx, sy))
    base.alpha_composite(layer, xy)


def fit_crop(img, box_size):
    return ImageOps.fit(img, box_size, method=Image.Resampling.LANCZOS, centering=(0.5, 0.5))


def fit_contain(img, box_size):
    im = img.copy()
    im.thumbnail(box_size, Image.Resampling.LANCZOS)
    return im


def screenshot_card(path, size, radius=30, chrome=True):
    src = Image.open(path).convert("RGB")
    shot = fit_crop(src, (size[0], size[1] - (38 if chrome else 0)))
    card = Image.new("RGBA", size, (255, 255, 255, 255))
    d = ImageDraw.Draw(card)
    if chrome:
        d.rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=(252, 253, 252), outline=(255, 255, 255, 160), width=2)
        d.rectangle((0, 38, size[0], size[1]), fill=(255, 255, 255))
        for i, c in enumerate([(255, 95, 86), (255, 189, 46), (40, 201, 64)]):
            d.ellipse((22 + i * 26, 13, 36 + i * 26, 27), fill=c)
        card.alpha_composite(shot.convert("RGBA"), (0, 38))
    else:
        card.alpha_composite(shot.convert("RGBA"), (0, 0))
    mask = rounded_rect_mask(size, radius)
    card.putalpha(mask)
    return card


def draw_text_box(draw, xy, text, fnt, fill, max_width, line_spacing=8):
    words = text.split()
    lines = []
    line = ""
    for word in words:
        candidate = word if not line else f"{line} {word}"
        if draw.textbbox((0, 0), candidate, font=fnt)[2] <= max_width:
            line = candidate
        else:
            if line:
                lines.append(line)
            line = word
    if line:
        lines.append(line)
    x, y = xy
    for line in lines:
        draw.text((x, y), line, font=fnt, fill=fill)
        y += draw.textbbox((0, 0), line, font=fnt)[3] + line_spacing
    return y


def pill(draw, xy, text, fill, fg=WHITE, icon=None):
    f = font(22, bold=True)
    x, y = xy
    tw = draw.textbbox((0, 0), text, font=f)[2]
    w, h = tw + 42, 44
    draw.rounded_rectangle((x, y, x + w, y + h), radius=22, fill=fill)
    draw.text((x + 21, y + 10), text, font=f, fill=fg)
    return w


def add_logo_lockup(base, xy, scale=1.0, light=False):
    icon = clean_app_icon((int(66 * scale), int(66 * scale)))
    base.alpha_composite(icon, xy)
    d = ImageDraw.Draw(base)
    x = xy[0] + int(80 * scale)
    y = xy[1] + int(9 * scale)
    d.text((x, y), "SucceedAI", font=font(int(32 * scale), bold=True), fill=WHITE if light else INK)
    d.text((x, y + int(36 * scale)), "AI text replacement for macOS", font=font(int(15 * scale)), fill=(210, 232, 229) if light else MUTED)


def gallery_canvas():
    bg = gradient((1270, 760), (246, 251, 246), (225, 246, 242), radial=[(1020, 120, 360, TEAL, 54), (240, 680, 320, ORANGE, 28), (1140, 700, 260, BLUE, 30)])
    return add_noise(bg, 8).convert("RGBA")


def build_gallery():
    items = [
        ("01-ai-command-anywhere-1270x760.jpg", "AI commands in any Mac app", "Type a trigger, describe the task, press Return. SucceedAI replaces the command in place.", screens["hero"], TEAL, "/ai"),
        ("02-rewrite-without-context-switching-1270x760.jpg", "Rewrite without switching apps", "Turn rough notes, emails, and messages into polished text exactly where you are working.", screens["rewrite"], BLUE, "/ai"),
        ("03-menu-bar-control-center-1270x760.jpg", "A calm menu bar control center", "Start the global assistant, confirm permissions, and open settings from one compact macOS panel.", screens["menu"], ORANGE, "/ai"),
        ("04-permissions-made-clear-1270x760.jpg", "Permissions users can understand", "First-run setup explains why Accessibility is needed and guides users to the right macOS setting.", screens["privacy"], TEAL, "/ai"),
        ("05-custom-replacement-trigger-1270x760.jpg", "Choose your own trigger", "Change the replacement shortcut from Settings > Keys and keep the preview in sync.", screens["settings"], BLUE, ";ai"),
    ]

    for i, (name, title, subtitle, shot_path, accent, trigger) in enumerate(items):
        canvas = gallery_canvas()
        d = ImageDraw.Draw(canvas)
        add_logo_lockup(canvas, (66, 54))
        pill(d, (66, 146), "Productivity for macOS", accent)
        y = draw_text_box(d, (66, 218), title, font(61, bold=True), INK, 440, 10)
        draw_text_box(d, (68, y + 16), subtitle, font(25), MUTED, 430, 8)
        d.rounded_rectangle((68, 625, 370, 681), radius=28, fill=(255, 255, 255, 210), outline=(255, 255, 255, 235), width=2)
        d.text((94, 641), f"Type  {trigger}  + Return", font=font(23, bold=True, mono=True), fill=INK)

        card = screenshot_card(shot_path, (700, 438), radius=34)
        angle = -2 if i % 2 == 0 else 2
        card = card.rotate(angle, expand=True, resample=Image.Resampling.BICUBIC)
        paste_shadow(canvas, card, (510, 176), radius=28, opacity=88, offset=(0, 20))

        # Foreground command chip for depth.
        chip = Image.new("RGBA", (420, 86), (0, 0, 0, 0))
        cd = ImageDraw.Draw(chip)
        cd.rounded_rectangle((0, 0, 420, 86), radius=28, fill=(255, 255, 255, 238), outline=(255, 255, 255, 255), width=2)
        cd.text((28, 18), trigger, font=font(28, bold=True, mono=True), fill=accent)
        cd.text((92, 20), "make this clearer", font=font(28, bold=True), fill=INK)
        paste_shadow(canvas, chip, (718, 614), radius=18, opacity=70, offset=(0, 10))
        save_asset(canvas.convert("RGB"), GALLERY / name, quality=92)

    # Sixth asset: compact feature grid, useful for gallery tail or social reuse.
    canvas = gradient((1270, 760), DARK, (13, 57, 57), radial=[(220, 160, 400, TEAL, 70), (1120, 120, 360, ORANGE, 58), (780, 720, 420, BLUE, 48)]).convert("RGBA")
    canvas = add_noise(canvas.convert("RGB"), 10).convert("RGBA")
    d = ImageDraw.Draw(canvas)
    add_logo_lockup(canvas, (72, 60), light=True)
    draw_text_box(d, (74, 170), "Stop breaking flow to ask AI", font(66, bold=True), WHITE, 560, 10)
    draw_text_box(d, (78, 328), "SucceedAI brings rewrite, summarize, translate, and polish workflows into any editable macOS text field.", font(27), (205, 232, 229), 530, 8)
    features = [("Global trigger", "Works across apps"), ("In-place paste", "Keeps your cursor flow"), ("Native settings", "Custom replacement shortcut"), ("Clear setup", "Accessibility guided")]
    for idx, (h, body) in enumerate(features):
        x = 650 + (idx % 2) * 270
        y = 134 + (idx // 2) * 210
        d.rounded_rectangle((x, y, x + 238, y + 156), radius=28, fill=(255, 255, 255, 28), outline=(255, 255, 255, 50), width=2)
        d.ellipse((x + 26, y + 24, x + 64, y + 62), fill=(18, 191, 178, 230))
        d.text((x + 28, y + 84), h, font=font(25, bold=True), fill=WHITE)
        draw_text_box(d, (x + 28, y + 116), body, font(18), (190, 220, 216), 180, 4)
    save_asset(canvas.convert("RGB"), GALLERY / "06-flow-first-feature-grid-1270x760.jpg", quality=92)

    # Seventh asset: use-case story, useful when visitors swipe beyond core feature screens.
    canvas = gallery_canvas()
    d = ImageDraw.Draw(canvas)
    add_logo_lockup(canvas, (66, 54))
    pill(d, (66, 146), "Use cases", ORANGE)
    y = draw_text_box(d, (66, 218), "One command for everyday writing", font(58, bold=True), INK, 470, 10)
    draw_text_box(d, (68, y + 16), "Rewrite emails, summarize notes, draft replies, translate messages, and polish rough thoughts without opening another app.", font(25), MUTED, 460, 8)
    use_cases = [
        ("Email", "Rewrite this reply so it sounds warmer"),
        ("Notes", "Summarize these notes into action items"),
        ("Support", "Draft a helpful customer response"),
        ("Docs", "Turn this rough idea into release notes"),
    ]
    for idx, (title, body) in enumerate(use_cases):
        x = 580 + (idx % 2) * 300
        yy = 150 + (idx // 2) * 210
        d.rounded_rectangle((x, yy, x + 270, yy + 166), radius=28, fill=(255, 255, 255, 220), outline=(255, 255, 255, 240), width=2)
        d.text((x + 28, yy + 26), title, font=font(27, bold=True), fill=INK)
        draw_text_box(d, (x + 28, yy + 72), body, font(20), MUTED, 210, 4)
    save_asset(canvas.convert("RGB"), GALLERY / "07-use-cases-1270x760.jpg", quality=92)

    # Eighth asset: CTA slide for launches, decks, and email embeds.
    canvas = gradient((1270, 760), (248, 253, 247), (218, 244, 239), radial=[(1050, 120, 420, TEAL, 64), (140, 650, 350, ORANGE, 42), (700, 720, 300, BLUE, 28)]).convert("RGBA")
    canvas = add_noise(canvas.convert("RGB"), 8).convert("RGBA")
    d = ImageDraw.Draw(canvas)
    icon = clean_app_icon((178, 178))
    canvas.alpha_composite(icon, (546, 86))
    d.text((635, 310), "SucceedAI", font=font(58, bold=True), fill=INK, anchor="mm")
    draw_text_box(d, (337, 372), "AI text replacement for macOS. Write with AI in any app without the copy-paste loop.", font(31), MUTED, 600, 8)
    d.rounded_rectangle((410, 548, 860, 612), radius=32, fill=ORANGE)
    d.text((635, 566), "Find SucceedAI on Product Hunt", font=font(25, bold=True), fill=WHITE, anchor="ma")
    d.text((635, 654), "producthunt.com/products/succeed-ai", font=font(22, mono=True), fill=INK, anchor="ma")
    save_asset(canvas.convert("RGB"), GALLERY / "08-product-hunt-call-to-action-1270x760.jpg", quality=92)


def build_icon_assets():
    icon = clean_app_icon((1024, 1024))
    icon.save(ICONS / "product-hunt-icon-1024x1024.png", optimize=True)
    icon_240 = icon.resize((240, 240), Image.Resampling.LANCZOS)
    icon_240.save(ICONS / "product-hunt-icon-240x240.png", optimize=True)

    thumb = Image.new("RGBA", (240, 240), (246, 251, 246, 255))
    d = ImageDraw.Draw(thumb)
    for r, c, a in [(210, TEAL, 46), (150, ORANGE, 32), (120, BLUE, 28)]:
        overlay = Image.new("RGBA", (240, 240), (0, 0, 0, 0))
        od = ImageDraw.Draw(overlay)
        od.ellipse((120-r, 34-r, 120+r, 34+r), fill=(*c, a))
        thumb = Image.alpha_composite(thumb, overlay)
    icon_small = icon.resize((154, 154), Image.Resampling.LANCZOS)
    paste_shadow(thumb, icon_small, (43, 28), radius=12, opacity=50, offset=(0, 8))
    d = ImageDraw.Draw(thumb)
    d.text((38, 192), "SucceedAI", font=font(24, bold=True), fill=INK)
    thumb.convert("RGB").save(ICONS / "product-hunt-thumbnail-240x240.jpg", quality=94, optimize=True, progressive=True)


def clean_app_icon(size):
    source = Image.open(APP_ICON).convert("RGBA")
    return source.crop((128, 0, 896, 768)).resize(size, Image.Resampling.LANCZOS)


def social_canvas(size):
    bg = gradient(size, (245, 252, 247), (223, 246, 242), radial=[(int(size[0]*0.82), int(size[1]*0.18), int(size[0]*0.32), TEAL, 54), (int(size[0]*0.12), int(size[1]*0.88), int(size[0]*0.27), ORANGE, 30)]).convert("RGBA")
    return add_noise(bg.convert("RGB"), 8).convert("RGBA")


def build_social():
    specs = [
        ("product-hunt-og-1200x630.jpg", (1200, 630)),
        ("x-announcement-1600x900.jpg", (1600, 900)),
        ("linkedin-launch-1200x627.jpg", (1200, 627)),
    ]
    for name, size in specs:
        w, h = size
        canvas = social_canvas(size)
        d = ImageDraw.Draw(canvas)
        scale = w / 1270
        add_logo_lockup(canvas, (int(58*scale), int(48*scale)), scale=scale)
        title_size = int(62 * scale)
        body_size = int(25 * scale)
        y = draw_text_box(d, (int(62*scale), int(165*scale)), "Launch SucceedAI on Product Hunt", font(title_size, bold=True), INK, int(500*scale), int(10*scale))
        draw_text_box(d, (int(64*scale), y + int(18*scale)), "AI text replacement in any macOS app. No context switching, no copy-paste loop.", font(body_size), MUTED, int(500*scale), int(8*scale))
        d.rounded_rectangle((int(64*scale), int((h/scale - 112)*scale), int(430*scale), int((h/scale - 58)*scale)), radius=int(26*scale), fill=ORANGE)
        d.text((int(90*scale), int((h/scale - 98)*scale)), "Find us on Product Hunt", font=font(int(22*scale), bold=True), fill=WHITE)
        card = screenshot_card(screens["hero"], (int(610*scale), int(382*scale)), radius=int(30*scale))
        paste_shadow(canvas, card, (int(545*scale), int(150*scale)), radius=int(26*scale), opacity=90, offset=(0, int(18*scale)))
        save_asset(canvas.convert("RGB"), SOCIAL / name, quality=92)

    # Email header has less text and stronger logo presence.
    canvas = gradient((600, 200), DARK, (10, 62, 62), radial=[(480, 40, 220, TEAL, 75), (90, 180, 180, ORANGE, 38)]).convert("RGBA")
    canvas = add_noise(canvas.convert("RGB"), 8).convert("RGBA")
    add_logo_lockup(canvas, (36, 38), scale=0.85, light=True)
    d = ImageDraw.Draw(canvas)
    d.text((38, 128), "Now on Product Hunt", font=font(28, bold=True), fill=WHITE)
    d.rounded_rectangle((390, 68, 552, 122), radius=27, fill=ORANGE)
    d.text((421, 84), "Join launch", font=font(20, bold=True), fill=WHITE)
    save_asset(canvas.convert("RGB"), SOCIAL / "email-header-600x200.jpg", quality=92)

    # Reddit/community image with less promotional language.
    canvas = gradient((1600, 900), (246, 251, 246), (226, 247, 242), radial=[(1280, 120, 520, TEAL, 58), (180, 780, 420, ORANGE, 34)]).convert("RGBA")
    canvas = add_noise(canvas.convert("RGB"), 8).convert("RGBA")
    d = ImageDraw.Draw(canvas)
    add_logo_lockup(canvas, (78, 70), scale=1.22)
    draw_text_box(d, (90, 230), "I built a Mac app to use AI inside any text field", font(72, bold=True), INK, 760, 10)
    draw_text_box(d, (94, 450), "Type a command, press Return, and replace it with AI-generated text without leaving the app you are using.", font(34), MUTED, 690, 8)
    card = screenshot_card(screens["rewrite"], (620, 388), radius=34)
    paste_shadow(canvas, card, (860, 245), radius=30, opacity=90, offset=(0, 22))
    save_asset(canvas.convert("RGB"), SOCIAL / "community-founder-post-1600x900.jpg", quality=92)


def build_brand_assets():
    icon = clean_app_icon((180, 180))

    def lockup(path, dark=False):
        bg = DARK if dark else (255, 255, 255)
        fg = WHITE if dark else INK
        sub = (190, 220, 216) if dark else MUTED
        canvas = Image.new("RGBA", (900, 260), (*bg, 255) if isinstance(bg, tuple) else (5, 20, 25, 255))
        if dark:
            canvas = gradient((900, 260), DARK, (12, 62, 62), radial=[(760, 60, 260, TEAL, 62)]).convert("RGBA")
        d = ImageDraw.Draw(canvas)
        paste_shadow(canvas, icon, (54, 40), radius=14, opacity=45, offset=(0, 10))
        d.text((270, 72), "SucceedAI", font=font(64, bold=True), fill=fg)
        d.text((274, 148), "AI text replacement for macOS", font=font(28), fill=sub)
        canvas.save(path, optimize=True)

    lockup(BRAND / "succeedai-logo-lockup-light.png", dark=False)
    lockup(BRAND / "succeedai-logo-lockup-dark.png", dark=True)

    # Product Hunt/community cover.
    cover = gradient((1600, 840), DARK, (10, 70, 67), radial=[(1260, 80, 520, TEAL, 72), (120, 820, 450, ORANGE, 40)]).convert("RGBA")
    cover = add_noise(cover.convert("RGB"), 8).convert("RGBA")
    d = ImageDraw.Draw(cover)
    add_logo_lockup(cover, (90, 74), scale=1.1, light=True)
    draw_text_box(d, (96, 242), "Write with AI in any Mac app", font(82, bold=True), WHITE, 760, 10)
    draw_text_box(d, (102, 455), "Type a command, press Return, and replace it with polished AI-generated text in place.", font(36), (210, 232, 229), 700, 8)
    card = screenshot_card(screens["hero"], (660, 414), radius=36)
    paste_shadow(cover, card, (850, 236), radius=30, opacity=92, offset=(0, 24))
    save_asset(cover.convert("RGB"), BANNERS / "launch-cover-1600x840.jpg", quality=92)


def save_asset(img, path, quality=92):
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, quality=quality, optimize=True, progressive=True)


def write_readme():
    text = """# Product Hunt Launch Assets

Generated assets for the SucceedAI Product Hunt listing.

## Product Hunt Uploads

- `icons/product-hunt-icon-240x240.png` - square product logo/icon.
- `icons/product-hunt-icon-1024x1024.png` - high-resolution clean app icon.
- `gallery/*.jpg` - Product Hunt gallery images at `1270x760`.
- `brand/*.png` - reusable logo lockups.
- `banners/launch-cover-1600x840.jpg` - wide campaign cover.

## Extra Promotional Assets

- `social/product-hunt-og-1200x630.jpg` - Open Graph/social preview.
- `social/x-announcement-1600x900.jpg` - X/Twitter launch post image.
- `social/linkedin-launch-1200x627.jpg` - LinkedIn launch image.
- `social/email-header-600x200.jpg` - email/newsletter header.
- `social/community-founder-post-1600x900.jpg` - community/Reddit-style launch image.

## Notes

- Product Hunt recommends gallery images at `1270x760` and at least two gallery assets.
- The first gallery image is designed with centered content so it survives thumbnail cropping.
- Assets are generated from real app screenshots and the committed app icon.
"""
    (OUT / "README.md").write_text(text)


def main():
    ensure_dirs()
    build_gallery()
    build_icon_assets()
    build_social()
    build_brand_assets()
    write_readme()
    for path in sorted(OUT.rglob("*")):
        if path.is_file():
            print(path.relative_to(ROOT), os.path.getsize(path))


if __name__ == "__main__":
    main()
