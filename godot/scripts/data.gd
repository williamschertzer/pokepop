class_name Data
extends RefCounted
## Game data: Pokéball tiers, Pokémon towers and their upgrades, maps and waves.
## Numbers match the web version (index.html) so balance is the same.

const W := 960.0
const H := 600.0

const BALLS := {
	"poke":   {"name": "Poké Ball",  "rate": "×1",   "tier": 0, "spd": 1.00, "hp": 1, "kids": [], "r": 11.0, "top": "#e3350d", "note": "The basic ball."},
	"great":  {"name": "Great Ball", "rate": "×1.5", "tier": 1, "spd": 1.35, "hp": 1, "kids": ["poke"], "r": 11.5, "top": "#2f6fd6", "note": "Faster. Pops into a Poké Ball."},
	"ultra":  {"name": "Ultra Ball", "rate": "×2",   "tier": 2, "spd": 1.75, "hp": 1, "kids": ["great"], "r": 12.0, "top": "#232328", "note": "Pops into a Great Ball."},
	"quick":  {"name": "Quick Ball", "rate": "×5",   "tier": 3, "spd": 2.8,  "hp": 1, "kids": ["ultra"], "r": 12.0, "top": "#2c86e0", "note": "Very fast. Pops into an Ultra Ball."},
	"timer":  {"name": "Timer Ball", "rate": "×4",   "tier": 3, "spd": 1.0,  "hp": 1, "kids": ["ultra"], "r": 12.0, "top": "#d8d8d2", "accel": true, "note": "Starts slow and speeds up the longer it rolls."},
	"net":    {"name": "Net Ball",   "rate": "×3.5", "tier": 4, "spd": 1.25, "hp": 2, "kids": ["ultra", "ultra"], "r": 12.5, "top": "#2fa6b4", "note": "Takes 2 hits. Water does half damage, Electric and Grass double."},
	"heal":   {"name": "Heal Ball",  "rate": "×1",   "tier": 4, "spd": 1.15, "hp": 4, "kids": ["great", "great"], "r": 12.5, "top": "#f28ab4", "regen": true, "note": "Takes 4 hits and heals itself if you stop hitting it."},
	"dusk":   {"name": "Dusk Ball",  "rate": "×3.5", "tier": 4, "spd": 1.80, "hp": 1, "kids": ["quick", "quick"], "r": 12.5, "top": "#1f3d2a", "hidden": true, "note": "Hidden. Only ghosts, Light Ball Pikachu and Charizard can see it."},
	"heavy":  {"name": "Heavy Ball", "rate": "+30",  "tier": 5, "spd": 0.95, "hp": 3, "kids": ["quick", "quick"], "r": 13.5, "top": "#8f9aaa", "armored": true, "note": "Takes 3 hits and shrugs off Electric attacks."},
	"master": {"name": "Master Ball", "rate": "×255", "tier": 6, "spd": 0.55, "hp": 400, "kids": ["heavy", "heavy", "dusk", "dusk"], "r": 24.0, "top": "#7b3fb4", "boss": true, "note": "Huge health. Immune to sleep."},
	"rocket": {"name": "Meowth Balloon", "rate": "R", "tier": 7, "spd": 0.38, "hp": 1500, "kids": ["master", "master"], "r": 30.0, "top": "#f4e3b0", "boss": true, "note": "Team Rocket's ride. Pops into two Master Balls."},
}
const ORDER := ["poke", "great", "ultra", "quick", "timer", "net", "heal", "dusk", "heavy", "master", "rocket"]

## Type matchups: damage multipliers for an attack type against a ball.
const TYPE_EFFECT := {
	"Fighting": {"heavy": 2.0},
	"Rock": {"heavy": 1.5},
	"Electric": {"net": 2.0},
	"Grass": {"net": 2.0},
	"Water": {"net": 0.5},
	"Dragon": {"master": 1.5, "rocket": 1.5},
}

## Easy / Normal / Hard: starting money, Pikachu HP and ball speed.
const DIFFS := {
	"easy": {"name": "Easy", "cash": 1.3, "lives": 1.5, "speed": .9},
	"normal": {"name": "Normal", "cash": 1.0, "lives": 1.0, "speed": 1.0},
	"hard": {"name": "Hard", "cash": .85, "lives": .6, "speed": 1.12},
}

## Trainer items bought from the side panel. Potion gets pricier each use in a game.
const ITEMS := {
	"potion": {"short": "Potion", "name": "Potion", "cost": 250, "step": 150, "desc": "Restores 25 Pikachu HP."},
	"repel": {"short": "Repel", "name": "Max Repel", "cost": 400, "step": 0, "desc": "Every ball moves at half speed for 5 seconds. Use it during a wave."},
	"candy": {"short": "Candy", "name": "Rare Candy", "cost": 300, "step": 0, "desc": "Your next upgrade costs 30% less."},
}

## New Pokémon unlock when you reach this wave on any map.
const UNLOCK := {"magikarp": 5, "pidgey": 10, "geodude": 15, "machop": 20, "abra": 25, "lapras": 30, "snorlax": 35, "dratini": 40}

