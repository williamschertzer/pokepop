# PokéPop Defense (Godot version)

This folder is the same game as the web version in the repo root, rebuilt in the [Godot](https://godotengine.org) game engine. Godot can turn it into a website, an Android app, or a Windows, Mac or Linux program.

It started as a copy of the web version (the Team Rocket story, the original 8 Pokémon, every Pokéball tier, the 4 Kanto maps, 40 waves plus freeplay) and has since grown past it. The Godot version adds:

- **More Pokémon** you have to earn, on Normal or Hard (Easy runs don't count): Magikarp (reach wave 15), Pidgey (wave 25), Geodude (beat a map), Machop (beat 2 different maps), Lapras (beat a map on Hard), Abra (beat 3 maps), Snorlax (beat 4 maps), Dratini (beat 3 maps on Hard), Chansey (wave 20), Eevee and Ditto, plus Caterpie (wave 10, a cheap Bug that slows balls with String Shot and Stun Spore), Togepi (wave 30, shields Pikachu with Protect), Clefairy (beat a map, heals during waves with Moonlight) and Growlithe (beat 2 maps, evolves into Arcanine and learns Extreme Speed). Settings has a switch to unlock them all at once.
- **Healers:** Chansey heals Pikachu after each wave and its Helping Hand makes any Pikachu in its range hit harder and faster. Clefairy heals during waves, and Togepi heals after waves and cuts leak damage.
- **Upgrades always stack.** Evolutions and moves only ever add to a Pokémon, in whatever order you buy them, and the upgrade preview counts nearby Abra auras and Dragon Dance so it never shows a drop.
- **3 new balls:** Timer Balls speed up the longer they roll, Net Balls shrug off Water, and Heal Balls heal themselves if you stop hitting them.
- **Type matchups:** Fighting does double damage to Heavy Balls, Electric and Grass do double to Net Balls, Water does half, and Dragon hits the bosses harder. The Pokédex lists them all.
- **Trainer items** in the side panel: a Potion (+25 HP), Max Repel (every ball slows down for 5 seconds) and Rare Candy (30% off your next upgrade).
- **8 more maps**, opened one at a time by beating the one before it (wave 40 on any difficulty): Route 1, Viridian Forest, Route 12 (a boardwalk with a wild Snorlax asleep in the best spot), Safari Zone (ponds and tall grass), Lavender Town, Diglett's Cave, Rock Tunnel, Cinnabar Volcano (lava pools only Charmander and Growlithe can stand in), Mt. Moon, Seafoam Islands, Cerulean Cave and Victory Road. Maps from older saves stay open.
- **Dark caves:** Mt. Moon, Rock Tunnel, Diglett's Cave and Cerulean Cave are dark. Pokémon see 40% less far unless they are inside the light of a Pokémon that knows Flash (Pikachu or Clefairy can learn it) or right next to a Fire Pokémon.
- **Clearing the way:** rocks, trees, boulders, ice blocks and the sleeping Snorlax take up good spots. Tap one to see who can clear it. The Pokémon has to have the obstacle inside its range and know the move: Bulbasaur learns Cut, Machop Rock Smash and Strength, Geodude Rock Smash (from its upgrade panel, under Field moves), Charmander and Growlithe burn dead trees with Ember and melt ice once they have Flamethrower, and Pikachu jolts Snorlax awake. Rocks sometimes hide a Nugget. Only Squirtle, Magikarp and Lapras can stand in water.
- **Easy, Normal and Hard** for every map, with best waves kept separately.
- **A livelier look:** Pokémon breathe and hop when they attack, balls roll along the path and break into pieces, big moves shake the screen, and each map has its own ambience (butterflies, fireflies, ghost lights, glinting crystals).

The original 8 Pokémon still play the same as in the web version.

All the art is drawn with code, just like the web version. There are no official sprites.

## 1. Open the game in Godot

1. Download **Godot 4.3** (or newer) from https://godotengine.org/download. Pick the normal version, not the ".NET" one. It is a single program, nothing to install: unzip it and double-click it.
2. In the Godot window that opens (the Project Manager), click **Import**.
3. Find this repo's `godot` folder and choose the file `project.godot`. Click **Import & Edit** (or **Open**).
4. The first time, Godot spends a few seconds preparing files. When the editor appears, press the **▶ Play** button at the top right (or the **F5** key). The game opens in its own window.

## 2. Download ready-made builds (no Godot needed)

Every time something is merged into `main`, GitHub builds the game for every platform and puts the files on the **[latest release](https://github.com/williamschertzer/pokepop/releases/latest)** page: `PokePop-Windows.zip`, `PokePop-macOS.zip`, `PokePop-Linux.zip`, `PokePop-Android.apk` and `PokePop-Web.zip`. The web build is also published to https://williamschertzer.github.io/pokepop/. The [main README](../README.md#download-for-mac-windows-linux-or-android) explains how to start each one, including the extra first-launch step on a Mac.

Builds of a pull request that isn't merged yet are on its **Build Godot game** run in the **Actions** tab, under **Artifacts** at the bottom of the page.

The Android build is a test build (signed with a debug key), which is fine for installing on your own phones.

## 3. Make a playable copy yourself (exporting)

You only need to do step A once.

**A. Get the export templates.** In Godot's top menu choose **Editor → Manage Export Templates…**, then click **Download and Install**. This is about 1 GB, so it takes a few minutes.

**B. Export.** Choose **Project → Export…**. The list on the left already has five presets set up for you: **Web**, **Android**, **Windows**, **macOS** and **Linux**. Click one, then click **Export Project…** at the bottom, pick a folder, and click **Save**. Untick "Export With Debug" for the final version.

What you get for each one:

- **Web:** a folder with an `index.html` and a few other files. Upload the whole folder to a website host. On [itch.io](https://itch.io), zip the folder, upload the zip, and tick "This file will be played in the browser". (Opening `index.html` straight from your computer won't work; browsers need it to come from a web server. To try it locally, click the small browser icon next to the Play button in Godot.)
- **Windows:** a single `PokePop.exe`. Double-click it to play. Windows may warn that the app is from an unknown publisher; click **More info → Run anyway**.
- **macOS:** a zip containing the app. Unzip it. The first time, Apple blocks it because it isn't signed by a paid developer account: try to open it, then go to **System Settings → Privacy & Security** and click **Open Anyway** (on older macOS, right-click the app and choose **Open**).
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

The game opens on a title screen. **Continue** picks up your last game, **New game** takes you to the map picker, and **Pokédex** shows how many Pokémon and maps you have unlocked and lists every Pokémon, map, obstacle, ball and type matchup, and **Settings** has the sound volume, an option to ask before releasing a Pokémon, and a switch to unlock every Pokémon and map right away.

Pick a difficulty and a map, then drag a Pokémon from the Party panel onto the map (or click it, or press keys 1 to 9 and 0, then click the map). Snorlax is the one Pokémon that goes on the path itself. The panel at the top right shows which balls the next wave brings. Press **Start wave** (or **Space**). Click a Pokémon on the field to open its upgrade panel; hovering an upgrade shows how its numbers change. **F** changes speed, **P** pauses, and **Esc** cancels or opens the pause menu (restart, change map, settings, main menu). On a phone or tablet you can also tap a spot once to preview and tap it again to place.

**Phones** get their own layout (Settings → Screen layout picks Automatic, Computer or Phone). Automatic uses it on touch screens whose short side is under 560 CSS pixels, so phones but not tablets. The phone layout is landscape only: the field fills the screen height, a rail beside it holds the HUD, the Party (drag a Pokémon out of it, or tap it to read about it first) and the wave controls, and upgrades, obstacles and Party details slide in as drawers. All of it is in `main.gd` under *phone layout*; the computer layout is unchanged.

The game saves itself between waves, so you can close it and choose **Continue** later. If you close it in the middle of a wave, you start again from the beginning of that wave. Your best wave on each map and your settings are saved on the device too.
