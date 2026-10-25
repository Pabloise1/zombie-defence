class_name Defs
extends RefCounted
const CELL := 2.0
const W := 97
const H := 97
const HALF := W * CELL * 0.5
const NAV := 1.0
const NW := 194
const NH := 194
const TRENCH_DEPTH := 1.5
const HQ_ORIGIN := Vector2i(47, 47)
const HQ_SIZE := 3
const START_SUPPLIES := 800
const BUILD_PHASE_TIME := 45.0
const FIRST_BUILD_PHASE_TIME := 120.0
const MAX_ALIVE := 640
const START_PEOPLE := 5
const START_WORKERS := 3
const PERSON_HP := 50.0
const SOLDIER_ARM_COST := 40
const SOLDIER_ARM_COST_BARRACKS := 20
const JOBS := ["worker", "soldier", "loader", "fetcher", "crafter"]
const POP_BASE := 10
const JOB_NAMES := {"worker": "Workers", "soldier": "Soldiers", "loader": "Loaders", "fetcher": "Fetchers", "crafter": "Crafters"}
const START_CRATES := 6
const HQ_STORE := 10
const CRATE_COST := 15
const CRAFT_TIME := 8.0
const CRAFTERS_PER_WORKSHOP := 2
const FETCH_LOAD := 25
const FETCH_FIND := 0.2
const SALVAGE_SCRAP := 120
const FUEL_RANGE := 14.0
const RADIO_GROUPS := 1
const MOUNTABLE := ["turret", "sniper", "mortar", "flame", "cannon"]
const PORT_BONUS := 0.25
const PORT_GUARD := 0.5
const MOVE_COST := 0.25
const WALL_MIN_SEG := 1.5
const WALL_PIECE := 2.0
const WALL_JOB_MAX := 4.0
const GATE_WIDTH := 4.0
const T_GROUND := 0
const T_TRENCH := 1
const T_ROCK := 2
const T_TUNNEL := 3
const BUILD := {
	"turret": {
		"name": "MG", "long": "MG Turret", "cost": 130, "time": 6.0, "hp": 260.0, "blocks": true, "zcost": 10.0,
		"ground": true, "trench": false, "line": false, "model": "turret_mg",
		"mag": 60, "reload": 3.0, "reserve": 240,
		"hint": "Tap to place a machine gun", "about": "Fast fire, mid range",
	},
	"cannon": {
		"name": "Cannon", "long": "Autocannon", "cost": 180, "time": 7.0, "hp": 320.0, "blocks": true, "zcost": 10.0,
		"ground": true, "trench": false, "line": false, "model": "autocannon", "unlock": 4,
		"mag": 12, "reload": 4.0, "reserve": 72,
		"hint": "Tap to place an autocannon", "about": "Heavy shells that burst  ·  brutes first",
	},
	"mortar": {
		"name": "Mortar", "long": "Mortar Pit", "cost": 155, "time": 7.0, "hp": 200.0, "blocks": true, "zcost": 10.0,
		"ground": true, "trench": false, "line": false, "model": "mortar_pit", "unlock": 3,
		"mag": 4, "reload": 5.0, "reserve": 24,
		"hint": "Tap to place. Long range, can't hit close", "about": "Shells crowds far away",
	},
	"sniper": {
		"name": "Sniper", "long": "Sniper Tower", "cost": 130, "time": 6.0, "hp": 160.0, "blocks": true, "zcost": 10.0,
		"ground": true, "trench": false, "line": false, "model": "sniper_tower", "capacity": 1,
		"mag": 5, "reload": 3.5, "reserve": 40,
		"hint": "Tap to place. Needs 1 soldier", "about": "Picks off brutes first",
	},
	"flame": {
		"name": "Flame", "long": "Flame Bunker", "cost": 205, "time": 7.0, "hp": 280.0, "blocks": true, "zcost": 12.0,
		"ground": true, "trench": false, "line": false, "model": "flame_bunker", "unlock": 5,
		"mag": 40, "reload": 5.0, "reserve": 300,
		"hint": "Tap to place. Short range, sets them alight", "about": "Burns everything close",
	},
	"concrete": {
		"name": "Concrete", "long": "Concrete Wall", "per_m": 14, "cost": 28, "time_per_m": 3.0, "hp_per_m": 1600.0,
		"blocks": true, "linear": true, "thick": 0.8, "height": 3.5, "model": "concrete_wall", "post": "wall_post_concrete",
		"port_model": "concrete_wall_port", "port_cost": 30, "slot_bonus": 0.35, "bastion": "bastion_c",
		"hint": "Tap points to draw. Tap the start to close", "about": "Tall and very tough",
	},
	"wall": {
		"name": "Wood", "long": "Wooden Wall", "per_m": 5, "cost": 10, "time_per_m": 1.0, "hp_per_m": 300.0,
		"blocks": true, "linear": true, "thick": 0.6, "height": 2.2, "model": "wall", "post": "wall_post_wood",
		"port_model": "wall_port_wood", "port_cost": 18, "slot_bonus": 0.25, "bastion": "bastion",
		"hint": "Tap points to draw. Tap the start to close", "about": "Cheap. Zombies must break it",
	},
	"fortified": {
		"name": "Fortified", "long": "Fortified Wall", "per_m": 20, "time_per_m": 3.0, "hp_per_m": 3800.0,
		"blocks": true, "linear": true, "thick": 1.1, "height": 5.0, "model": "fortified_wall", "post": "fortified_post",
		"port_model": "fortified_wall_port", "port_cost": 36, "slot_bonus": 0.5, "bastion": "bastion_c", "card_only": true,
		"unlock": 5, "nest_h": 3.7, "nest_in": 0.55, "walk": true, "walk_bonus": 0.4,
		"about": "5 m tall, a walkway for soldiers and guns",
	},
	"gate": {
		"name": "Gate", "long": "Gate", "cost": 50, "time": 8.0, "hp": 4000.0, "blocks": true, "linear": true,
		"thick": 0.8, "height": 3.5, "model": "concrete_gate",
		"hint": "Tap a wall to put a gate in it", "about": "Opens for people, not zombies",
	},
	"wire": {
		"name": "Wire", "long": "Barbed Wire", "cost": 10, "time": 1.5, "hp": 120.0, "blocks": false, "zcost": 4.0,
		"ground": true, "trench": true, "line": true, "model": "barbed_wire",
		"hint": "Drag to lay wire", "about": "Slows zombies, wears out",
	},
	"garrison": {
		"name": "Bunker", "long": "Garrison Bunker", "cost": 185, "time": 10.0, "hp": 1400.0, "blocks": true, "zcost": 16.0,
		"ground": true, "trench": false, "line": false, "model": "garrison_bunker", "capacity": 4, "size": 2,
		"mag": 120, "reload": 4.0, "reserve": 600,
		"hint": "Tap to place. Holds 4 soldiers", "about": "Soldiers shoot from the slots",
	},
	"platform": {
		"name": "Platform", "long": "Gun Platform", "cost": 30, "time": 5.0, "hp": 450.0, "blocks": true, "zcost": 8.0,
		"ground": true, "trench": false, "line": false, "model": "gun_platform", "slot_bonus": 0.25,
		"hint": "Tap to place, then tap it to put a gun on top", "about": "Raised gun slot  ·  +25% range",
	},
	"house": {
		"name": "House", "long": "House", "cost": 140, "time": 24.0, "hp": 3200.0, "blocks": true, "zcost": 6.0,
		"prefab": true, "half": Vector2(2, 2), "model": "house", "capacity": 4, "pop": 6, "slot_bonus": 0.45,
		"hint": "Drag it, turn the handle, then tick", "about": "+6 people  ·  2 roof gun slots",
	},
	"depot": {
		"name": "Depot", "long": "Depot", "cost": 115, "time": 22.0, "hp": 3600.0, "blocks": true, "zcost": 6.0,
		"prefab": true, "half": Vector2(3, 2), "model": "depot", "capacity": 3, "store": 40, "slot_bonus": 0.3,
		"hint": "Drag it, turn the handle, then tick", "about": "Stores 40 ammo crates",
	},
	"workshop": {
		"name": "Workshop", "long": "Workshop", "cost": 125, "time": 22.0, "hp": 3000.0, "blocks": true, "zcost": 6.0,
		"prefab": true, "half": Vector2(3, 2), "model": "workshop", "capacity": 2, "slot_bonus": 0.3,
		"hint": "Drag it, turn the handle, then tick", "about": "Crafters turn supplies into ammo",
	},
	"barracks": {
		"name": "Barracks", "long": "Barracks", "cost": 165, "time": 26.0, "hp": 4200.0, "blocks": true, "zcost": 6.0,
		"prefab": true, "half": Vector2(3, 2), "model": "barracks", "capacity": 6, "pop": 4, "slot_bonus": 0.3,
		"hint": "Drag it, turn the handle, then tick", "about": "+4 people  ·  soldiers heal here",
	},
	"watchtower": {
		"name": "Tower", "long": "Concrete Watchtower", "cost": 105, "time": 18.0, "hp": 2600.0, "blocks": true, "zcost": 6.0,
		"prefab": true, "half": Vector2(1, 1), "model": "watchtower_concrete", "capacity": 3, "slot_bonus": 0.7,
		"hint": "Drag it, turn the handle, then tick", "about": "Tall: big range for its roof gun",
	},
	"room_block": {
		"name": "Block", "long": "Room Block", "cost": 140, "time": 18.0, "hp": 3000.0, "blocks": true, "zcost": 6.0,
		"prefab": true, "half": Vector2(2, 2), "model": "room_block", "capacity": 4, "pop": 3, "slot_bonus": 0.4,
		"floor_cost": 100, "floor_time": 16.0, "max_floors": 4, "unlock": 3,
		"hint": "Drag it, turn the handle, then tick", "about": "Stack it up to 4 storeys  ·  windows for soldiers",
	},
	"stairs": {
		"name": "Stairs", "long": "Stair Tower", "cost": 55, "time": 8.0, "hp": 1400.0, "blocks": true, "zcost": 6.0,
		"prefab": true, "half": Vector2(1.1, 1.1), "model": "stairs_tower", "unlock": 3,
		"hint": "Put it beside a roof or a fortified wall", "about": "The way up to roofs and walkways",
	},
	"bridge": {
		"name": "Bridge", "long": "Roof Bridge", "per_m": 9, "time_per_m": 1.0, "hp": 0.0, "blocks": false, "zcost": 1.0,
		"model": "roof_bridge", "unlock": 3, "max_len": 16.0,
		"hint": "Tap a roof, walkway or stair top, then another", "about": "Links roofs, walls and stairs up high",
	},
	"helipad": {
		"name": "Helipad", "long": "Helipad", "cost": 250, "time": 24.0, "hp": 2600.0, "blocks": true, "zcost": 6.0,
		"prefab": true, "half": Vector2(3, 3), "model": "helipad", "unlock": 5, "heli": "huey", "heli_cost": 255,
		"hint": "Drag it, turn the handle, then tick", "about": "Buy a Huey here: rescue, patrol, resupply",
	},
	"helipad_large": {
		"name": "Big Pad", "long": "Large Helipad", "cost": 440, "time": 34.0, "hp": 4200.0, "blocks": true, "zcost": 6.0,
		"prefab": true, "half": Vector2(6, 6), "model": "helipad_large", "unlock": 7, "heli": "mi8", "heli_cost": 470,
		"hint": "Drag it, turn the handle, then tick", "about": "Buy the Mi-8 here: carries twice as much",
	},
	"ammo_point": {
		"name": "Ammo Pt", "long": "Ammo Point", "cost": 25, "time": 3.0, "hp": 150.0, "blocks": true, "zcost": 4.0,
		"ground": true, "trench": false, "line": false, "model": "ammo_point", "store": 8,
		"hint": "Tap to place a crate stash near your guns", "about": "Holds 8 crates. Shorter loader trips",
	},
	"radio": {
		"name": "Radio", "long": "Radio Mast", "cost": 75, "time": 8.0, "hp": 220.0, "blocks": true, "zcost": 4.0,
		"ground": true, "trench": false, "line": false, "model": "radio_mast",
		"hint": "Tap to place a radio mast", "about": "More survivors come each wave",
	},
	"fuel": {
		"name": "Fuel", "long": "Fuel Tank", "cost": 40, "time": 4.0, "hp": 140.0, "blocks": true, "zcost": 4.0,
		"ground": true, "trench": false, "line": false, "model": "fuel_tank",
		"hint": "Tap to place. Flame bunkers within 14 m can fire", "about": "Feeds flame bunkers. Explodes if hit hard",
	},
	"bastion": {
		"name": "Bastion", "long": "Wood Bastion", "cost": 100, "time": 14.0, "hp": 2400.0, "blocks": true, "zcost": 6.0,
		"prefab": true, "half": Vector2(1.5, 1.2), "model": "bastion_wood", "capacity": 2, "slot_bonus": 0.35, "card_only": true,
		"about": "1 gun on top  ·  2 soldier ports",
	},
	"bastion_c": {
		"name": "Bastion", "long": "Concrete Bastion", "cost": 185, "time": 24.0, "hp": 6500.0, "blocks": true, "zcost": 6.0,
		"prefab": true, "half": Vector2(1.5, 1.3), "model": "bastion_concrete", "capacity": 2, "slot_bonus": 0.45, "card_only": true,
		"about": "1 gun on top  ·  2 soldier ports",
	},
	"fence": {
		"name": "Fence", "long": "Garden Fence", "per_m": 4, "claim_per_m": 1.2, "time_per_m": 0.4, "hp_per_m": 90.0,
		"blocks": true, "linear": true, "thick": 0.3, "height": 1.85, "model": "suburb/fence_wood", "slot_bonus": 0.15,
		"bastion": "bastion", "card_only": true, "about": "Weak, but it's a wall",
	},
	"picket": {
		"name": "Picket", "long": "Picket Fence", "per_m": 3, "claim_per_m": 1.2, "time_per_m": 0.4, "hp_per_m": 70.0,
		"blocks": true, "linear": true, "thick": 0.25, "height": 1.1, "model": "suburb/fence_picket", "slot_bonus": 0.1,
		"bastion": "bastion", "card_only": true, "about": "The weakest fence",
	},
	"hedge": {
		"name": "Hedge", "long": "Hedge", "per_m": 4, "claim_per_m": 1.8, "time_per_m": 0.5, "hp_per_m": 150.0,
		"blocks": true, "linear": true, "thick": 0.9, "height": 1.6, "model": "suburb/hedge", "slot_bonus": 0.12,
		"bastion": "bastion", "card_only": true, "about": "Thick and thorny",
	},
	"brickwall": {
		"name": "Garden Wall", "long": "Garden Wall", "per_m": 6, "claim_per_m": 2.5, "time_per_m": 0.6, "hp_per_m": 240.0,
		"blocks": true, "linear": true, "thick": 0.35, "height": 1.0, "model": "suburb/garden_wall_brick", "slot_bonus": 0.1,
		"bastion": "bastion", "card_only": true, "about": "Low brick wall. The toughest garden boundary",
	},
	"nest": {
		"name": "Nest", "long": "Wall Nest", "cost": 25, "time": 4.0, "hp": 0.0, "blocks": false, "zcost": 1.0,
		"model": "wall_mount_nest", "card_only": true, "about": "Sandbag nest on the wall top",
	},
	"spikes": {
		"name": "Spikes", "long": "Spike Trap", "cost": 40, "time": 3.0, "hp": 0.0, "blocks": false, "zcost": 1.0,
		"ground": true, "trench": true, "line": false, "model": "spike_trap",
		"hint": "Tap to place. Double damage in a trench", "about": "Hurts all on it",
	},
	"mine": {
		"name": "Mine", "long": "Mine", "cost": 35, "time": 2.5, "hp": 0.0, "blocks": false, "zcost": 1.0,
		"ground": true, "trench": true, "line": false, "model": "mine",
		"hint": "Tap to place a mine", "about": "One big blast",
	},
	"dig": {
		"name": "Dig", "long": "Trench", "cost": 5, "time": 3.0, "hp": 0.0, "blocks": false, "zcost": 1.0,
		"ground": true, "trench": false, "line": true, "model": "",
		"hint": "Drag to mark a trench", "about": "Zombies fall in, climb out slowly",
	},
	"car_wreck": {
		"name": "Car", "long": "Car Wreck", "cost": 35, "time": 6.0, "hp": 1500.0, "blocks": true, "zcost": 6.0,
		"prefab": true, "half": Vector2(1.0, 2.45), "model": "suburb/car_sedan_wreck",
		"hint": "Drag it, turn the handle, then tick", "about": "Junk barricade. Plug a gap or wall in with cars",
	},
	"van_wreck": {
		"name": "Van", "long": "Van Wreck", "cost": 55, "time": 8.0, "hp": 2400.0, "blocks": true, "zcost": 6.0,
		"prefab": true, "half": Vector2(1.49, 3.25), "model": "suburb/van_wreck",
		"hint": "Drag it, turn the handle, then tick", "about": "Heavier junk barricade",
	},
	"bus_wreck": {
		"name": "Bus", "long": "School Bus Wreck", "cost": 120, "time": 14.0, "hp": 6000.0, "blocks": true, "zcost": 6.0,
		"prefab": true, "half": Vector2(1.54, 6.3), "model": "suburb/school_bus_wreck", "unlock": 3,
		"hint": "Drag it, turn the handle, then tick", "about": "12 m of steel. A wall in one go",
	},
	"decoy": {
		"name": "Decoy", "long": "Noise Decoy", "cost": 60, "time": 5.0, "hp": 1200.0, "blocks": true, "zcost": 6.0,
		"ground": true, "trench": false, "line": false, "model": "decoy", "unlock": 3, "lure": 30.0,
		"hint": "Tap to place. Zombies go for it first", "about": "Lures the horde. Ring it with mines",
	},
	"greenhouse": {
		"name": "Farm", "long": "Greenhouse", "cost": 150, "time": 20.0, "hp": 1800.0, "blocks": true, "zcost": 6.0,
		"prefab": true, "half": Vector2(2.5, 1.5), "model": "greenhouse", "unlock": 2, "income": 45,
		"hint": "Drag it, turn the handle, then tick", "about": "+45 supplies after every wave it survives",
	},
	"clinic": {
		"name": "Clinic", "long": "Clinic", "cost": 130, "time": 20.0, "hp": 2600.0, "blocks": true, "zcost": 6.0,
		"prefab": true, "half": Vector2(2.0, 1.5), "model": "clinic", "unlock": 3, "heal": 5.0, "heal_range": 14.0,
		"hint": "Drag it, turn the handle, then tick", "about": "Heals everyone within 14 m",
	},
	"fort_wood": {
		"name": "Wood Fort", "long": "Wooden Fort Module", "cost": 25, "time": 4.0, "hp": 700.0, "hp_per_level": 700.0,
		"raise_cost": 30, "raise_time": 6.0, "max_levels": 4, "blocks": true, "zcost": 6.0, "hide_inside": true,
		"ground": true, "trench": false, "line": true, "model": "fort_wood", "slot_bonus": 0.15,
		"hint": "Drag to lay a row. Tap one to add floors", "about": "Joins its neighbours  ·  up to 4 floors  ·  gun on the roof",
	},
	"fort_concrete": {
		"name": "Concrete", "long": "Concrete Fort Module", "cost": 45, "time": 7.0, "hp": 1600.0, "hp_per_level": 1600.0,
		"raise_cost": 55, "raise_time": 10.0, "max_levels": 4, "blocks": true, "zcost": 6.0, "hide_inside": true, "unlock": 3,
		"ground": true, "trench": false, "line": true, "model": "fort_concrete", "slot_bonus": 0.15,
		"hint": "Drag to lay a row. Tap one to add floors", "about": "Joins its neighbours  ·  up to 4 floors  ·  gun on the roof",
	},
	"water_tower": {
		"name": "Water Tw", "long": "Water Tower", "cost": 200, "time": 22.0, "hp": 2200.0, "blocks": true, "zcost": 6.0,
		"prefab": true, "half": Vector2(1.5, 1.5), "model": "water_tower", "slot_bonus": 0.8, "unlock": 4,
		"hint": "Drag it, turn the handle, then tick", "about": "11 m perch: its gun gets +80% range",
	},
	"container": {
		"name": "Container", "long": "Shipping Container", "cost": 70, "time": 10.0, "hp": 3500.0, "blocks": true, "zcost": 6.0,
		"prefab": true, "half": Vector2(3.0, 1.25), "model": "container", "slot_bonus": 0.25, "unlock": 2,
		"hint": "Drag it, turn the handle, then tick", "about": "Steel box fort piece  ·  1 roof gun slot",
	},
	"pillbox": {
		"name": "Pillbox", "long": "Concrete Pillbox", "cost": 140, "time": 16.0, "hp": 4500.0, "blocks": true, "zcost": 6.0,
		"prefab": true, "half": Vector2(1.6, 1.6), "model": "pillbox", "capacity": 3, "unlock": 3,
		"hint": "Drag it, turn the handle, then tick", "about": "3 soldiers fire from the slits  ·  very tough",
	},
	"outpost": {
		"name": "Outpost", "long": "Scavenger Outpost", "cost": 120, "time": 12.0, "hp": 2400.0, "blocks": true, "zcost": 6.0,
		"prefab": true, "half": Vector2(2.0, 2.0), "model": "outpost", "capacity": 2, "slot_bonus": 0.2, "unlock": 2,
		"site_range": 14.0, "income": 40, "scrap_take": 40, "goal": true,
		"hint": "Drag it next to a scrap site, turn the handle, then tick", "about": "Income every wave  ·  zombies go for it",
	},
	"armory": {
		"name": "Armory", "long": "Armory", "cost": 160, "time": 20.0, "hp": 2400.0, "blocks": true, "zcost": 6.0,
		"prefab": true, "half": Vector2(2.0, 1.5), "model": "armory", "unlock": 4,
		"hint": "Drag it, turn the handle, then tick", "about": "All soldiers do +25% damage",
	},
	"scrapyard": {
		"name": "Scrapyard", "long": "Scrapyard", "cost": 110, "time": 16.0, "hp": 1600.0, "blocks": true, "zcost": 6.0,
		"prefab": true, "half": Vector2(2.5, 2.0), "model": "scrapyard", "unlock": 2,
		"hint": "Drag it, turn the handle, then tick", "about": "Fetchers' hauls +50%  ·  scrap piles refill faster",
	},
	"lamp": {
		"name": "Lamp", "long": "Street Lamp", "cost": 10, "time": 2.0, "hp": 0.0, "blocks": false, "zcost": 1.0,
		"ground": true, "trench": false, "line": false, "model": "suburb/streetlight", "decor": true,
		"hint": "Tap to place", "about": "Decoration",
	},
	"bench": {
		"name": "Bench", "long": "Bench", "cost": 5, "time": 1.5, "hp": 0.0, "blocks": false, "zcost": 1.0,
		"ground": true, "trench": false, "line": false, "model": "suburb/bench", "decor": true,
		"hint": "Tap to place", "about": "Decoration",
	},
	"tree": {
		"name": "Tree", "long": "Tree", "cost": 15, "time": 3.0, "hp": 0.0, "blocks": false, "zcost": 1.0,
		"ground": true, "trench": false, "line": false, "model": "suburb/tree_oak", "decor": true, "scale": 0.5,
		"hint": "Tap to plant", "about": "Decoration",
	},
	"bush": {
		"name": "Bush", "long": "Bush", "cost": 5, "time": 1.5, "hp": 0.0, "blocks": false, "zcost": 1.0,
		"ground": true, "trench": false, "line": false, "model": "suburb/bush_a", "decor": true,
		"hint": "Tap to plant", "about": "Decoration",
	},
	"swings": {
		"name": "Swings", "long": "Swings", "cost": 20, "time": 4.0, "hp": 0.0, "blocks": false, "zcost": 1.0, "size": 2,
		"ground": true, "trench": false, "line": false, "model": "suburb/playground_swings", "decor": true,
		"hint": "Tap to place", "about": "Decoration",
	},
	"trampoline": {
		"name": "Bounce", "long": "Trampoline", "cost": 20, "time": 4.0, "hp": 0.0, "blocks": false, "zcost": 1.0, "size": 2,
		"ground": true, "trench": false, "line": false, "model": "suburb/trampoline", "decor": true,
		"hint": "Tap to place", "about": "Decoration",
	},
}
const TABS := [
	{"id": "defend", "name": "Defend", "tools": ["turret", "mortar", "sniper", "flame", "garrison", "cannon"]},
	{"id": "build", "name": "Build", "tools": ["concrete", "wall", "gate", "platform", "wire", "car_wreck", "van_wreck", "bus_wreck"]},
	{"id": "base", "name": "Buildings", "tools": ["outpost", "house", "depot", "workshop", "barracks", "watchtower", "greenhouse", "clinic", "armory", "scrapyard"]},
	{"id": "high", "name": "Fortress", "tools": ["fort_wood", "fort_concrete", "room_block", "stairs", "bridge", "helipad", "helipad_large", "water_tower", "container", "pillbox"]},
	{"id": "supply", "name": "Extras", "tools": ["ammo_point", "radio", "fuel", "lamp", "bench", "tree", "bush", "swings", "trampoline"]},
	{"id": "traps", "name": "Traps", "tools": ["spikes", "mine", "dig", "decoy", "remove"]},
]
const TOOLS := ["turret", "mortar", "sniper", "flame", "garrison", "cannon", "concrete", "wall", "gate", "platform", "wire",
	"house", "depot", "workshop", "barracks", "watchtower", "room_block", "stairs", "bridge", "helipad", "helipad_large",
	"ammo_point", "radio", "fuel", "spikes", "mine", "dig",
	"car_wreck", "van_wreck", "bus_wreck", "decoy", "greenhouse", "clinic", "lamp", "bench", "tree", "bush", "swings", "trampoline",
	"water_tower", "container", "pillbox", "armory", "scrapyard", "fort_wood", "fort_concrete", "outpost"]
