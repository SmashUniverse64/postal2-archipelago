from dataclasses import dataclass

from Options import Choice, DeathLink, OptionSet, PerGameCommonOptions, Range, Toggle

from .data import TRAP_NAMES, coerce_trap_selection


class StartingDay(Choice):
    """Which weekday you begin after the intro (or immediately with Skip Intro).
    The seed shuffles the other four days into a beatable order. Leftover
    starting-day errands sit later in that order, so a Monday start can next
    unlock Thursday. Other days unlock when you receive an errand for that
    day. Hunt tokens only appear on maps you can enter that weekday. random
    picks a weekday."""
    display_name = "Starting Day"
    option_monday = 0
    option_tuesday = 1
    option_wednesday = 2
    option_thursday = 3
    option_friday = 4
    option_random = 5
    default = 0


class ShuffleWeapons(Toggle):
    """When on, world-placed guns are Archipelago checks instead of free loot.
    You still receive weapons from the multiworld. Always recommended."""
    display_name = "Shuffle Weapons"
    default = True


class RandomWeapon(Toggle):
    """Start with one random weapon already unlocked (shovel, pistol,
    shotgun, etc.). That copy is taken out of the item pool."""
    display_name = "Random Weapon"
    default = True


class Traps(OptionSet):
    """Choose which traps can appear. Each trap you leave on is still placed
    twice. Traps you turn off are replaced with normal junk, and the ones you
    keep are not any more common. All of them are on by default. An older YAML
    that says true or false still works: true means every trap, false means
    none."""
    display_name = "Traps"
    valid_keys = TRAP_NAMES
    default = frozenset(TRAP_NAMES)

    @classmethod
    def from_any(cls, data):
        return cls(coerce_trap_selection(data))


class VendingSanity(Toggle):
    """Turns ATF Vending Machines into locations to check: opening the menu
    is a check, and each machine can sell unique Archipelago items."""
    display_name = "Vending Sanity"
    default = True


class VendingSlots(Range):
    """Maximum Archipelago parcels each Vending Machine can sell.
    Each machine rolls 0 through this number when the seed is generated.
    Default 3. Ignored if Vending Sanity is off."""
    display_name = "Max Vending Items"
    range_start = 0
    range_end = 5
    default = 3


class MaxTokens(Range):
    """Maximum Archipelago tokens on each hunt map. Each map rolls 6 through
    this number, then
    keeps at most as many as it has real loot piles that fit the spacing
    rules. Default 12."""
    display_name = "Max Tokens Per Map"
    range_start = 6
    range_end = 15
    default = 12


# Parked. Not on Postal2Options, so it does not appear in the YAML or the
# website. choose_scrounge still accepts lootsanity, and the mutator still
# honors OPTION LOOTSANITY. To offer it again, add `lootsanity: Lootsanity`
# below and pass bool(self.options.lootsanity) from generate_early and
# fill_slot_data instead of the hardcoded False.
class Lootsanity(Toggle):
    """When on, every eligible world loot pile becomes an Archipelago token.
    Blocked / unreachable piles stay out. Hunt days still choose which maps
    spawn tokens each weekday. Max Tokens Per Map is ignored."""
    display_name = "Lootsanity"
    default = False


class CrackolaSanity(Toggle):
    """Kickable / buyable Crackola machines are location checks."""
    display_name = "Crackola Sanity"
    default = True


class ATMSanity(Toggle):
    """Kickable ATMs are location checks."""
    display_name = "ATM Sanity"
    default = True


class TokenGlow(Toggle):
    """Turn on a rainbow-colored light on useful and progression Archipelago
    tokens, and on ATM, Crackola, and vending machines that still hold one
    of those checks. Filler and trap pulse grey light instead. Turn off for
    a more difficult experience."""
    display_name = "Token Glow"
    default = True


class TokenHeartbeat(Toggle):
    """Heartbeat ping that gets faster and louder as you near an AP token or
    a machine that still has checks. Turn off to hunt by sight only."""
    display_name = "Token Heartbeat"
    default = True


class MeleeDurability(Toggle):
    """Melee weapons start at 100 durability. Each connecting hit wears 1–7.
    At 0 you can still equip them but they will not swing. Weapon Repair Kits
    restore the equipped melee weapon to 100. Chainsaw and gas can still use
    fuel instead. Off by default."""
    display_name = "Melee Durability"
    default = False


class PissRealism(Toggle):
    """Changes default piss behavior completely for a unique (and more
    difficult) experience. Your bladder starts nearly empty and refills
    slowly. At max bladder, you take damage until you go. Once you start
    pissing you cannot zip up until the meter is under 10. Enabling this
    option adds water bottles to Vending Machines ($5 at every vending
    machine) that instantly restore 5 bladder. Drinking Crackola also adds
    5 bladder. Off by default. Adjust how fast piss regenerates in Piss
    Regen Seconds."""
    display_name = "Piss Realism"
    default = False


class PissRegen(Range):
    """Seconds per bladder pip when Piss Realism is on. Default 120.
    Minimum 30, maximum 180. Ignored if Piss Realism is off."""
    display_name = "Piss Regen Seconds"
    range_start = 30
    range_end = 180
    default = 120


@dataclass
class Postal2Options(PerGameCommonOptions):
    death_link: DeathLink
    starting_day: StartingDay
    shuffle_weapons: ShuffleWeapons
    random_weapon: RandomWeapon
    traps: Traps
    vending_sanity: VendingSanity
    vending_slots: VendingSlots
    max_tokens: MaxTokens
    crackola_sanity: CrackolaSanity
    atm_sanity: ATMSanity
    token_glow: TokenGlow
    token_heartbeat: TokenHeartbeat
    melee_durability: MeleeDurability
    piss_realism: PissRealism
    piss_regen: PissRegen
