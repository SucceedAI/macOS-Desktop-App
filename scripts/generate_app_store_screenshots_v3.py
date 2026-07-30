#!/usr/bin/env python3
"""Generate SucceedAI's premium, use-case-led App Store screenshot campaign.

All product UI comes from real simulator or running-app captures. The generated
background plates are decorative brand assets only.
"""

import argparse
import shutil
from pathlib import Path
from typing import Iterable

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "AppStore/Screenshots/v3-preview"
IOS_RAW = ROOT / "AppStore/Screenshots/iOS/Raw"
IOS_RAW_V3 = ROOT / "AppStore/Screenshots/iOS/Raw-v3"
MAC_RAW = ROOT / "AppStore/Captures/macOS"
BRAND = ROOT / "AppStore/Brand/Backgrounds"
ICON = ROOT / "iOS/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"

PORTRAIT_BG = BRAND / "premium-ribbons-portrait-v3.png"
LANDSCAPE_BG = BRAND / "premium-ribbons-landscape-v3.png"

IPHONE = (1320, 2868)
IPAD = (2064, 2752)
MAC = (2880, 1800)

SF = Path("/System/Library/Fonts/SFNS.ttf")
SF_DISPLAY = Path("/System/Library/Fonts/SFNSDisplay.ttf")
SF_ROUNDED = Path("/System/Library/Fonts/SFNSRounded.ttf")

WHITE = (255, 255, 255, 255)
SOFT = (210, 222, 250, 255)
INK = (8, 16, 40, 255)
CYAN = (27, 224, 242, 255)
BLUE = (71, 138, 255, 255)
VIOLET = (157, 102, 255, 255)
MAGENTA = (239, 84, 232, 255)
GREEN = (70, 226, 155, 255)


def font(size: int, weight: str = "regular") -> ImageFont.FreeTypeFont:
    if weight == "heavy":
        path = SF_ROUNDED
    elif SF_DISPLAY.exists():
        path = SF_DISPLAY
    else:
        path = SF
    return ImageFont.truetype(str(path), size=size)


def fit_background(path: Path, size: tuple[int, int], darken: int = 0) -> Image.Image:
    source = Image.open(path).convert("RGBA")
    scale = max(size[0] / source.width, size[1] / source.height)
    resized = source.resize(
        (round(source.width * scale), round(source.height * scale)),
        Image.Resampling.LANCZOS,
    )
    left = (resized.width - size[0]) // 2
    top = (resized.height - size[1]) // 2
    canvas = resized.crop((left, top, left + size[0], top + size[1]))
    if darken:
        canvas.alpha_composite(Image.new("RGBA", size, (1, 5, 22, darken)))
    return canvas


def tracking_text(
    draw: ImageDraw.ImageDraw,
    xy: tuple[int, int],
    value: str,
    selected_font: ImageFont.FreeTypeFont,
    fill,
    tracking: int,
):
    x, y = xy
    for character in value:
        draw.text((x, y), character, font=selected_font, fill=fill)
        x += int(draw.textlength(character, font=selected_font)) + tracking


def wrap(
    draw: ImageDraw.ImageDraw,
    value: str,
    selected_font: ImageFont.FreeTypeFont,
    max_width: int,
) -> list[str]:
    lines: list[str] = []
    for paragraph in value.splitlines():
        words = paragraph.split()
        current = ""
        for word in words:
            candidate = f"{current} {word}".strip()
            if draw.textlength(candidate, font=selected_font) <= max_width:
                current = candidate
            else:
                if current:
                    lines.append(current)
                current = word
        if current:
            lines.append(current)
    return lines


def paragraph(
    draw: ImageDraw.ImageDraw,
    xy: tuple[int, int],
    value: str,
    selected_font: ImageFont.FreeTypeFont,
    fill,
    max_width: int,
    leading: float = 1.15,
) -> int:
    x, y = xy
    for line in wrap(draw, value, selected_font, max_width):
        draw.text((x, y), line, font=selected_font, fill=fill)
        y += round(selected_font.size * leading)
    return y


def app_icon(size: int) -> Image.Image:
    icon = Image.open(ICON).convert("RGBA").resize((size, size), Image.Resampling.LANCZOS)
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, size - 1, size - 1), radius=round(size * 0.235), fill=255
    )
    icon.putalpha(mask)
    return icon


def add_brand_lockup(canvas: Image.Image, x: int, y: int, scale: float = 1.0):
    icon_size = round(62 * scale)
    canvas.alpha_composite(app_icon(icon_size), (x, y))
    draw = ImageDraw.Draw(canvas)
    draw.text(
        (x + icon_size + round(18 * scale), y + round(7 * scale)),
        "SucceedAI",
        font=font(round(35 * scale), "heavy"),
        fill=WHITE,
    )