const MAP_BUILDINGS := {
	"house_two_storey": {
		"name": "House", "long": "Two-storey House", "claim": 55, "claim_time": 20.0, "hp": 3400.0, "blocks": true, "zcost": 6.0,
		"capacity": 4, "pop": 4, "slot_bonus": 0.3, "about": "+4 people  ·  windows  ·  a gun slot on the garage roof",
	},
	"house_bungalow": {
		"name": "Bungalow", "long": "Bungalow", "claim": 45, "claim_time": 16.0, "hp": 2600.0, "blocks": true, "zcost": 6.0,
		"capacity": 3, "pop": 3, "slot_bonus": 0.25, "about": "+3 people  ·  windows  ·  a gun slot on the porch",
	},
	"house_modern": {
		"name": "House", "long": "Modern House", "claim": 55, "claim_time": 18.0, "hp": 3200.0, "blocks": true, "zcost": 6.0,
		"capacity": 4, "pop": 4, "slot_bonus": 0.35, "about": "+4 people  ·  2 gun slots on the terrace",
	},
	"corner_shop": {
		"name": "Shop", "long": "Corner Shop", "claim": 70, "claim_time": 20.0, "hp": 3600.0, "blocks": true, "zcost": 6.0,
		"capacity": 4, "slot_bonus": 0.4, "about": "Flat roof: 2 gun slots",
	},
	"petrol_station": {
		"name": "Petrol", "long": "Petrol Station", "claim": 60, "claim_time": 20.0, "hp": 2400.0, "blocks": true, "zcost": 6.0,
		"capacity": 2, "slot_bonus": 0.5, "about": "Gun slots on the canopy",
	},
	"garage_detached": {
		"name": "Garage", "long": "Garage", "claim": 25, "claim_time": 8.0, "hp": 1600.0, "blocks": true, "zcost": 6.0,
		"capacity": 1, "slot_bonus": 0.25, "about": "A gun slot on the roof",
	},
}
const MAPS := [
	{"id": "fields", "name": "Fields", "about": "Open farmland. The first map", "ready": true},
	{"id": "suburb", "name": "Suburb", "about": "Streets, houses to claim, a petrol station", "ready": true},
	{"id": "forest", "name": "Forest", "about": "Woods, a lake", "ready": false},
	{"id": "city", "name": "City", "about": "Tall blocks", "ready": false},
]
const PREFABS := ["house", "depot", "workshop", "barracks", "watchtower", "bastion", "bastion_c", "room_block", "stairs", "helipad", "helipad_large",
	"car_wreck", "van_wreck", "bus_wreck", "greenhouse", "clinic", "water_tower", "container", "pillbox", "armory", "scrapyard", "outpost"]