## Upgrade effects are lists of [op, stat, value]: "+" adds, "*" multiplies, "=" sets.
const TOWERS := {
	"pikachu": {"name": "Pikachu", "role": "Chain lightning", "type": "Electric", "cost": 250,
		"blurb": "Fast Thunder Shocks that chain to nearby balls. Heavy Balls ignore Electric attacks.",
		"base": {"range": 120, "rate": 0.6, "dmg": 1, "chain": 1, "detect": false},
		"A": [
			{"name": "Evolve: Raichu", "cost": 500, "desc": "+1 damage, +15 range, chains to 1 more ball.", "fx": [["+", "dmg", 1], ["+", "range", 15], ["+", "chain", 1]]},
			{"name": "Light Ball", "cost": 900, "desc": "Attacks 40% faster and can see Dusk Balls.", "fx": [["*", "rate", 0.6], ["=", "detect", true]]},
			{"name": "Gigantamax", "cost": 4200, "desc": "G-Max Volt Crash every 7s hits every ball on the map for 3.", "fx": [["=", "gmax", 7]]}],
		"B": [
			{"name": "Quick Attack", "cost": 300, "desc": "Attacks 30% faster.", "fx": [["*", "rate", 0.7]]},
			{"name": "Thunderbolt", "cost": 750, "desc": "+1 damage and chains to 2 more balls.", "fx": [["+", "dmg", 1], ["+", "chain", 2]]},
			{"name": "Thunder", "cost": 2600, "desc": "Every 3rd attack is Thunder: 8 damage in an area, even to Heavy Balls.", "fx": [["=", "thunder", true]]}]},
	"charmander": {"name": "Charmander", "role": "Crowd burner", "type": "Fire", "cost": 375,
		"blurb": "Short-range flame bursts that scorch a whole cluster of balls.",
		"base": {"range": 88, "rate": 1.0, "dmg": 1, "pierce": 5, "cone": 0.5, "burn": 0, "burnMul": 1, "detect": false},
		"A": [
			{"name": "Evolve: Charmeleon", "cost": 550, "desc": "+1 damage, +10 range, flames hit 4 more balls.", "fx": [["+", "dmg", 1], ["+", "range", 10], ["+", "pierce", 4]]},
			{"name": "Evolve: Charizard", "cost": 1600, "desc": "+25 range, wider flames, hits 6 more. Flies high enough to see Dusk Balls.", "fx": [["+", "range", 25], ["+", "pierce", 6], ["=", "cone", 0.8], ["=", "detect", true]]},
			{"name": "Mega Charizard X", "cost": 5000, "desc": "+3 damage, 40% faster, burns do double damage.", "fx": [["+", "dmg", 3], ["*", "rate", 0.6], ["=", "burnMul", 2]]}],
		"B": [
			{"name": "Flamethrower", "cost": 400, "desc": "+20 range and flames hit 3 more balls.", "fx": [["+", "range", 20], ["+", "pierce", 3]]},
			{"name": "Fire Spin", "cost": 900, "desc": "Burns balls for 1 damage every 0.75s, 4 times.", "fx": [["=", "burn", 4]]},
			{"name": "Blast Burn", "cost": 3500, "desc": "Every 6s, a blast deals 10 damage to everything within 150.", "fx": [["=", "blast", 6]]}]},
	"squirtle": {"name": "Squirtle", "role": "Pusher", "type": "Water", "cost": 325,
		"blurb": "Water Gun knocks balls back down the path.",
		"base": {"range": 110, "rate": 0.85, "dmg": 1, "jets": 1, "push": 10, "bubble": false, "detect": false},
		"A": [
			{"name": "Evolve: Wartortle", "cost": 450, "desc": "+1 damage and pushes balls back twice as far.", "fx": [["+", "dmg", 1], ["+", "push", 10]]},
			{"name": "Evolve: Blastoise", "cost": 1400, "desc": "Shell cannons fire at 2 balls at once. +20 range.", "fx": [["=", "jets", 2], ["+", "range", 20]]},
			{"name": "Mega Blastoise", "cost": 4500, "desc": "Mega Launcher fires 3 jets, +2 damage, 30% faster.", "fx": [["=", "jets", 3], ["+", "dmg", 2], ["*", "rate", 0.7]]}],
		"B": [
			{"name": "Bubble Beam", "cost": 350, "desc": "Soaked balls move 40% slower for 1.5s.", "fx": [["=", "bubble", true]]},
			{"name": "Squirtle Squad Shades", "cost": 700, "desc": "+25 range and spots Dusk Balls. Also looks very cool.", "fx": [["+", "range", 25], ["=", "detect", true]]},
			{"name": "Hydro Pump", "cost": 3000, "desc": "Every 5s, a huge blast deals 8 damage to every ball in range and pushes them back.", "fx": [["=", "hydro", 5]]}]},
	"bulbasaur": {"name": "Bulbasaur", "role": "Line slicer", "type": "Grass", "cost": 350,
		"blurb": "Razor Leaf throws spinning leaves that slice through a line of balls.",
		"base": {"range": 115, "rate": 1.1, "dmg": 1, "leaves": 2, "pierce": 2, "detect": false},
		"A": [
			{"name": "Evolve: Ivysaur", "cost": 500, "desc": "+1 damage and throws 3 leaves.", "fx": [["+", "dmg", 1], ["=", "leaves", 3]]},
			{"name": "Evolve: Venusaur", "cost": 1500, "desc": "Throws 5 leaves that each slice 1 more ball. +15 range.", "fx": [["=", "leaves", 5], ["+", "pierce", 1], ["+", "range", 15]]},
			{"name": "Mega Venusaur", "cost": 4800, "desc": "+2 damage. Petal Blizzard hits every ball in range for 4 every 4s.", "fx": [["+", "dmg", 2], ["=", "blizzard", 4]]}],
		"B": [
			{"name": "Leech Seed", "cost": 400, "desc": "Seeded balls take 1 damage a second for 4s, and each drain earns ₽1.", "fx": [["=", "seed", true]]},
			{"name": "Sleep Powder", "cost": 900, "desc": "Every 5s, puts every ball in range to sleep for 1.2s. Master Balls resist.", "fx": [["=", "powder", 5]]},
			{"name": "Solar Beam", "cost": 3200, "desc": "Every 4s, fires a beam across the whole map, aimed to hit as many balls as possible. 12 damage to every ball it touches.", "fx": [["=", "solar", 4]]}]},
	"gastly": {"name": "Gastly", "role": "Hidden-ball finder", "type": "Ghost", "cost": 450,
		"blurb": "Shadow Balls explode on impact. Ghosts see hidden Dusk Balls.",
		"base": {"range": 132, "rate": 1.3, "dmg": 1, "radius": 32, "detect": true, "sleep": 0, "dream": 0, "pspeed": 420},
		"A": [
			{"name": "Evolve: Haunter", "cost": 600, "desc": "+1 damage, bigger blasts, 15% faster.", "fx": [["+", "dmg", 1], ["+", "radius", 10], ["*", "rate", 0.85]]},
			{"name": "Evolve: Gengar", "cost": 1500, "desc": "+2 damage, even bigger blasts, +20 range.", "fx": [["+", "dmg", 2], ["+", "radius", 12], ["+", "range", 20]]},
			{"name": "Mega Gengar", "cost": 4800, "desc": "+3 damage, 30% faster. Shadow Tag slows every ball in range by half.", "fx": [["+", "dmg", 3], ["*", "rate", 0.7], ["=", "tag", true]]}],
		"B": [
			{"name": "Hypnosis", "cost": 350, "desc": "Balls hit fall asleep for 0.8s. Master Balls never sleep.", "fx": [["=", "sleep", 0.8]]},
			{"name": "Dream Eater", "cost": 800, "desc": "+2 damage to sleeping balls and ₽1 extra per pop.", "fx": [["=", "dream", 2]]},
			{"name": "Nightmare", "cost": 2800, "desc": "Sleep lasts 1.4s. Sleeping balls in range take 2 damage every 0.5s.", "fx": [["=", "sleep", 1.4], ["=", "nightmare", true]]}]},
	"meowth": {"name": "Meowth", "role": "Money maker", "type": "Normal", "cost": 400,
		"blurb": "Quit Team Rocket. Pay Day earns ₽ at the end of every wave, and it scratches balls that get close.",
		"base": {"range": 72, "rate": 0.7, "dmg": 1, "swipes": 1, "pay": 40, "detect": false},
		"A": [
			{"name": "Evolve: Persian", "cost": 700, "desc": "+1 damage. Pay Day earns ₽80 a wave.", "fx": [["+", "dmg", 1], ["=", "pay", 80]]},
			{"name": "Amulet Coin", "cost": 1500, "desc": "Doubles Pay Day to ₽160 a wave.", "fx": [["*", "pay", 2]]},
			{"name": "Gold Rush", "cost": 5000, "desc": "Pay Day +₽40. Every 6s, coins rain on up to 30 balls for 4 damage each, and every coin that lands pays ₽1.", "fx": [["=", "goldRush", 6], ["+", "pay", 40]]}],
		"B": [
			{"name": "Fury Swipes", "cost": 300, "desc": "Scratches up to 3 balls per attack.", "fx": [["=", "swipes", 3]]},
			{"name": "Slash", "cost": 750, "desc": "+2 damage, 35% faster, +15 range.", "fx": [["+", "dmg", 2], ["*", "rate", 0.65], ["+", "range", 15]]},
			{"name": "Thief", "cost": 2200, "desc": "Old habits. Every ball Meowth pops pays ₽3 extra.", "fx": [["=", "thief", true]]}]},
	"wobbuffet": {"name": "Wobbuffet", "role": "Slows and counters", "type": "Psychic", "cost": 200, "pathNames": ["Abilities", "Counters"],
		"blurb": "Never attacks. It just keeps hurting itself in confusion. Its upgrades make that useful.",
		"base": {"range": 95, "rate": 0, "dmg": 0, "confuse": 3, "counter": 0, "bossMul": 1, "detect": true},
		"A": [
			{"name": "Shadow Tag", "cost": 350, "desc": "Balls in range move 35% slower.", "fx": [["=", "shadowTag", 0.65]]},
			{"name": "Mean Look", "cost": 800, "desc": "Balls in range move 55% slower, and Dusk Balls near it become visible to every Pokémon.", "fx": [["=", "shadowTag", 0.45], ["=", "reveal", true]]},
			{"name": "Encore", "cost": 2500, "desc": "Every 8s, sends every ball in range 150 steps back down the path.", "fx": [["=", "encore", 8]]}],
		"B": [
			{"name": "Counter", "cost": 400, "desc": "Each time it hurts itself, a shockwave deals 2 damage to balls in range.", "fx": [["=", "counter", 2]]},
			{"name": "Mirror Coat", "cost": 1000, "desc": "Shockwaves deal 5, and it gets confused every 2s.", "fx": [["=", "counter", 5], ["=", "confuse", 2]]},
			{"name": "Destiny Bond", "cost": 3000, "desc": "Shockwaves deal 12, and triple damage to Master Balls and the balloon.", "fx": [["=", "counter", 12], ["=", "bossMul", 3]]}]},
	"mewtwo": {"name": "Mewtwo", "role": "Legendary powerhouse", "type": "Psychic", "cost": 3000,
		"blurb": "Expensive and extremely strong. Psychic blasts hit 3 balls at once, including hidden and Heavy ones.",
		"base": {"range": 170, "rate": 0.5, "dmg": 3, "targets": 3, "bossMul": 1, "detect": true},
		"A": [
			{"name": "Mind Link", "cost": 1200, "desc": "+30 range and 20% faster.", "fx": [["+", "range", 30], ["*", "rate", 0.8]]},
			{"name": "Battle Armor", "cost": 3500, "desc": "+3 damage and triple damage to Master Balls and the balloon.", "fx": [["+", "dmg", 3], ["=", "bossMul", 3]]},
			{"name": "Mega Mewtwo Y", "cost": 9000, "desc": "Attacks twice as fast and hits 3 more balls.", "fx": [["*", "rate", 0.5], ["+", "targets", 3]]}],
		"B": [
			{"name": "Psychic", "cost": 1500, "desc": "+1 damage and hits 2 more balls.", "fx": [["+", "dmg", 1], ["+", "targets", 2]]},
			{"name": "Psystrike", "cost": 4000, "desc": "Every 5s, deals 10 damage to every ball in range.", "fx": [["=", "psystrike", 5]]},
			{"name": "Future Sight", "cost": 7500, "desc": "Every 6s, marks the strongest ball on the map. 2s later it takes 150 damage.", "fx": [["=", "future", 6]]}]},
	"magikarp": {"name": "Magikarp", "type": "Water", "cost": 150, "role": "Joke that pays off",
		"blurb": "Splash! But nothing happened. Evolve it into Gyarados and it becomes a monster.",
		"base": {"range": 90, "rate": 1.5, "dmg": 0, "area": 0, "splash": true, "detect": false},
		"A": [
			{"name": "Evolve: Gyarados", "cost": 800, "desc": "Huge water blasts: 3 damage to every ball near the target.", "fx": [["+", "dmg", 3], ["=", "range", 140], ["=", "rate", 0.75], ["=", "area", 40], ["=", "splash", false]]},
			{"name": "Intimidate", "cost": 1100, "desc": "Balls in range move 30% slower.", "fx": [["=", "shadowTag", 0.7]]},
			{"name": "Mega Gyarados", "cost": 4500, "desc": "+3 damage, 30% faster, bigger blasts, and sees Dusk Balls.", "fx": [["+", "dmg", 3], ["*", "rate", 0.7], ["+", "area", 20], ["=", "detect", true]]}],
		"B": [
			{"name": "Tackle", "cost": 100, "desc": "Finally does 1 damage.", "fx": [["+", "dmg", 1], ["=", "splash", false]]},
			{"name": "Flail", "cost": 600, "desc": "Up to +4 damage the lower Pikachu's HP is.", "fx": [["=", "flail", true]]},
			{"name": "Bounce", "cost": 2200, "desc": "Every 4s, lands on the toughest ball in range for 20 damage, and 6 to balls next to it.", "fx": [["=", "bounce", 4]]}]},
	"pidgey": {"name": "Pidgey", "type": "Flying", "cost": 300, "role": "Long-range sniper",
		"blurb": "Gusts of wind from very far away. Great for covering a long stretch of path.",
		"base": {"range": 230, "rate": 1.1, "dmg": 2, "pierce": 1, "push": 0, "brave": 0, "hurricane": 0, "detect": false},
		"A": [
			{"name": "Evolve: Pidgeotto", "cost": 450, "desc": "+40 range and sharp eyes that spot Dusk Balls.", "fx": [["+", "range", 40], ["=", "detect", true]]},
			{"name": "Evolve: Pidgeot", "cost": 1300, "desc": "+1 damage, and each gust slices through 3 balls.", "fx": [["+", "dmg", 1], ["=", "pierce", 3]]},
			{"name": "Mega Pidgeot", "cost": 4400, "desc": "+1 damage. Every 5s, Hurricane hits every ball in range for 6 and blows them back.", "fx": [["+", "dmg", 1], ["=", "hurricane", 5]]}],
		"B": [
			{"name": "Gust", "cost": 300, "desc": "Each hit knocks the ball back a little.", "fx": [["=", "push", 12]]},
			{"name": "Agility", "cost": 800, "desc": "Attacks 45% faster.", "fx": [["*", "rate", 0.55]]},
			{"name": "Brave Bird", "cost": 2800, "desc": "Every 3rd attack is a dive for 30 damage.", "fx": [["=", "brave", 30]]}]},
	"geodude": {"name": "Geodude", "type": "Rock", "cost": 400, "role": "Path trapper",
		"blurb": "Drops rocks on the path. Balls that roll over a rock take damage until it crumbles.",
		"base": {"range": 110, "rate": 1.8, "dmg": 1, "rocks": 1, "rockUses": 5, "throw": 0, "quake": 0, "explode": 0, "armorBreak": false, "detect": true},
		"A": [
			{"name": "Evolve: Graveler", "cost": 550, "desc": "Drops 2 rocks at a time, and they last longer.", "fx": [["=", "rocks", 2], ["+", "rockUses", 2]]},
			{"name": "Evolve: Golem", "cost": 1500, "desc": "+2 damage, and rocks crack Heavy Ball armour so Electric attacks work on them.", "fx": [["+", "dmg", 2], ["=", "armorBreak", true]]},
			{"name": "Explosion", "cost": 4000, "desc": "Every 8s, all its rocks blow up for 10 damage around them.", "fx": [["=", "explode", 8]]}],
		"B": [
			{"name": "Rock Throw", "cost": 400, "desc": "Also throws a rock at a ball for 2 damage.", "fx": [["=", "throw", 2]]},
			{"name": "Stealth Rock", "cost": 900, "desc": "+1 damage and rocks last 6 balls longer.", "fx": [["+", "dmg", 1], ["+", "rockUses", 6]]},
			{"name": "Earthquake", "cost": 2800, "desc": "Every 6s, 8 damage to every ball in a wide area.", "fx": [["=", "quake", 6]]}]},
	"machop": {"name": "Machop", "type": "Fighting", "cost": 425, "role": "Armour breaker",
		"blurb": "Close-range punches. Double damage to Heavy Balls, and knocks their armour off so Electric attacks work.",
		"base": {"range": 90, "rate": 0.7, "dmg": 2, "targets": 1, "push": 0, "chi": 0, "armorBreak": true, "detect": false},
		"A": [
			{"name": "Evolve: Machoke", "cost": 550, "desc": "+1 damage and +10 range.", "fx": [["+", "dmg", 1], ["+", "range", 10]]},
			{"name": "Evolve: Machamp", "cost": 1500, "desc": "+1 damage. Four arms punch 4 balls at once.", "fx": [["+", "dmg", 1], ["=", "targets", 4]]},
			{"name": "Gigantamax Machamp", "cost": 4600, "desc": "+2 damage. Every 10s, nearby Pokémon attack twice as fast for 4s.", "fx": [["+", "dmg", 2], ["=", "chi", 10]]}],
		"B": [
			{"name": "Karate Chop", "cost": 350, "desc": "Attacks 25% faster.", "fx": [["*", "rate", 0.75]]},
			{"name": "Cross Chop", "cost": 900, "desc": "+2 damage.", "fx": [["+", "dmg", 2]]},
			{"name": "Dynamic Punch", "cost": 2500, "desc": "+2 damage, and punched balls fly back down the path.", "fx": [["+", "dmg", 2], ["=", "push", 35]]}]},
	"abra": {"name": "Abra", "type": "Psychic", "cost": 500, "role": "Supporter",
		"blurb": "Barely attacks. Instead it makes the Pokémon around it stronger.",
		"base": {"range": 120, "rate": 1.4, "dmg": 1, "auraRate": 1.0, "auraDmg": 0, "auraRange": 1.0, "auraDetect": false, "trick": 0, "detect": true},
		"A": [
			{"name": "Evolve: Kadabra", "cost": 600, "desc": "Pokémon in its range attack 15% faster.", "fx": [["=", "auraRate", 1.15]]},
			{"name": "Evolve: Alakazam", "cost": 1800, "desc": "Pokémon in its range also deal +1 damage.", "fx": [["=", "auraDmg", 1]]},
			{"name": "Mega Alakazam", "cost": 5000, "desc": "Pokémon in its range attack 30% faster, get 15% more range and see Dusk Balls.", "fx": [["=", "auraRate", 1.3], ["=", "auraRange", 1.15], ["=", "auraDetect", true]]}],
		"B": [
			{"name": "Calm Mind", "cost": 400, "desc": "Its own attack is twice as fast and +1 damage.", "fx": [["*", "rate", 0.5], ["+", "dmg", 1]]},
			{"name": "Reflect", "cost": 900, "desc": "Balls in range move 30% slower.", "fx": [["=", "shadowTag", 0.7]]},
			{"name": "Trick Room", "cost": 3000, "desc": "Every 10s, every ball on the map moves at half speed for 3s.", "fx": [["=", "trick", 10]]}]},
	"lapras": {"name": "Lapras", "type": "Ice", "cost": 600, "role": "Freezer",
		"blurb": "Icy blasts freeze a small group of balls solid for a moment. Big balls thaw faster.",
		"base": {"range": 125, "rate": 0.9, "dmg": 1, "freeze": .5, "area": 30, "gfreeze": 0, "surf": 0, "brittle": false, "cold": 0, "detect": false},
		"A": [
			{"name": "Ice Beam", "cost": 500, "desc": "+1 damage and freezes for twice as long.", "fx": [["+", "dmg", 1], ["=", "freeze", 1.0]]},
			{"name": "Blizzard", "cost": 1400, "desc": "+1 damage and freezes a much wider area around the target.", "fx": [["=", "area", 65], ["+", "dmg", 1]]},
			{"name": "Gigantamax Lapras", "cost": 5200, "desc": "Every 12s, freezes every ball on the map for 2s.", "fx": [["=", "gfreeze", 12]]}],
		"B": [
			{"name": "Surf", "cost": 500, "desc": "Every 5s, a wave hits balls in range for 2 and pushes them back.", "fx": [["=", "surf", 5]]},
			{"name": "Freeze-Dry", "cost": 1100, "desc": "Frozen balls take +2 damage from every attack.", "fx": [["=", "brittle", true]]},
			{"name": "Sheer Cold", "cost": 3200, "desc": "Every 8s, instantly pops the toughest normal ball in range, all its layers at once.", "fx": [["=", "cold", 8]]}]},
	"snorlax": {"name": "Snorlax", "type": "Normal", "cost": 800, "role": "Roadblock", "onPath": true,
		"blurb": "Goes ON the path and blocks it. Balls pile up until they push it aside, then it naps and comes back.",
		"base": {"range": 55, "hold": 30, "recover": 6, "slam": 0, "slamDmg": 2, "yawn": 0, "detect": true},
		"A": [
			{"name": "Thick Fat", "cost": 600, "desc": "Holds back balls more than twice as long.", "fx": [["=", "hold", 70]]},
			{"name": "Rest", "cost": 1200, "desc": "Wakes back up in 3s instead of 6.", "fx": [["=", "recover", 3]]},
			{"name": "Gigantamax Snorlax", "cost": 5000, "desc": "Holds 3 times longer still, and balls near it move 40% slower.", "fx": [["=", "hold", 200], ["=", "shadowTag", 0.6], ["=", "range", 80]]}],
		"B": [
			{"name": "Body Slam", "cost": 500, "desc": "Every 1.2s, 2 damage to every ball next to it.", "fx": [["=", "slam", 1.2]]},
			{"name": "Yawn", "cost": 900, "desc": "Every 3s, balls next to it fall asleep for 1s.", "fx": [["=", "yawn", 3]]},
			{"name": "Belly Drum", "cost": 2600, "desc": "Body Slam does triple damage.", "fx": [["=", "slamDmg", 6]]}]},
	"dratini": {"name": "Dratini", "type": "Dragon", "cost": 750, "role": "Boss hunter",
		"blurb": "Dragon breath that hits Master Balls and the Meowth balloon twice as hard.",
		"base": {"range": 140, "rate": 0.8, "dmg": 3, "bossMul": 2, "rage": 0, "dance": false, "outrage": 0, "hyper": 0, "detect": false},
		"A": [
			{"name": "Evolve: Dragonair", "cost": 700, "desc": "+2 damage and +20 range.", "fx": [["+", "dmg", 2], ["+", "range", 20]]},
			{"name": "Evolve: Dragonite", "cost": 2000, "desc": "+2 damage, +30 range, and flies high enough to see Dusk Balls.", "fx": [["+", "dmg", 2], ["+", "range", 30], ["=", "detect", true]]},
			{"name": "Outrage", "cost": 5500, "desc": "Every 15s, attacks 3 times as fast for 5s.", "fx": [["=", "outrage", 15]]}],
		"B": [
			{"name": "Dragon Rage", "cost": 800, "desc": "Every hit on a Master Ball or the balloon deals 20 extra.", "fx": [["=", "rage", 20]]},
			{"name": "Dragon Dance", "cost": 1500, "desc": "Attacks 10% faster for every wave it survives, up to 60%.", "fx": [["=", "dance", true]]},
			{"name": "Hyper Beam", "cost": 4200, "desc": "Every 6s, a beam through the toughest ball deals 30 to everything in its line.", "fx": [["=", "hyper", 6]]}]},
}
const KINDS := ["pikachu", "charmander", "squirtle", "bulbasaur", "gastly", "meowth", "wobbuffet", "magikarp", "pidgey", "geodude", "machop", "abra", "lapras", "snorlax", "dratini", "mewtwo"]

