///////////////////////////////////////////////////////////////////////////////
// Inventory item that opens the Time Warp day-select screen.
// After a destination is chosen, throw it; when the dropped tree lights,
// pick it up to warp.
///////////////////////////////////////////////////////////////////////////////
class APTimeWarpInv extends P2PowerupInv;

var int PendingDay;
var string PendingURL;
var string PendingLabel;
var bool bPendingShowMap;
var bool bArmed;
var bool bPendingReady;

function ArmWarp(int Day, string URL, string Label, bool bShowMap)
{
	PendingDay = Day;
	PendingURL = URL;
	PendingLabel = Label;
	bPendingShowMap = bShowMap;
	bArmed = true;
	bPendingReady = false;
	bCanThrow = true;
	bAllowHints = true;
	Hint1 = "Press %KEY_ThrowPowerup% to throw";
	Hint2 = "Time Warp. Pick it up";
	Hint3 = "while it glows to warp.";
	if (P2Pawn(Owner) != None)
	{
		P2Pawn(Owner).SelectedItem = self;
		if (P2Player(P2Pawn(Owner).Controller) != None)
			P2Player(P2Pawn(Owner).Controller).UpdateHudInvHints();
	}
}

function ClearArm()
{
	bArmed = false;
	bPendingReady = false;
	bCanThrow = false;
	PendingURL = "";
	PendingLabel = "";
	Hint1 = "Press %KEY_InventoryActivate%";
	Hint2 = "to pick a day, then throw";
	Hint3 = "Time Warp to begin.";
}

function BreakWarp()
{
	ClearArm();
	Hint1 = "Time Warp is broken.";
	Hint2 = "Walk home through";
	Hint3 = "the Apocalypse.";
}

function TransferState(P2PowerupPickup maker)
{
	local APTimeWarpPickup Warp;

	Super.TransferState(maker);
	Warp = APTimeWarpPickup(maker);
	if (Warp == None)
		return;
	PendingDay = Warp.WarpDay;
	PendingURL = Warp.WarpURL;
	PendingLabel = Warp.WarpLabel;
	bPendingShowMap = Warp.bShowMap;
	bArmed = Warp.bArmed;
	bPendingReady = Warp.bReady;
}

function PickupFunction(Pawn Other)
{
	local APGameInfo G;

	Super.PickupFunction(Other);
	if (!bArmed)
		return;
	G = APGameInfo(Level.Game);
	if (bPendingReady)
	{
		bPendingReady = false;
		if (G != None)
			G.CommitTimeWarp(PendingDay, PendingURL, PendingLabel, bPendingShowMap);
		return;
	}
	ArmWarp(PendingDay, PendingURL, PendingLabel, bPendingShowMap);
}

state Activated
{
	function LookAtIt()
	{
		local P2Player Player;
		local APGameInfo G;

		Player = P2Player(P2Pawn(Owner).Controller);
		if (Player == None)
			return;
		G = APGameInfo(Level.Game);
		if (G != None)
			G.ShowTimeWarpMenu(Player);
	}
Begin:
	LookAtIt();
	GotoState('');
}

defaultproperties
{
	PickupClass=class'Archipelago.APTimeWarpPickup'
	Icon=Texture'Archipelago.APLogo'
	InventoryGroup=103
	GroupOffset=90
	PowerupName="Time Warp"
	PowerupDesc="Pick a day, throw Time Warp, then pick it up while it glows."
	bCanThrow=false
	bCannotBeStolen=true
	bThrowIndividually=false
	bDisplayAmount=false
	Amount=0
	MaxAmount=1
	Hint1="Press %KEY_InventoryActivate%"
	Hint2="to pick a day, then throw"
	Hint3="Time Warp to begin."
}
