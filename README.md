<p align="center"><img src="https://github.com/SmashUniverse64/postal2-archipelago/blob/main/docs/postal2-ap-logo.png" width="200" alt="description" display="block"></p>

# Postal 2 Archipelago

[Archipelago](https://archipelago.gg) randomizer for the original Monday–Friday **POSTAL 2** campaign.

**Goal:** finish all 19 weekday errands, then walk Home through the Apocalypse to your trailer.

When you start the game, you will load into your **Starting Day** with one random errand for that day. The seed shuffles the other four weekdays into a beatable order. Other days unlock when you receive an errand for that day.

## Install Guide

The install guide for the Postal 2 Mutator and the APworld is contained on the current [Release page](https://github.com/SmashUniverse64/postal2-archipelago/releases).
## New Mechanics

### AP Tokens

**AP tokens** are a new pickup that replaces other pickup locations at random. In-game, they appear as Archipelago logos. You'll have to look high and low across the entirety of Paradise to find them all! Progressive or otherwise useful items are colorful logos; filler and traps use a greyscale logo instead.

Which loot locations become tokens is chosen **per seed**. **Max Tokens Per Map** (`max_tokens`, default 12, range 6–15) is the maximum cap of AP tokens that can spawn on each map. Each chosen pile is its own named check (`Main Street - Shotgun Stereo House Bedroom`). Leftover vanilla piles next to a token stay usable (medkits, ammo, guns).

Every weekday you unlock, you gain access to 'Hunt Maps,' maps seeded with AP Tokens. View your currently unlocked Hunt Maps using your map. Visiting these hunt maps on their chosen day counts as a check. Keep in mind that you can only see AP Tokens (and collect the visit check) on each map on its chosen day, so make sure you're on the correct day to grab them all!

Does that sound daunting? It might be if you aren't familiar with all the loot locations, so the mod includes features designed to help with the hunting process! The YAML options **Token Glow** and **Token Heartbeat** make it easier to find remaining AP Tokens. In addition, there's a new **Hint Flare** item that fires a rocket from every AP Token on the current map into the sky. Follow the sound and the resulting boom!

Kickable ATMs, Crackola machines, and vending machines are checks too when those YAML options are on. Vending machines can also stock Archipelago items, with some configurable options. Use the new legend in the bottom-right corner of the map to track your progress!

### Time Warp

You no longer automatically end the day when all your errands are complete. So, how do you get to the other days? 

You have been given a new **Time Warp** item which is in your Other slot (where your Map is).

Select and use Time Warp to see a brand new warp menu. You can see a list of all of your **unlocked** days and the errands available for each. Keys **1–5** let you pick a weekday, then a destination. **Home** is always available as a warp point, but additional unlockable warp points take you to other maps for more convenient travel later in your run. Throw the Time Warp on the ground with the X key, and then when the giant light shaft appears, pick it back up to warp to your specified day and location.

**But how are the one-off story maps handled?**

Keys **6–0** return to Library, Burning Library, Brewery, Napalm Factory, and Parcel Center after you leave those maps once. This is in case you miss any AP tokens during your first visit!

## YAML options

### Weapon Unlocks

**Shuffle Weapons** (YAML option, on by default). You've forgotten how to use all of the weapons in the game and must unlock them as items in the item pool. If you turn this off, it works like the vanilla game, and you can add any weapon you find to your inventory. **Random Weapon**, another YAML option, is on by default alongside this and grants you a random weapon out of the pool that you can use right from the start. You can turn this off if you want to just have access to your hands (flipping people off) and piss.

### Melee Durability (Off by Default)

Your arsenal of extremely OP melee weapons will now wear down with each hit. Each successful hit with a melee weapon removes a random amount of durability from that weapon. If durability hits zero, you can no longer swing that melee weapon. Don't despair, though; you can use newly added Weapon Repair Kits to instantly repair your currently equipped melee weapon to max! When this option is on, weapon repair kits are guaranteed to drop for you in the loot pool, but if you really need to stock up, they've also been added to the various vending machines around Paradise. You can also partially repair your melee weapons by finding an instance of that weapon on the ground.

### Piss Realism (Off by Default)

Piss regenerates really, really slowly, with a configurable value in the options (30 seconds per 1 piss all the way up to 180 seconds per 1 piss). When your piss reaches the max of 20, you start taking damage and must piss to ease your bladder! So, you have to regulate how much piss you have access to, but also don't let it overflow. If you need emergency piss for whatever reason (especially with high values), you can buy water bottles at vending machines to instantly restore 5 piss.

### Other Major Features

- **Starting Day** (YAML option, defaults to Monday). Choose which day you start on or go all random. The order of your week is different every run.
- **Traps** (YAML option, on by default). A few silly and a few evil traps for you to discover...
- **Death Link support**
- **Token Glow and Token Heartbeat** (YAML option, on by default). By default, AP tokens both emit a glow you can see from outside buildings and create a heartbeat sound to help you track them down more easily. But if you want to make it a super difficult challenge for yourself, you can disable both! Some of these pickups are really tricky to find without it, so it's a real test of your game knowledge!

## AI Disclosure

AI tools were used to assist with debugging, refactoring, and asking questions about UnrealScript and Postal 2's engine.