const TYPE_COLORS := {
	"Electric": "#f7d02c", "Fire": "#f08030", "Ghost": "#9a7ad6", "Water": "#5aa8f0",
	"Grass": "#78c850", "Normal": "#d8cfa8", "Psychic": "#f37ab0", "Flying": "#a99cf0",
	"Fighting": "#e0603c", "Ice": "#98d8e0", "Rock": "#c8b060", "Dragon": "#8a68f8",
}

## Every stat a tower can have, so missing ones read as "off".
const STAT_DEFAULTS := {
	"range": 0.0, "rate": 0.0, "dmg": 0.0, "detect": false, "chain": 0, "gmax": 0.0, "thunder": false,
	"pierce": 0, "cone": 0.0, "burn": 0, "burnMul": 1.0, "blast": 0.0, "radius": 0.0, "sleep": 0.0,
	"dream": 0.0, "pspeed": 0.0, "tag": false, "nightmare": false, "jets": 0, "push": 0.0, "bubble": false,
	"hydro": 0.0, "leaves": 0, "blizzard": 0.0, "seed": false, "powder": 0.0, "solar": 0.0, "swipes": 0,
	"pay": 0, "goldRush": 0.0, "thief": false, "confuse": 0.0, "counter": 0.0, "bossMul": 1.0,
	"shadowTag": 0.0, "reveal": false, "encore": 0.0, "targets": 0, "psystrike": 0.0, "future": 0.0,
	"area": 0.0, "splash": false, "flail": false, "bounce": 0.0, "brave": 0, "hurricane": 0.0,
	"rocks": 0, "rockUses": 0, "throw": 0, "quake": 0.0, "explode": 0.0, "armorBreak": false, "chi": 0.0,
	"auraRate": 1.0, "auraDmg": 0, "auraRange": 1.0, "auraDetect": false, "trick": 0.0, "freeze": 0.0,
	"gfreeze": 0.0, "surf": 0.0, "brittle": false, "cold": 0.0, "hold": 0.0, "recover": 0.0, "slam": 0.0,
	"slamDmg": 0.0, "yawn": 0.0, "rage": 0.0, "dance": false, "outrage": 0.0, "hyper": 0.0,
}

