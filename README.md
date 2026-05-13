# SucceedAI - AI Writing Assistant for macOS

SucceedAI is an AI text replacement assistant for Mac. Type a configurable command in any editable macOS text field, describe what you need, press Return, and SucceedAI replaces the command with polished AI-generated text in place.

![SucceedAI AI writing assistant for Mac](ProductHunt/gallery/01-ai-command-anywhere-1270x760.jpg)

## Why It Exists

Most AI writing workflows force you to leave the app where the writing is happening:

1. Copy text from Mail, Notes, Slack, a browser, or a document.
2. Open a chatbot or AI editor.
3. Write a prompt.
4. Copy the result.
5. Paste it back.
6. Fix the flow you just interrupted.

SucceedAI removes that copy-paste loop. It brings AI writing directly into the active Mac text field.

## What You Can Do

- Rewrite emails so they are clearer, warmer, shorter, or more direct.
- Summarize notes into action items.
- Translate messages without opening another app.
- Draft support replies inside the browser or help desk you already use.
- Polish social posts, product copy, issue comments, release notes, and documentation.
- Customize the command trigger from the settings panel.

## How It Works

1. Open any app with an editable text field.
2. Type your SucceedAI trigger, such as `/ai`.
3. Describe the writing task.
4. Press Return.
5. SucceedAI replaces the command with the generated response.

Example:

```text
/ai rewrite this launch email so it is concise and friendly
```

## macOS Permission

The app needs Accessibility permission because macOS requires it for apps that detect global keyboard input and insert text into other apps. The app includes a guided permission setup and a Settings panel where users can check the permission state.

![SucceedAI macOS permission setup](ProductHunt/gallery/04-permissions-made-clear-1270x760.jpg)

## Settings Panel

_Launch at Login, Replacement Trigger Customization, ..._

![SucceedAI settings panel](ProductHunt/gallery/05-custom-replacement-trigger-1270x760.jpg)


## Get Started For Development

1. Rename `Succeed AI/Config.swift.dist` to `Succeed AI/Config.swift` and update the values.
2. Set up your local Xcode signing configuration:

   ```bash
   cp Local.xcconfig.dist Local.xcconfig
   ```

3. Open `Local.xcconfig` and replace `YOUR_TEAM_ID` with your Apple Developer Team ID.
4. Open the project in Xcode on macOS.
5. Build and run the `SucceedAI` scheme.

`Local.xcconfig` is git-ignored and keeps signing credentials out of source control. Never commit it. The committed template is `Local.xcconfig.dist`.

## Run Checks

```bash
xcodebuild -project 'Succeed AI.xcodeproj' -scheme SucceedAI -configuration Debug -destination 'platform=macOS' -only-testing:'Succeed AITests' test
xcodebuild -project 'Succeed AI.xcodeproj' -scheme SucceedAI -configuration Release -destination 'platform=macOS' build
```

## Generate Store And Launch Assets

```bash
python3 scripts/generate_app_store_screenshots.py
python3 scripts/generate_product_hunt_assets.py
```

The App Store screenshot generator writes both `AppStore/Screenshots/macOS/` and the Fastlane upload folder `fastlane/screenshots/en-US/`.

## Fastlane Release Checks

```bash
fastlane mac screenshots
fastlane mac verify_release_build
```

Use `fastlane mac upload_metadata` for App Store metadata and screenshots only. Use `fastlane mac release` after Apple signing credentials and App Store Connect authentication are configured.

## Backend Proxy

The macOS app defaults to the server proxy flow. The backend in `ai-proxy-server/` is configured for Railway and uses the OpenAI Responses API by default.

```bash
cd ai-proxy-server
npm install
npm run build
```


## Author

**[Pierre-Henry Soria ツ](https://ph7.me)** – A super passionate & enthusiastic Problem-Solver and AI Software Engineer with data scientist background. Also, a real Roquefort 🧀, ristretto ☕️, and dark chocolate lover! 😋

[![Pierre-Henry Soria](https://avatars0.githubusercontent.com/u/1325411?s=200)](https://ph7.me "Pierre-Henry Soria, Software Developer")

[![YouTube Video](https://img.shields.io/badge/YouTube-FF0000?style=for-the-badge&logo=youtube&logoColor=white)](https://youtu.be/cWBuZ4DXGK4 "YouTube SucceedAI Video") [![@phenrysay](https://img.shields.io/badge/x-000000?style=for-the-badge&logo=x)](https://x.com/phenrysay "Follow Me on X") [![pH-7](https://img.shields.io/badge/GitHub-100000?style=for-the-badge&logo=github&logoColor=white)](https://github.com/pH-7 "My GitHub") [![BlueSky](https://img.shields.io/badge/BlueSky-00A8E8?style=for-the-badge&logo=bluesky&logoColor=white)](https://bsky.app/profile/pierrehenry.dev "Follow Me on BlueSky")