def add_header(
    canvas: Image.Image,
    kicker: str,
    title: str,
    subtitle: str,
    *,
    left: int,
    top: int,
    width: int,
    title_size: int,
    align: str = "left",
) -> int:
    draw = ImageDraw.Draw(canvas)
    kicker_font = font(round(title_size * 0.235), "heavy")
    title_font = font(title_size, "heavy")
    subtitle_font = font(round(title_size * 0.34))
    lines = title.splitlines()

    if align == "center":
        kicker_width = sum(
            int(draw.textlength(ch, font=kicker_font)) + round(title_size * 0.035)
            for ch in kicker
        )
        tracking_text(
            draw,
            (left + (width - kicker_width) // 2, top),
            kicker.upper(),
            kicker_font,
            CYAN,
            round(title_size * 0.035),
        )
        y = top + round(title_size * 0.48)
        for line in lines:
            bbox = draw.textbbox((0, 0), line, font=title_font)
            draw.text(
                (left + width // 2, y),
                line,
                font=title_font,
                fill=WHITE,
                anchor="ma",
            )
            y += round((bbox[3] - bbox[1]) * 1.14)
        subtitle_lines = wrap(draw, subtitle, subtitle_font, width)
        y += round(title_size * 0.1)
        for line in subtitle_lines:
            draw.text(
                (left + width // 2, y),
                line,
                font=subtitle_font,
                fill=SOFT,
                anchor="ma",
            )
            y += round(subtitle_font.size * 1.22)
        return y

    tracking_text(
        draw,
        (left, top),
        kicker.upper(),
        kicker_font,
        CYAN,
        round(title_size * 0.035),
    )
    y = top + round(title_size * 0.5)
    for line in lines:
        draw.text((left, y), line, font=title_font, fill=WHITE)
        y += round(title_size * 0.94)
    y += round(title_size * 0.1)
    return paragraph(draw, (left, y), subtitle, subtitle_font, SOFT, width, 1.25)


def rounded_capture(
    canvas: Image.Image,
    source: Image.Image,
    box: tuple[int, int, int, int],
    radius: int,
    *,
    border=(255, 255, 255, 105),
    shadow_alpha=150,
):
    x1, y1, x2, y2 = box
    width, height = x2 - x1, y2 - y1
    fitted = source.resize((width, height), Image.Resampling.LANCZOS)
    mask = Image.new("L", (width, height), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, width - 1, height - 1), radius=radius, fill=255
    )

    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        (x1, y1 + 34, x2, y2 + 38),
        radius=radius,
        fill=(0, 0, 15, shadow_alpha),
    )
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(52)))
    canvas.paste(fitted, (x1, y1), mask)
    ImageDraw.Draw(canvas).rounded_rectangle(
        (x1, y1, x2 - 1, y2 - 1), radius=radius, outline=border, width=4
    )


def crop(source: Image.Image, box: tuple[int, int, int, int]) -> Image.Image:
    return source.crop(box)


def load(path: Path) -> Image.Image:
    if not path.exists():
        raise FileNotFoundError(path)
    return Image.open(path).convert("RGBA")


def phone_canvas() -> Image.Image:
    return fit_background(PORTRAIT_BG, IPHONE, darken=46)


def ipad_canvas() -> Image.Image:
    return fit_background(PORTRAIT_BG, IPAD, darken=54)


def mac_canvas() -> Image.Image:
    return fit_background(LANDSCAPE_BG, MAC, darken=58)


def iphone_full(
    source: Image.Image,
    kicker: str,
    title: str,
    subtitle: str,
) -> Image.Image:
    canvas = phone_canvas()
    add_header(
        canvas,
        kicker,
        title,
        subtitle,
        left=78,
        top=80,
        width=1164,
        title_size=112,
        align="center",
    )
    rounded_capture(canvas, source, (98, 680, 1222, 3122), 92)
    return canvas