const MAPS := [
	{"id": "route1", "name": "Route 1", "sub": "Pallet Town to Viridian City", "diff": "Easy", "lives": 150, "cash": 750, "theme": "route",
		"path": [[120, 640], [120, 430], [360, 430], [360, 540], [620, 540], [620, 360], [820, 360], [820, 180], [560, 180], [560, 300], [300, 300], [300, 90], [680, 90], [680, -40]]},
	{"id": "forest", "name": "Viridian Forest", "sub": "Watch out for Bug Catchers", "diff": "Medium", "lives": 100, "cash": 750, "theme": "forest",
		"path": [[-40, 110], [200, 110], [200, 490], [420, 490], [420, 210], [640, 210], [640, 480], [850, 480], [850, -40]]},
	{"id": "lavender", "name": "Lavender Town", "sub": "In the shadow of Pokémon Tower", "diff": "Hard", "lives": 75, "cash": 750, "theme": "lavender",
		"path": [[480, -40], [480, 140], [190, 140], [190, 460], [760, 460], [760, 270], [1000, 270]]},
	{"id": "mtmoon", "name": "Mt. Moon", "sub": "Short tunnels, no room for error", "diff": "Expert", "lives": 50, "cash": 750, "theme": "cave",
		"path": [[-40, 300], [290, 300], [290, 120], [630, 120], [630, 470], [1000, 470]]},
]