const GUNS := ["turret", "mortar", "sniper", "flame", "garrison", "cannon"]
const SOLDIER_MAX := 40
const SOLDIER_HP := 70.0
const SOLDIER_RANGE := 14.0
const SOLDIER_DAMAGE := 13.0
const SOLDIER_INTERVAL := 0.95
const MORTAR_MIN := 8.0
const MORTAR_MAX := 30.0
const MORTAR_RELOAD := 2.6
const MORTAR_RADIUS := 3.0
const MORTAR_DAMAGE := 80.0
const SNIPER_RANGE := 36.0
const SNIPER_DAMAGE := 140.0
const SNIPER_INTERVAL := 2.2
const FLAME_RANGE := 7.5
const FLAME_ANGLE := 0.5
const FLAME_DPS := 32.0
const BURN_DPS := 11.0
const BURN_TIME := 3.0
const WIRE_SLOW := 0.33
const WIRE_WEAR := 7.0
const TURRET_RANGE := 13.0
const TURRET_RATE := 6.0
const TURRET_DAMAGE := 6.0
const CANNON_RANGE := 16.0
const CANNON_INTERVAL := 0.7
const CANNON_DAMAGE := 34.0
const CANNON_SPLASH := 1.8
const CANNON_SPLASH_DAMAGE := 16.0
const SPIKE_INTERVAL := 0.5
const SPIKE_DAMAGE := 14.0
const MINE_RADIUS := 4.0
const MINE_DAMAGE := 170.0
const Z_WALKER := 0
const Z_RUNNER := 1
const Z_BRUTE := 2
const REFUND_BUILT := 0.5
const REPAIR_COST := 0.4
const Z_HP_GROWTH := 0.38
const Z_HP_LATE := 0.05
const Z_HP := [33.0, 23.0, 330.0]
const Z_DMG := [7.0, 5.0, 40.0]
const WALKER_DMG := 7.0
const REWARD := [1, 2, 18]
const WAVE_BONUS_BASE := 50
const WAVE_BONUS_PER := 15
const BONUS_FREE_PEOPLE := 10
const BONUS_PER_PERSON := 25
const BONUS_PER_CLAIM := 40

