///////////////////////////////////////////////////////////////////////////////
// Player controller for Archipelago. Extends AWDudePlayer so kill-counter
// and AW extras stay intact. Used to lock fire/weapon switch during the
// piss trap (vanilla Streaming already ignores switch while pissing, but
// only if PressingFire stays true).
///////////////////////////////////////////////////////////////////////////////
class APDudePlayer extends AWDudePlayer;

function Possess(Pawn aPawn)
{
	Super.Possess(aPawn);
	// 1.1 bound these to debug commands. Default is unbound.
	ConsoleCommand("SET Input NumPad1");
	ConsoleCommand("SET Input NumPad2");
	ConsoleCommand("SET Input NumPad3");
	ConsoleCommand("SET Input NumPad4");
	ConsoleCommand("SET Input NumPad5");
}

function AddWeaponSelector()
{
	CustomWeaponSelectorClassName = "";
	CustomWeaponSelectorName = '';
	WeaponSelectorClassName = "Archipelago.APWeaponSelector";
	WeaponSelectorName = 'APWeaponSelector';
	if (Player == None)
		return;
	if (APWeaponSelector(WeaponSelector) != None)
		return;
	RecreateWeaponSelector();
	if (APWeaponSelector(WeaponSelector) != None)
		APWeaponSelector(WeaponSelector).SafeRefreshSelector();
}

function RefreshWeaponSelector()
{
	RecreateWeaponSelector();
	if (APWeaponSelector(WeaponSelector) != None)
		APWeaponSelector(WeaponSelector).SafeRefreshSelector();
}

function RecreateWeaponSelector()
{
	local int i, n;
	local Interaction Kill[8];

	CustomWeaponSelectorClassName = "";
	CustomWeaponSelectorName = '';
	WeaponSelectorClassName = "Archipelago.APWeaponSelector";
	WeaponSelectorName = 'APWeaponSelector';
	if (Player == None)
		return;
	n = 0;
	for (i = 0; i < Player.LocalInteractions.Length && n < 8; i++)
	{
		if (P2WeaponSelector(Player.LocalInteractions[i]) != None)
		{
			Kill[n] = Player.LocalInteractions[i];
			n++;
		}
	}
	for (i = 0; i < n; i++)
	{
		if (Kill[i] != None)
			Player.InteractionMaster.RemoveInteraction(Kill[i]);
	}
	WeaponSelector = None;
	WeaponSelector = P2WeaponSelector(Player.InteractionMaster.AddInteraction(WeaponSelectorClassName, Player));
}

function WipeTravelSelectors()
{
	local int i, n;
	local Interaction Kill[8];
	local P2InventorySelector InvSel;

	if (Player == None)
		return;
	n = 0;
	for (i = 0; i < Player.LocalInteractions.Length && i < 32; i++)
	{
		InvSel = P2InventorySelector(Player.LocalInteractions[i]);
		if (InvSel != None)
		{
			if (InvSel.bMenuVisible)
				InvSel.HideMenu(true);
			InvSel.DisplayItems.Length = 0;
		}
		if (P2WeaponSelector(Player.LocalInteractions[i]) != None && n < 8)
		{
			Kill[n] = Player.LocalInteractions[i];
			n++;
		}
	}
	for (i = 0; i < n; i++)
	{
		if (Kill[i] != None)
			Player.InteractionMaster.RemoveInteraction(Kill[i]);
	}
	WeaponSelector = None;
	if (InventorySelector != None)
		InventorySelector.DisplayItems.Length = 0;
}

function PreTravel()
{
	local APGameInfo G;

	WipeTravelSelectors();
	G = APGameInfo(Level.Game);
	if (G != None)
		G.ClearGreyTokens();
	Super.PreTravel();
}

event PostLoadGame()
{
	Super.PostLoadGame();
	if (APWeaponSelector(WeaponSelector) != None)
		APWeaponSelector(WeaponSelector).SafeRefreshSelector();
}

event TravelPostAccept()
{
	local APGameInfo G;

	RecreateWeaponSelector();
	Super.TravelPostAccept();
	G = APGameInfo(Level.Game);
	if (G != None && P2Pawn(Pawn) != None)
	{
		G.SanitizeDudeInventory(P2Pawn(Pawn));
		G.StripDuplicateWeapons(P2Pawn(Pawn));
		G.GiveTimeWarp(P2Pawn(Pawn));
	}
	if (APWeaponSelector(WeaponSelector) != None)
		APWeaponSelector(WeaponSelector).SafeRefreshSelector();
}

function bool PissLocked()
{
	local APGameInfo G;

	G = APGameInfo(Level.Game);
	return (G != None && G.IsPissLocked());
}

function bool WaitingForAPClient()
{
	local APGameInfo G;

	G = APGameInfo(Level.Game);
	return (G != None && G.IsWaitingForAPClient());
}

simulated function bool PressingFire()
{
	if (PissLocked() && Pawn != None && UrethraWeapon(Pawn.Weapon) != None)
		return true;
	return Super.PressingFire();
}

exec function NextWeapon()
{
	if (WaitingForAPClient() || PissLocked())
		return;
	Super.NextWeapon();
}

exec function PrevWeapon()
{
	if (WaitingForAPClient() || PissLocked())
		return;
	Super.PrevWeapon();
}

