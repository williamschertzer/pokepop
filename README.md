# PokéPop Defense

A Pokémon tower defense game in the style of Bloons TD. Team Rocket is firing Pokéballs down the route at Ash's Pikachu, and your team has to pop every one before it gets there.

## Play

Once GitHub Pages is on, the game lives at https://williamschertzer.github.io/pokepop/ and can be installed as an app:

- **Android / Chrome / Edge:** press **Install app** in the game's header, or use the browser menu's *Install app*.
- **iPhone / iPad:** open the page in Safari, tap **Share**, then **Add to Home Screen**.

After the first visit it works offline.

### Turning on GitHub Pages

Settings → Pages → *Build and deployment* → Source: **Deploy from a branch**, Branch: **main**, folder **/ (root)**.

## What's in the game

- **Pokéballs** get stronger with catch rate: Poké, Great, Ultra, Quick, Dusk (hidden), Heavy (ignores Electric), Master (boss), and Team Rocket's Meowth balloon on wave 40.
- **Pokémon:** Pikachu, Charmander, Squirtle, Bulbasaur, Gastly, Meowth, Wobbuffet and Mewtwo. Each has an evolution path and a moves path; only one path can reach tier 3.
- **Maps:** Route 1, Viridian Forest, Lavender Town and Mt. Moon.

Click a Pokémon on the field to open its upgrade menu, which also lists everything it has already learned.

## Files

- `index.html`: the whole game (HTML, CSS and JavaScript, no build step)
- `manifest.webmanifest`, `sw.js`, `icons/`: what makes it installable and offline-capable

All art is drawn in code; no official sprites are used.