static func z_hp_scale(w: int) -> float:
	var late := maxi(0, w - 4)
	return 1.0 + Z_HP_GROWTH * (w - 1) + Z_HP_LATE * late * late

static func cell_center(c: Vector2i) -> Vector3:
	return Vector3((c.x + 0.5) * CELL - HALF, 0.0, (c.y + 0.5) * CELL - HALF)

static func world_to_cell(p: Vector3) -> Vector2i:
	return Vector2i(floori((p.x + HALF) / CELL), floori((p.z + HALF) / CELL))

static func hq_center() -> Vector3:
	return cell_center(HQ_ORIGIN + Vector2i(1, 1))

static func world_to_nav(p: Vector3) -> Vector2i:
	return Vector2i(floori((p.x + HALF) / NAV), floori((p.z + HALF) / NAV))

static func nav_center(n: Vector2i) -> Vector3:
	return Vector3((n.x + 0.5) * NAV - HALF, 0.0, (n.y + 0.5) * NAV - HALF)

static func nav_to_build(n: Vector2i) -> Vector2i:
	return Vector2i(n.x / 2, n.y / 2)

static func gun_def(kind: String) -> bool:
	return GUNS.has(kind)

static func is_prefab(kind: String) -> bool:
	return bool(BUILD.get(kind, {}).get("prefab", false))

static func gun_range(kind: String) -> float:
	match kind:
		"turret":
			return TURRET_RANGE
		"cannon":
			return CANNON_RANGE
		"mortar":
			return MORTAR_MAX
		"sniper":
			return SNIPER_RANGE
		"flame":
			return FLAME_RANGE
		"garrison":
			return SOLDIER_RANGE + 2.0
	return 0.0