const DIFF_COLORS := {"Easy": "#5fd38a", "Medium": "#ffd23f", "Hard": "#ff9a4a", "Expert": "#ff6b6b"}

const WAVES := [null,
	[["poke", 20, .8]],
	[["poke", 32, .6]],
	[["poke", 22, .5], ["great", 8, .9]],
	[["poke", 26, .42], ["great", 16, .7]],
	[["great", 26, .55], ["poke", 12, .35]],
	[["poke", 16, .4], ["great", 18, .55], ["ultra", 6, 1]],
	[["great", 26, .45], ["ultra", 12, .75]],
	[["poke", 24, .3], ["great", 22, .38], ["ultra", 15, .6]],
	[["ultra", 32, .48]],
	[["great", 70, .22]],
	[["ultra", 24, .45], ["quick", 6, .9], ["timer", 4, 1.0]],
	[["great", 32, .28], ["ultra", 22, .38], ["quick", 10, .7]],
	[["quick", 22, .55], ["ultra", 26, .36]],
	[["dusk", 6, 1.2], ["ultra", 32, .32]],
	[["quick", 36, .38], ["dusk", 8, 1], ["timer", 8, .7]],
	[["ultra", 64, .18], ["dusk", 12, .7]],
	[["heavy", 6, 1.4], ["quick", 32, .33]],
	[["dusk", 20, .5], ["heavy", 8, 1.1], ["net", 6, .9]],
	[["quick", 64, .18], ["heavy", 12, .8]],
	[["dusk", 26, .4], ["heavy", 15, .7], ["ultra", 44, .18]],
	[["heavy", 26, .55], ["quick", 44, .22], ["heal", 5, 1.0]],
	[["dusk", 44, .32]],
	[["heavy", 32, .42], ["dusk", 22, .48], ["net", 12, .5]],
	[["quick", 110, .11], ["heavy", 22, .48]],
	[["master", 1, 1], ["dusk", 22, .5]],
	[["heavy", 46, .33], ["dusk", 32, .38], ["heal", 10, .7]],
	[["dusk", 64, .24], ["quick", 64, .14]],
	[["master", 1, 1], ["heavy", 36, .4]],
	[["heavy", 64, .23], ["dusk", 44, .28], ["timer", 24, .3]],
	[["master", 2, 5], ["dusk", 44, .28]],
]