def iphone_outcomes(source: Image.Image) -> Image.Image:
    canvas = phone_canvas()
    add_header(
        canvas,
        "NO PROMPT ENGINEERING",
        "Ten outcomes.\nOne clear choice.",
        "Pick what you need. SucceedAI handles the instruction.",
        left=70,
        top=84,
        width=1180,
        title_size=110,
        align="center",
    )
    action_area = crop(source, (45, 320, 1275, 1395))
    rounded_capture(canvas, action_area, (78, 730, 1242, 1748), 60)

    draw = ImageDraw.Draw(canvas)
    actions = [
        ("POLISH", "Make it clear"),
        ("SUMMARIZE", "Find the signal"),
        ("PLAN", "Get next steps"),
        ("TRANSLATE", "Switch language"),
    ]
    for index, (label, detail) in enumerate(actions):
        row, column = divmod(index, 2)
        left = 78 + column * 594
        top = 1848 + row * 338
        draw.rounded_rectangle(
            (left, top, left + 570, top + 286),
            radius=46,
            fill=(8, 18, 54, 218),
            outline=(127, 173, 255, 100),
            width=3,
        )
        tracking_text(draw, (left + 42, top + 38), label, font(26, "heavy"), CYAN, 2)
        draw.text(
            (left + 42, top + 104),
            detail,
            font=font(46),
            fill=WHITE,
        )
    return canvas


def iphone_plan(source: Image.Image) -> Image.Image:
    canvas = phone_canvas()
    add_header(
        canvas,
        "A REAL WORKDAY USE CASE",
        "From loose notes\nto next steps.",
        "Turn scattered thoughts into a plan you can act on.",
        left=70,
        top=84,
        width=1180,
        title_size=110,
        align="center",
    )
    draw = ImageDraw.Draw(canvas)
    cards = [
        (
            (78, 750, 1242, 1205),
            "ROUGH NOTES",
            "Launch brief Friday\n• finalise copy\n• ask Maya for images\n• send review link",
            (92, 121, 181, 105),
        ),
        (
            (78, 1310, 1242, 1850),
            "CLEAR PLAN",
            "1  Finalise launch copy\n2  Request product images\n3  Share the review link\n4  Publish on Friday",
            (97, 74, 215, 160),
        ),
    ]
    for box, label, body, fill in cards:
        draw.rounded_rectangle(
            box,
            radius=54,
            fill=fill,
            outline=(255, 255, 255, 72),
            width=3,
        )
        tracking_text(
            draw,
            (box[0] + 48, box[1] + 42),
            label,
            font(27, "heavy"),
            CYAN if label == "ROUGH NOTES" else MAGENTA,
            3,
        )
        paragraph(
            draw,
            (box[0] + 48, box[1] + 112),
            body,
            font(43, "heavy" if label == "CLEAR PLAN" else "regular"),
            WHITE,
            box[2] - box[0] - 96,
            1.32,
        )
    draw.ellipse((574, 1170, 746, 1342), fill=(111, 77, 255, 255))
    draw.text((660, 1252), "↓", font=font(76, "heavy"), fill=WHITE, anchor="mm")

    action_area = crop(source, (45, 360, 1275, 1100))
    rounded_capture(canvas, action_area, (78, 1980, 1242, 2680), 54)
    return canvas


def ipad_full(
    source: Image.Image,
    kicker: str,
    title: str,
    subtitle: str,
) -> Image.Image:
    canvas = ipad_canvas()
    add_header(
        canvas,
        kicker,
        title,
        subtitle,
        left=104,
        top=76,
        width=1856,
        title_size=126,
        align="center",
    )
    rounded_capture(canvas, source, (142, 650, 1922, 3023), 62)
    return canvas


def ipad_outcomes(source: Image.Image) -> Image.Image:
    canvas = ipad_canvas()
    add_header(
        canvas,
        "TEN USEFUL OUTCOMES",
        "Choose the result.\nSkip the prompt.",
        "Proofread, polish, reply, summarize, plan, translate and more.",
        left=104,
        top=76,
        width=1856,
        title_size=126,
        align="center",
    )
    focused = crop(source, (30, 270, 2034, 1600))
    rounded_capture(canvas, focused, (112, 690, 1952, 1911), 58)
    draw = ImageDraw.Draw(canvas)
    points = [
        ("01", "Choose an outcome"),
        ("02", "Add your draft"),
        ("03", "Generate locally"),
    ]
    for index, (number, label) in enumerate(points):
        left = 112 + index * 620
        draw.rounded_rectangle(
            (left, 2045, left + 580, 2460),
            radius=48,
            fill=(8, 18, 54, 220),
            outline=(127, 173, 255, 95),
            width=3,
        )
        draw.text((left + 48, 2085), number, font=font(66, "heavy"), fill=VIOLET)
        paragraph(
            draw,
            (left + 48, 2190),
            label,
            font(42, "heavy"),
            WHITE,
            480,
            1.1,
        )
    return canvas


