# PokéPop Defense

A Pokémon tower defense game in the style of Bloons TD. Team Rocket is firing Pokéballs down the route at Ash's Pikachu, and your team has to pop every one before it gets there.

## Play

There are two versions. The **Godot version** (in `godot/`) is the main one: it has 16 Pokémon, a Pokédex, items and difficulty levels. The **classic web version** (`index.html` in the repo root) is the original 8-Pokémon game.

### In your browser

- Godot version: https://williamschertzer.github.io/pokepop/
- Classic web version: https://williamschertzer.github.io/pokepop/classic/

Both update by themselves every time something is merged into `main`. Both can be installed as an app and work offline after the first visit: on Android/Chrome/Edge use **Install app**; on iPhone/iPad open the page in Safari, tap **Share**, then **Add to Home Screen**.

### On a phone

The Godot version has its own phone layout, which turns on by itself on small touch screens. Hold the phone sideways. The map takes the full height of the screen, with your HP, money, Party and wave controls in a column beside it:

- **Drag** a Pokémon from the Party onto the map. The preview floats just above your finger so you can see where it will land; let go off the map to cancel.
- **Tap** a Pokémon in the Party to open a drawer with what it does, its stats and every upgrade, then **Place** it and tap the map twice (once to preview the spot, once to place).
- **Tap** a Pokémon on the map to open its upgrades. Each upgrade shows what it changes ("Damage 1 › 2"), since there's no hovering on a phone.
- **Menu** pauses the game and holds the sound and auto-start switches.

Settings → **Screen layout** switches between Automatic, Computer and Phone.

### Download for Mac, Windows, Linux or Android

Go to the **[latest release](https://github.com/williamschertzer/pokepop/releases/latest)** and download the file for your computer. These are rebuilt automatically from `main`, so they are always the newest version.

| Computer | Download | How to start it |
| --- | --- | --- |
| Windows | [PokePop-Windows.zip](https://github.com/williamschertzer/pokepop/releases/latest/download/PokePop-Windows.zip) | Unzip it and double-click `PokePop.exe`. If Windows says it protected your PC, click **More info → Run anyway** (this only happens because the game isn't signed by a paid publisher). |
| Mac | [PokePop-macOS.zip](https://github.com/williamschertzer/pokepop/releases/latest/download/PokePop-macOS.zip) | Unzip it (double-click) and drag `PokePop.app` into **Applications** if you like. The first time, see *Opening it on a Mac* below. Works on Apple Silicon and Intel Macs. |
| Linux | [PokePop-Linux.zip](https://github.com/williamschertzer/pokepop/releases/latest/download/PokePop-Linux.zip) | Unzip it and run `PokePop.x86_64` (run `chmod +x PokePop.x86_64` first if it won't start). |
| Android | [PokePop-Android.apk](https://github.com/williamschertzer/pokepop/releases/latest/download/PokePop-Android.apk) | Open the link on your phone, tap the downloaded file, and allow "install unknown apps" when asked. |

**Opening it on a Mac.** Apple blocks games that aren't from a paid Apple developer account, so the first launch takes one extra step:

1. Double-click `PokePop.app`. macOS says it can't be opened; click **Done** (or **OK**).
2. Open **System Settings → Privacy & Security**, scroll down, and click **Open Anyway** next to the PokePop message. Confirm with your password.
3. From then on it opens normally. (On older macOS you can instead right-click the app and choose **Open**.)

If macOS says the app "is damaged", open **Terminal** and run `xattr -dr com.apple.quarantine ~/Downloads/PokePop.app` (use the folder where the app actually is), then open it again.

### Turning on GitHub Pages (one-time setup)

Settings → Pages → *Build and deployment* → Source: **GitHub Actions**. The **Build Godot game** workflow then publishes the site on every push to `main`.

## What's in the game

- **Pokéballs** get stronger with catch rate: Poké, Great, Ultra, Quick, Dusk (hidden), Heavy (ignores Electric), Master (boss), and Team Rocket's Meowth balloon on wave 40.
- **Pokémon:** Pikachu, Charmander, Squirtle, Bulbasaur, Gastly, Meowth, Wobbuffet and Mewtwo, plus (Godot version) Magikarp, Pidgey, Geodude, Machop, Abra, Lapras, Snorlax and Dratini, which unlock as you play. Each has an evolution path and a moves path; only one path can reach tier 3.
- **Maps:** Route 1, Viridian Forest, Lavender Town and Mt. Moon.

Click a Pokémon on the field to open its upgrade menu, which also lists everything it has already learned.

## Godot version

The `godot/` folder has the game rebuilt in the Godot engine, so it can also be an Android app or a Windows, Mac or Linux program. GitHub builds all of those automatically (see *Download* above). To open or change it in Godot yourself, see [godot/README.md](godot/README.md).

## Files

- `index.html`: the whole classic web game (HTML, CSS and JavaScript, no build step)
- `manifest.webmanifest`, `sw.js`, `icons/`: what makes it installable and offline-capable
- `godot/`: the Godot version (see its README)
- `.github/workflows/godot-build.yml`: builds every platform, updates the latest release and publishes GitHub Pages

All art is drawn in code; no official sprites are used.