## Red-ball equivalents: how many lives a ball costs if it leaks.
static var RBE := {}


static func rbe(t: String) -> int:
	if RBE.has(t):
		return RBE[t]
	var b: Dictionary = BALLS[t]
	var n := 20 if b.get("boss", false) else 1
	for k in b.kids:
		n += rbe(k)
	RBE[t] = n
	return n


static func wave_groups(n: int) -> Array:
	if n < WAVES.size():
		return WAVES[n]
	if n == 40:
		return [["heavy", 40, .3], ["dusk", 40, .3], ["master", 1, 1], ["rocket", 1, 1]]
	var k := n - 30
	var gap := maxf(.1, .26 - k * .012)
	var masters: int = 2 + int(floor((n - 40) / 2.0)) if n > 40 else 1 + int(floor(k / 4.0))
	var g: Array = [["heavy", 50 + k * 6, gap], ["dusk", 50 + k * 6, gap], ["net", 6 + k * 2, gap * 2], ["heal", 4 + k, gap * 3], ["master", masters, maxf(1.5, 4 - k * .2)]]
	if n > 40 and n % 5 == 0:
		g.append(["rocket", int(floor((n - 40) / 5.0)), 8])
	return g


static func make_wave(n: int) -> Array:
	var ev: Array = []
	var start := 0.0
	for grp in wave_groups(n):
		var count: int = grp[1]
		var gap: float = grp[2]
		for i in count:
			ev.append({"t": start + i * gap, "type": grp[0]})
		start += count * gap * .55
	return stable_sort(ev, func(a, b): return a.t < b.t)