def mac_capture(
    source: Image.Image,
    kicker: str,
    title: str,
    subtitle: str,
    *,
    callouts: Iterable[str],
) -> Image.Image:
    canvas = mac_canvas()
    add_brand_lockup(canvas, 150, 105, 1.18)
    add_header(
        canvas,
        kicker,
        title,
        subtitle,
        left=150,
        top=270,
        width=1370,
        title_size=132,
    )
    draw = ImageDraw.Draw(canvas)
    y = 1190
    for label in callouts:
        selected_font = font(31, "heavy")
        width = round(draw.textlength(label, font=selected_font)) + 92
        draw.rounded_rectangle(
            (150, y, 150 + width, y + 74),
            radius=37,
            fill=(12, 29, 71, 255),
            outline=(115, 166, 255, 150),
            width=2,
        )
        draw.ellipse((178, y + 25, 202, y + 49), fill=CYAN)
        draw.text((222, y + 17), label, font=selected_font, fill=WHITE)
        y += 92

    max_width, max_height = 1190, 1530
    scale = min(max_width / source.width, max_height / source.height)
    width, height = round(source.width * scale), round(source.height * scale)
    x = 2880 - width - 120
    y = (1800 - height) // 2 + 22
    rounded_capture(canvas, source, (x, y, x + width, y + height), 48)
    return canvas


def mac_use_case(source: Image.Image) -> Image.Image:
    canvas = mac_canvas()
    add_brand_lockup(canvas, 150, 105, 1.18)
    add_header(
        canvas,
        "A REAL WORKDAY USE CASE",
        "Scattered notes.\nClear next steps.",
        "Choose Build a Plan and turn an unstructured brain-dump into work you can move.",
        left=150,
        top=270,
        width=1320,
        title_size=124,
    )
    draw = ImageDraw.Draw(canvas)
    source_box = (1540, 170, 2740, 705)
    result_box = (1540, 880, 2740, 1560)
    for box, fill in [
        (source_box, (29, 50, 93, 230)),
        (result_box, (72, 44, 143, 225)),
    ]:
        draw.rounded_rectangle(
            box,
            radius=52,
            fill=fill,
            outline=(255, 255, 255, 74),
            width=3,
        )
    tracking_text(draw, (1600, 225), "ROUGH NOTES", font(28, "heavy"), CYAN, 3)
    paragraph(
        draw,
        (1600, 310),
        "Launch brief Friday\n• finalise copy\n• request product images\n• share the review link",
        font(42),
        WHITE,
        1050,
        1.32,
    )
    tracking_text(draw, (1600, 935), "ACTION PLAN", font(28, "heavy"), MAGENTA, 3)
    paragraph(
        draw,
        (1600, 1020),
        "1  Finalise launch copy\n2  Request product images\n3  Share the review link\n4  Publish on Friday",
        font(45, "heavy"),
        WHITE,
        1050,
        1.35,
    )
    draw.ellipse((2038, 680, 2242, 884), fill=(110, 76, 255, 255))
    draw.text((2140, 778), "↓", font=font(86, "heavy"), fill=WHITE, anchor="mm")

    focused = crop(source, (0, 380, source.width, 1110))
    rounded_capture(canvas, focused, (150, 1235, 1400, 1700), 42)
    return canvas


def save(image: Image.Image, path: Path):
    path.parent.mkdir(parents=True, exist_ok=True)
    image.convert("RGB").save(path, "PNG", optimize=True)
    print(path.relative_to(ROOT))


def clean():
    OUT.mkdir(parents=True, exist_ok=True)
    for existing in OUT.rglob("*.png"):
            existing.unlink()


def publish():
    """Replace the local Fastlane/App Store delivery folders with QA'd v3 assets."""
    destinations = [
        ROOT / "fastlane/screenshots-ios/en-US",
        ROOT / "AppStore/Screenshots/macOS",
        ROOT / "fastlane/screenshots/en-AU",
    ]
    for destination in destinations:
        destination.mkdir(parents=True, exist_ok=True)
        for existing in destination.glob("*.png"):
            existing.unlink()

    for source in sorted((OUT / "iPhone").glob("*.png")) + sorted(
        (OUT / "iPad").glob("*.png")
    ):
        shutil.copy2(source, ROOT / "fastlane/screenshots-ios/en-US" / source.name)

    for source in sorted((OUT / "macOS").glob("*.png")):
        shutil.copy2(source, ROOT / "AppStore/Screenshots/macOS" / source.name)
        fastlane_name = source.name.replace(".png", "_DESKTOP.png")
        shutil.copy2(source, ROOT / "fastlane/screenshots/en-AU" / fastlane_name)

    print("Published QA'd v3 screenshots to the Fastlane delivery folders.")


