# PokéPop Defense (Godot version)

This folder is the same game as the web version in the repo root, rebuilt in the [Godot](https://godotengine.org) game engine. Godot can turn it into a website, an Android app, or a Windows, Mac or Linux program.

Everything from the web version is here: the Team Rocket story, all 8 Pokémon with their evolution and move upgrades, the upgrade panel that lists what each Pokémon has learned, every Pokéball tier, the 4 Kanto maps, 40 waves plus freeplay, and Solar Beam firing across the whole map. The numbers are the same too: the same team played through all 40 waves on every map in both versions ends each wave with the same Pikachu HP and the same Pokédollars. (Deep into freeplay with fully upgraded teams, money can drift by a few ₽ because the two engines round decimals slightly differently.)

All the art is drawn with code, just like the web version. There are no official sprites.

## 1. Open the game in Godot

1. Download **Godot 4.3** (or newer) from https://godotengine.org/download. Pick the normal version, not the ".NET" one. It is a single program, nothing to install: unzip it and double-click it.
2. In the Godot window that opens (the Project Manager), click **Import**.
3. Find this repo's `godot` folder and choose the file `project.godot`. Click **Import & Edit** (or **Open**).
4. The first time, Godot spends a few seconds preparing files. When the editor appears, press the **▶ Play** button at the top right (or the **F5** key). The game opens in its own window.

## 2. Download ready-made builds (no Godot needed)

Every time the `godot` folder changes on GitHub, GitHub builds the game for you:

1. Open the repo on GitHub and click the **Actions** tab.
2. Click the newest **Build Godot game** run with a green tick.
3. Scroll to **Artifacts** at the bottom and download **PokePop-Android**, **PokePop-Windows**, **PokePop-macOS**, **PokePop-Linux** or **PokePop-Web**. Each downloads as a zip; unzip it first.

The Android build is a test build (signed with a debug key), which is fine for installing on your own phones. See the notes below for what to do with each file.

## 3. Make a playable copy yourself (exporting)

You only need to do step A once.

**A. Get the export templates.** In Godot's top menu choose **Editor → Manage Export Templates…**, then click **Download and Install**. This is about 1 GB, so it takes a few minutes.

**B. Export.** Choose **Project → Export…**. The list on the left already has five presets set up for you: **Web**, **Android**, **Windows**, **macOS** and **Linux**. Click one, then click **Export Project…** at the bottom, pick a folder, and click **Save**. Untick "Export With Debug" for the final version.

What you get for each one:

- **Web:** a folder with an `index.html` and a few other files. Upload the whole folder to a website host. On [itch.io](https://itch.io), zip the folder, upload the zip, and tick "This file will be played in the browser". (Opening `index.html` straight from your computer won't work; browsers need it to come from a web server. To try it locally, click the small browser icon next to the Play button in Godot.)
- **Windows:** a single `PokePop.exe`. Double-click it to play. Windows may warn that the app is from an unknown publisher; click **More info → Run anyway**.
- **macOS:** a zip containing the app. Unzip it, then right-click the app and choose **Open** the first time (Apple blocks unsigned apps on a normal double-click).
- **Linux:** a single `PokePop.x86_64` file.
- **Android:** an `.apk` file. Android needs two extra free tools first; see below.

### Android, step by step

1. Install [Android Studio](https://developer.android.com/studio). Open it once and let it download the Android SDK. It also includes the Java it needs.
2. In Godot, open **Editor → Editor Settings…**, scroll the left list to **Export → Android**, and fill in:
   - **Java SDK Path:** Android Studio's built-in Java. On Windows this is usually `C:\Program Files\Android\Android Studio\jbr`. On a Mac it is `/Applications/Android Studio.app/Contents/jbr/Contents/Home`.
   - **Android SDK Path:** on Windows usually `C:\Users\<you>\AppData\Local\Android\Sdk`, on a Mac `~/Library/Android/sdk`.
   Godot creates the "debug keystore" (the key it signs test apps with) by itself.
3. Export with the **Android** preset to get `PokePop.apk`.
4. Copy the APK to your phone (email, Google Drive, or USB), tap it, and allow "install unknown apps" when Android asks.

Shortcut: plug your phone into the computer with USB debugging turned on, and a small Android icon appears next to Godot's Play button. Clicking it installs and starts the game on the phone directly.

To publish on the Google Play Store you would also need a "release keystore" and a Play developer account; Godot's guide explains it: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html

## How to play

The game opens on a title screen. **Continue** picks up your last game, **New game** takes you to the map picker, and **Settings** has the sound volume and an option to ask before releasing a Pokémon.

Pick a map, then drag a Pokémon from the Party panel onto the map (or click it, or press keys 1 to 8, then click the map). The panel at the top right shows which balls the next wave brings. Press **Start wave** (or **Space**). Click a Pokémon on the field to open its upgrade panel; hovering an upgrade shows how its numbers change. **F** changes speed, **P** pauses, and **Esc** cancels or opens the pause menu (restart, change map, settings, main menu). On a phone or tablet you can also tap a spot once to preview and tap it again to place.

The game saves itself between waves, so you can close it and choose **Continue** later. If you close it in the middle of a wave, you start again from the beginning of that wave. Your best wave on each map and your settings are saved on the device too.