## Sorts like JavaScript's Array.sort: items that compare equal keep their order.
static func stable_sort(arr: Array, less: Callable) -> Array:
	var dec: Array = []
	for i in arr.size():
		dec.append([arr[i], i])
	dec.sort_custom(func(a, b):
		if less.call(a[0], b[0]):
			return true
		if less.call(b[0], a[0]):
			return false
		return a[1] < b[1])
	var out: Array = []
	for e in dec:
		out.append(e[0])
	return out


static func master_hp(n: int) -> int:
	return int(round(260 * (1 + maxf(0, n - 25) * .08)))


static func rocket_hp(n: int) -> int:
	return int(round(1500 * (1 + maxf(0, n - 40) * .12)))


static func compute_stats(kind: String, a: int, b: int) -> Dictionary:
	var d: Dictionary = TOWERS[kind]
	var s := STAT_DEFAULTS.duplicate()
	for k in d.base:
		s[k] = d.base[k]
	for i in a:
		_apply(s, d.A[i].fx)
	for i in b:
		_apply(s, d.B[i].fx)
	return s


static func _apply(s: Dictionary, fx: Array) -> void:
	for e in fx:
		match e[0]:
			"+": s[e[1]] += e[2]
			"*": s[e[1]] *= e[2]
			"=": s[e[1]] = e[2]