exec function SwitchWeapon(byte F)
{
	if (WaitingForAPClient() || PissLocked())
		return;
	Super.SwitchWeapon(F);
}

exec function SwitchToHands(optional bool bForce)
{
	if (WaitingForAPClient() || PissLocked())
		return;
	Super.SwitchToHands(bForce);
}

exec function ToggleToHands(optional bool bForce)
{
	if (WaitingForAPClient() || PissLocked())
		return;
	Super.ToggleToHands(bForce);
}

exec function UseZipper(optional float F)
{
	local APGameInfo G;

	if (WaitingForAPClient() || PissLocked())
		return;
	G = APGameInfo(Level.Game);
	if (G != None)
		G.EnsureClinicGonorrhea();
	Super.UseZipper(F);
}

exec function ThrowWeapon()
{
	if (WaitingForAPClient() || PissLocked())
		return;
	Super.ThrowWeapon();
}

exec function ThrowPowerup()
{
	if (WaitingForAPClient())
		return;
	Super.ThrowPowerup();
}

exec function Use()
{
	if (WaitingForAPClient())
		return;
	Super.Use();
}

exec function Suicide()
{
	if (WaitingForAPClient())
		return;
	Super.Suicide();
}

exec function ActivateItem()
{
	local CrackColaInv Cola;
	local bool WasIdle;
	local APGameInfo G;

	if (WaitingForAPClient())
		return;
	Cola = None;
	if (Pawn != None)
		Cola = CrackColaInv(Pawn.SelectedItem);
	WasIdle = (Cola != None && Cola.Amount > 0 && Cola.GetStateName() != 'Activated');
	Super.ActivateItem();
	if (WasIdle && Cola != None && Cola.GetStateName() == 'Activated')
	{
		G = APGameInfo(Level.Game);
		if (G != None && G.PissRealismEnabled())
			G.AddPiss(P2Pawn(Pawn), 5);
	}
}

exec function QuickUseMap()
{
	if (WaitingForAPClient())
		return;
	Super.QuickUseMap();
}

function ForceMapUp()
{
	if (WaitingForAPClient())
		return;
	Super.ForceMapUp();
}

function bool BlockBrokenMelee()
{
	local APGameInfo G;
	local P2Weapon Weap;
	local string N;

	G = APGameInfo(Level.Game);
	if (G == None || Pawn == None)
		return false;
	if (WeaponSelector != None && WeaponSelector.ValidIndexesSelected())
		return false;
	if (Pawn.PendingWeapon != None && Pawn.PendingWeapon != Pawn.Weapon)
		return false;
	Weap = P2Weapon(Pawn.Weapon);
	if (!G.IsMeleeBroken(Weap))
		return false;
	if (Level.TimeSeconds >= G.LastBrokenMeleeMsgTime + 1.5)
	{
		N = Weap.ItemName;
		if (N == "")
			N = "weapon";
		G.ShowAPMessage("Your "$N$" is broken.");
		G.LastBrokenMeleeMsgTime = Level.TimeSeconds;
	}
	return true;
}

exec function Fire(optional float F)
{
	if (WaitingForAPClient())
		return;
	if (BlockBrokenMelee())
		return;
	Super.Fire(F);
}

exec function AltFire(optional float F)
{
	if (WaitingForAPClient())
		return;
	if (BlockBrokenMelee())
		return;
	Super.AltFire(F);
}

function bool CheckForChangeClothes(class<Inventory> NewClothesClass)
{
	local APGameInfo G;

	G = APGameInfo(Level.Game);
	if (G != None && G.IsGimpTrapLocked()
		&& NewClothesClass != class'GimpClothesInv')
	{
		G.ShowAPMessage("The zipper's stuck until you leave this map.");
		return false;
	}
	if (G != None && G.ShouldKeepGimp()
		&& NewClothesClass != class'GimpClothesInv')
		return false;
	return Super.CheckForChangeClothes(NewClothesClass);
}

function DisplayVote()
{
	local APGameInfo G;

	G = APGameInfo(Level.Game);
	if (G != None && !G.VoteBoothShouldWork())
	{
		G.RefuseVoteBooth();
		return;
	}
	Super.DisplayVote();
}

function bool OnIntroMap()
{
	local P2GameInfoSingle G;

	G = P2GameInfoSingle(Level.Game);
	if (G != None && G.IsIntroMap())
		return true;
	return false;
}

function CheckPrepForSave()
{
	if (OnIntroMap())
	{
		bDidPrepForSave = true;
		return;
	}
	Super.CheckPrepForSave();
}

state PlayerWalking
{
	function PrepForSave()
	{
		if (OnIntroMap())
			return;
		Super.PrepForSave();
	}

	function PlayerMove(float DeltaTime)
	{
		if (WaitingForAPClient())
		{
			aForward = 0;
			aStrafe = 0;
			aUp = 0;
			bPressedJump = false;
		}
		Super.PlayerMove(DeltaTime);
	}
}

state PlayerPrepSave
{
	function BeginState()
	{
		if (OnIntroMap())
		{
			bDidPrepForSave = true;
			ExitPrepToSave();
			return;
		}
		Super.BeginState();
	}
}

defaultproperties
{
	WeaponSelectorClassName="Archipelago.APWeaponSelector"
	WeaponSelectorName=APWeaponSelector
}