def main(should_publish: bool = False):
    clean()
    actions = load(IOS_RAW_V3 / "actions-result.png")
    keyboard_phone = load(IOS_RAW / "02-keyboard-1320x2868.png")
    privacy_phone = load(IOS_RAW / "03-privacy-1320x2868.png")

    ipad_actions = load(IOS_RAW_V3 / "ipad-landscape-actions.png")
    ipad_keyboard = load(IOS_RAW_V3 / "ipad-landscape-keyboard.png")
    ipad_privacy = load(IOS_RAW_V3 / "ipad-landscape-privacy.png")

    iphone_shots = [
        (
            "01-rough-draft-to-ready-1320x2868.png",
            iphone_full(
                actions,
                "PRIVATE AI WRITING",
                "Rough draft.\nReady to send.",
                "Polish everyday writing in seconds, right on your iPhone.",
            ),
        ),
        (
            "02-ai-where-you-type-1320x2868.png",
            iphone_full(
                keyboard_phone,
                "SUCCEEDAI KEYBOARD",
                "AI, right where\nyou type.",
                "Transform selected text without breaking your flow.",
            ),
        ),
        (
            "03-your-words-never-leave-1320x2868.png",
            iphone_full(
                privacy_phone,
                "PRIVATE BY ARCHITECTURE",
                "Your words\nnever leave.",
                "No account. No backend. No cloud prompt history.",
            ),
        ),
        ("04-ten-outcomes-1320x2868.png", iphone_outcomes(actions)),
        ("05-notes-to-next-steps-1320x2868.png", iphone_plan(actions)),
    ]

    ipad_shots = [
        (
            "01-private-writing-workspace-2064x2752.png",
            ipad_full(
                ipad_actions,
                "PRIVATE AI FOR IPAD",
                "A bigger canvas\nfor better thinking.",
                "Draft, transform and refine without sending your words away.",
            ),
        ),
        ("02-choose-the-outcome-2064x2752.png", ipad_outcomes(ipad_actions)),
        (
            "03-ai-in-any-app-2064x2752.png",
            ipad_full(
                ipad_keyboard,
                "SUCCEEDAI KEYBOARD",
                "AI in any app.\nWithout the cloud.",
                "Work where you already write, with undo built into the flow.",
            ),
        ),
        (
            "04-private-by-architecture-2064x2752.png",
            ipad_full(
                ipad_privacy,
                "PRIVACY FIRST",
                "Private isn’t\na setting.",
                "It’s the architecture: no account, no backend, no uploads.",
            ),
        ),
    ]

    mac_ready = load(MAC_RAW / "01-ready-panel.png")
    mac_actions = load(MAC_RAW / "02-polish-action.png")
    mac_result = load(MAC_RAW / "03-local-result.png")
    mac_settings = load(MAC_RAW / "04-settings.png")
    mac_shots = [
        (
            "01-rough-text-to-finished-work-2880x1800.png",
            mac_capture(
                mac_result,
                "PRIVATE AI IN YOUR MENU BAR",
                "Rough text.\nFinished work.",
                "Compare your draft and polished result in one focused place.",
                callouts=("Original preserved", "Copy when ready", "Refine locally"),
            ),
        ),
        (
            "02-ten-outcomes-one-click-2880x1800.png",
            mac_capture(
                mac_actions,
                "NO PROMPT ENGINEERING",
                "Ten outcomes.\nOne clear choice.",
                "Polish, proofread, shorten, reply, summarize, plan, translate and more.",
                callouts=("Choose the outcome", "Paste your draft", "Generate on-device"),
            ),
        ),
        (
            "03-copy-transform-paste-2880x1800.png",
            mac_capture(
                mac_ready,
                "WORKS WITH THE APPS YOU USE",
                "Copy. Transform.\nPaste anywhere.",
                "Bring in only the text you choose, without invasive permissions.",
                callouts=("User controlled", "No monitoring", "Always in reach"),
            ),
        ),
        (
            "04-private-by-architecture-2880x1800.png",
            mac_capture(
                mac_settings,
                "PRIVACY FIRST",
                "Private isn’t\na setting.",
                "No account, no cloud, and no Accessibility or Input Monitoring permission.",
                callouts=("On-device model", "Works offline", "No prompt history"),
            ),
        ),
        (
            "05-notes-to-next-steps-2880x1800.png",
            mac_use_case(mac_actions),
        ),
    ]

    for filename, image in iphone_shots:
        save(image, OUT / "iPhone" / filename)
    for filename, image in ipad_shots:
        save(image, OUT / "iPad" / filename)
    for filename, image in mac_shots:
        save(image, OUT / "macOS" / filename)
    if should_publish:
        publish()


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--publish",
        action="store_true",
        help="Replace the local Fastlane delivery folders after rendering.",
    )
    arguments = parser.parse_args()
    main(arguments.publish)