static func sprite_for(kind: String, a: int) -> String:
	match kind:
		"pikachu": return "gmax" if a >= 3 else ("raichu" if a >= 1 else "pikachu")
		"charmander": return ["charmander", "charmeleon", "charizard", "megax"][a]
		"gastly": return ["gastly", "haunter", "gengar", "megagengar"][a]
		"squirtle": return ["squirtle", "wartortle", "blastoise", "megablastoise"][a]
		"bulbasaur": return ["bulbasaur", "ivysaur", "venusaur", "megavenusaur"][a]
		"meowth": return "persian" if a >= 1 else "meowth"
		"wobbuffet": return "wobbuffet"
		"mewtwo": return "megamewtwo" if a >= 3 else ("armormewtwo" if a >= 2 else "mewtwo")
		"magikarp": return "megagyarados" if a >= 3 else ("gyarados" if a >= 1 else "magikarp")
		"pidgey": return ["pidgey", "pidgeotto", "pidgeot", "megapidgeot"][a]
		"geodude": return ["geodude", "graveler", "golem", "golem"][a]
		"machop": return ["machop", "machoke", "machamp", "gmaxmachamp"][a]
		"abra": return ["abra", "kadabra", "alakazam", "megaalakazam"][a]
		"lapras": return "gmaxlapras" if a >= 3 else "lapras"
		"snorlax": return "gmaxsnorlax" if a >= 3 else "snorlax"
		"dratini": return ["dratini", "dragonair", "dragonite", "dragonite"][a]
	return kind


## Damage multiplier for an attack of this type against this ball.
static func type_mul(type: String, ball: String) -> float:
	return TYPE_EFFECT.get(type, {}).get(ball, 1.0)


static func best_key(map_id: String, diff: String) -> String:
	return map_id if diff == "normal" else "%s:%s" % [map_id, diff]


static func path_names(kind: String) -> Array:
	return TOWERS[kind].get("pathNames", ["Evolution", "Moves"])


# ---------- seeded random (same sequence as the web version) ----------
const M32 := 0xFFFFFFFF


static func imul(x: int, y: int) -> int:
	x &= M32
	y &= M32
	return ((x * (y & 0xFFFF)) + (((x * (y >> 16)) & 0xFFFF) << 16)) & M32


static func hash_str(s: String) -> int:
	var h := 2166136261
	for i in s.length():
		h ^= s.unicode_at(i)
		h = imul(h, 16777619)
	return h & M32


class Rng:
	var a: int

	func _init(seed_value: int) -> void:
		a = seed_value & Data.M32

	func next() -> float:
		a = (a + 0x6D2B79F5) & Data.M32
		var t := Data.imul(a ^ (a >> 15), a | 1)
		t = ((t + Data.imul(t ^ (t >> 7), t | 61)) & Data.M32) ^ t
		return float((t ^ (t >> 14)) & Data.M32) / 4294967296.0
