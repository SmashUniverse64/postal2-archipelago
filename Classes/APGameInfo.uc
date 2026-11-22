///////////////////////////////////////////////////////////////////////////////
// APGameInfo
//
// Archipelago campaign: vanilla Monday-Friday Postal 2, plus a localhost
// TCP bridge to the Postal 2 Client in the apworld.
//
// Goal is completing Friday. The Postal 2 Client speaks Archipelago.
///////////////////////////////////////////////////////////////////////////////
class APGameInfo extends GameSinglePlayer;

#exec Texture Import File=Textures\APLogo.tga Name=APLogo Mips=Off ALPHA=1 DXT=5
#exec Texture Import File=Textures\APLogoGrey.tga Name=APLogoGrey Mips=Off ALPHA=1 DXT=5
#exec Texture Import File=Textures\APMenuLogo.tga Name=APMenuLogo Mips=Off ALPHA=1 DXT=5

var config string CompanionHost;
var config int CompanionPort;
var config string APServer;
var config string APSlot;
var config string APPassword;
var APLink Bridge;
var array<string> RecordedChecks;
var array<string> PendingItems;
var string LastMapKey;
var string LastVisitKey;
var array<string> AreaLockedTeles;
var float LastLockMsgTime;
var float RefuseCooldown;
var float LastWeaponRefuseTime;
var string LastWeaponRefuseName;
var float LastGateNudgeTime;
var bool bAnnouncedMapPickups;
var bool bRemindedMapPickups;
var bool bAnnouncedAllFound;
var float MapAnnounceAt;
var float MapRemindAt;
var bool bReturnVisit;
var float NextGlowUpdate;
var float NextMachineGlowUpdate;
var float TokenBeepScanTime;
var float TokenBeepBestDist;
var float NextMilkPlace;
var bool bVendCureTriggered;
var float VendCureFallbackAt;
var string LastVendorMap;
var float LastBrokenMeleeMsgTime;
var float APCatRainUntil;
var float APNextCat;
var float APPissUntil;
var float PissComplainAt;
var float PissDamageAt;
var bool bGimpTrap;
var class<Inventory> GimpTrapPrevClothes;
var bool bGimpTrapHadCop;
var bool bVendorDirty;
var bool bNeedStripCollected;
var bool bCheckedSyncReady;
var bool bRecBlobsRepaired;
var byte ClinicNeedCached;
var float LastCatchUpTime;
var string VHintU[32];
var string VHintN[32];
var int VHintP[32];
var int VHintF[32];
var int VHintCount;
var string GreyBlob;
var array<string> GreyBlobs;
const RecCheckCap = 800;
const RecBlobPartCap = 96;
const RecBlobLenCap = 960;
var int APTrackerInLogic;
var int APTrackerLeft;
var array<string> CatU;
var array<string> CatCls;
var array<string> CatMap;
var array<int> CatX;
var array<int> CatY;
var array<int> CatZ;
var array<int> CatHere;
var string CatHereKey;
var array<string> MapTokK;
var array<int> MapTokN;
var bool bMapTokDirty;
var int MapTokScan;
var bool bPendingPissTrap;
var int StartDayWaitLeft;
var bool bPendingStartDayReload;
var float StartDayReloadAt;

///////////////////////////////////////////////////////////////////////////////
event PostTravel(P2Pawn PlayerPawn)
{
	local P2Player P;
	local APGameState GS;

	Super.PostTravel(PlayerPawn);
	RepairRecBlobs();
	if (IsIntroMap())
	{
		EnsureBridge();
		if (GS == None)
			GS = APState();
		if (GS == None || GS.APSeed == "" || !GS.bAPCaughtUp)
			RequestCatchUp();
		return;
	}
	SanitizeDudeInventory(PlayerPawn);
	InvalidateScroungeCache();
	EnsureBridge();
	ClinicNeedCached = 0;
	GS = APState();
	if (GS != None)
		GS.CompactUnlocks();
	DropTravelledGreyList();
	StripLockedStartingItems(PlayerPawn);
	SwapStatsClipboard(PlayerPawn);
	ClearGimpTrap(PlayerPawn);
	EnsureEscapeClothes(PlayerPawn);
	ApplyWarpLockGimp();
	if (ShouldKeepGimp())
		EnforceKeepGimp(PlayerPawn);
	EnsureAnyDayPetition();
	ApplyGatedErrands(true);
	ReportMapEntry();
	ApplyAreaLocks();
	ReapplyUnlocks(PlayerPawn);
	if (ShouldKeepGimp())
		EnforceKeepGimp(PlayerPawn);
	ForceAPLogoFlags();
	ApplyStartDay();
	RestoreErrandPickupsOnMap();
	RemoveCollectedWorldPickups();

	GS = APState();
	if (GS != None && GS.bNeedBreweryResync)
		FinishBreweryEscape(PlayerPawn);
	if (ShouldKeepGimp())
		EnforceKeepGimp(PlayerPawn);
	if (GS != None && (GS.APSeed == "" || !GS.bAPCaughtUp))
		RequestCatchUp();
	if (GS != None && GS.bShowMapAfterWarp)
	{
		GS.bShowMapAfterWarp = false;
		P = GetPlayer();
		if (P != None)
			P.ForceMapUp();
	}
	SanitizeDudeInventory(PlayerPawn);
	StripDuplicateWeapons(PlayerPawn);
	GiveTimeWarp(PlayerPawn);
	ApplyPissRealismToDude(PlayerPawn);
	MaybeStartApocalypse(true);
}

event PostLoadGame()
{
	Super.PostLoadGame();
	DropTravelledGreyList();
	RepairRecBlobs();
	EnsureBridge();
	ClinicNeedCached = 0;
	if (APState() != None)
		APState().CompactUnlocks();
	EnsureAnyDayPetition();
	ApplyGatedErrands(true);
	if (GetPlayer() != None && P2Pawn(GetPlayer().Pawn) != None)
	{
		SanitizeDudeInventory(P2Pawn(GetPlayer().Pawn));
		SwapStatsClipboard(P2Pawn(GetPlayer().Pawn));
		ReapplyUnlocks(P2Pawn(GetPlayer().Pawn));
		if (ShouldKeepGimp())
			EnforceKeepGimp(P2Pawn(GetPlayer().Pawn));
		SanitizeDudeInventory(P2Pawn(GetPlayer().Pawn));
	}
	RestoreErrandPickupsOnMap();
	NextGlowUpdate = 0;
	RemoveCollectedWorldPickups();
	if (GetPlayer() != None)
	{
		EnsureEscapeClothes(P2Pawn(GetPlayer().Pawn));
		ApplyWarpLockGimp();
		SanitizeDudeInventory(P2Pawn(GetPlayer().Pawn));
		StripDuplicateWeapons(P2Pawn(GetPlayer().Pawn));
		GiveTimeWarp(P2Pawn(GetPlayer().Pawn));
		ApplyPissRealismToDude(P2Pawn(GetPlayer().Pawn));
	}
	MaybeStartApocalypse();
	RequestCatchUp();
}

function RequestCatchUp(optional float MinGap)
{
	if (MinGap <= 0)
		MinGap = 8.0;
	if (LastCatchUpTime > 0 && Level.TimeSeconds < LastCatchUpTime + MinGap)
		return;
	LastCatchUpTime = Level.TimeSeconds;
	if (LastCatchUpTime <= 0)
		LastCatchUpTime = 0.01;
	bCheckedSyncReady = false;
	EnsureBridge();
	if (Bridge != None)
		Bridge.SendLine("CATCHUP");
}

///////////////////////////////////////////////////////////////////////////////
// Vanilla PrepSliderPawns loops while SliderPawnsActive > SliderPawnGoal and
// only decrements when it randomly stasises a LambController pawn. If the
// counter is inflated (dead controllers, preload spawn leftovers, extra AP
// pawns), that while-loop never exits and UE2 aborts at 1e6 iterations.
// Time Warp from the Brewery onto Home Monday hits this during Startup.
///////////////////////////////////////////////////////////////////////////////
function PrepSliderPawns()
{
	local FPSPawn fpawn;
	local int loopcount, userand, userange, rangehalf, hitcount, actual, stasised;

	actual = 0;
	hitcount = 0;
	foreach DynamicActors(class'FPSPawn', fpawn)
	{
		hitcount++;
		if (hitcount > 4000)
			break;
		if (fpawn == None || fpawn.bDeleteMe || fpawn.bPlayer)
			continue;
		if (fpawn.bUsePawnSlider && !fpawn.bPersistent && !fpawn.bSliderStasis
			&& LambController(fpawn.Controller) != None)
			actual++;
	}
	SliderPawnsActive = actual;
	if (SliderPawnsActive <= SliderPawnGoal)
		return;

	userange = SliderPawnsActive - SliderPawnGoal;
	rangehalf = userange / 2;
	loopcount = 0;
	hitcount = 0;
	while (SliderPawnsActive > SliderPawnGoal && loopcount < 40)
	{
		stasised = 0;
		foreach DynamicActors(class'FPSPawn', fpawn)
		{
			if (SliderPawnsActive <= SliderPawnGoal)
				break;
			hitcount++;
			if (hitcount > 4000)
			{
				if (SliderPawnsActive > SliderPawnGoal)
					SliderPawnsActive = SliderPawnGoal;
				return;
			}
			if (fpawn == None || fpawn.bDeleteMe || fpawn.bPlayer)
				continue;
			if (!fpawn.bUsePawnSlider || fpawn.bPersistent || fpawn.bSliderStasis)
				continue;
			if (LambController(fpawn.Controller) == None)
				continue;
			userand = Rand(userange);
			if (userand >= rangehalf)
			{
				LambController(fpawn.Controller).GoIntoSliderStasis();
				stasised++;
				userange = SliderPawnsActive - SliderPawnGoal;
				if (userange < 1)
					break;
				rangehalf = userange / 2;
			}
		}
		if (stasised == 0)
		{
			if (SliderPawnsActive > SliderPawnGoal)
				SliderPawnsActive = SliderPawnGoal;
			return;
		}
		loopcount++;
	}
	if (SliderPawnsActive > SliderPawnGoal)
		SliderPawnsActive = SliderPawnGoal;
}

// Split vanilla StartUp so PrepActorsByGroup's AllActors pass cannot
// spend the 1e6-iteration budget before RemoveGottenPickups runs.
auto state StartUp
{
	function PrepPlayerStartup()
	{
		local P2Player p2p;

		p2p = GetPlayer();
		if (!Level.IsDemoBuild() && p2p != None)
			p2p.PrepForSave();
		if (p2p != None && TheGameState != None
			&& TheGameState.bFirstLevelOfGame && TheGameState.bForceMap)
		{
			p2p.ForceMapUp();
			TheGameState.bForceMap = false;
		}
	}

	function bool StartingUp()
	{
		return true;
	}

Begin:
	PrepDifficulty();
	SetZoneFogPlanes();
	StartDayWaitLeft = 80;
WaitStartDay:
	if (WantStartDayWait())
	{
		Sleep(0.1);
		Goto('WaitStartDay');
	}
	ApplyStartDay();
	ChangeSkyByDay();
	ChangeMenuBackground();
	PrepActorsByGroup();
	Sleep(0.0);
	PrepSliderPawns();
	PrepPickupsForErrands();
	RemoveGottenPickups();
	CheckToTransferPlayerInventory();
	StoreChams();
	if (TheGameState != None && TheGameState.bIsApocalypse)
		ConvertAllPawnsToRiotMode();
	PrepPlayerStartup();
	if (!IsMainMenuMap() && !IsIntroMap() && !IsFinishedDayMap())
		if (Level.Title != "" && Level.Title != "Untitled" && GetPlayer() != None)
			GetPlayer().ClientMessage(Level.Title);
	if (TheGameState != None && TheGameState.bIsApocalypse)
		GotoState('RunningApocalypse');
	else
		GotoState(RunningStateName);
}

///////////////////////////////////////////////////////////////////////////////
function EnsureBridge()
{
	local APLink Existing;

	if (Bridge != None && !Bridge.bDeleteMe)
		return;

	foreach AllActors(class'APLink', Existing)
	{
		Bridge = Existing;
		if (Bridge.APGame != self)
			Bridge.InitBridge(self);
		return;
	}

	Bridge = Spawn(class'APLink');
	if (Bridge == None)
	{
		Warn("Archipelago: failed to spawn APLink");
		return;
	}
	Bridge.InitBridge(self);
}

///////////////////////////////////////////////////////////////////////////////
// Errand completions are the real location checks. After Super marks the
// errand done, the newest CompletedErrands entry is the one that just fired.
//
// Buying milk from the Paradise clerk does NOT go through MilkPickup — the
// cashier calls this with MilkInv. Treat that as GetMilk even if Super
// does not consider the errand complete.
///////////////////////////////////////////////////////////////////////////////
function bool CheckForErrandCompletion(
	Actor Other,
	Actor Another,
	Pawn ActionPawn,
	P2Player ThisPlayer,
	bool bPremature,
	optional string SendToURL)
{
	local bool bCompleted;
	local int i, DayIndex, ErrandIndex;
	local string UniqueName;

	if (Other != None && Other.Tag == 'VoteScreen' && !IsUnlocked("ERRAND:Vote"))
		return false;

	bCompleted = Super.CheckForErrandCompletion(Other, Another, ActionPawn, ThisPlayer, bPremature, SendToURL);
	if (!bCompleted)
		bCompleted = TryCompleteOffDayErrand(Other, Another, ActionPawn, bPremature);

	if (Other != None && (Other.IsA('MilkInv') || Other.IsA('MilkPickup') || Other.Tag == 'MilkPickup')
		&& IsUnlocked("ERRAND:GetMilk"))
		SendCheck("GetMilk");
	if (!bCompleted)
		MaybeRefuseErrand(Other, ActionPawn);

	if (bCompleted && TheGameState != None)
	{
		i = TheGameState.CompletedErrands.Length - 1;
		if (i >= 0)
		{
			DayIndex = TheGameState.CompletedErrands[i].Day;
			ErrandIndex = TheGameState.CompletedErrands[i].Errand;
			if (DayIndex >= 0 && DayIndex < Days.Length
				&& Days[DayIndex] != None
				&& ErrandIndex >= 0 && ErrandIndex < Days[DayIndex].Errands.Length)
			{
				UniqueName = Days[DayIndex].Errands[ErrandIndex].UniqueName;
				SendCheck(UniqueName);
				if (IsAnyDayErrand(UniqueName))
					SaveErrandOnAllDays(UniqueName);
			}
		}

	}

	return bCompleted;
}

// Petition is the only errand that can finish off its vanilla weekday.
// Super only asks Days[CurrentDay]; if the clipboard is not on today's list
// yet, complete GetSignatures on whichever day still owns it.
function bool TryCompleteOffDayErrand(
	Actor Other,
	Actor Another,
	Pawn ActionPawn,
	bool bPremature)
{
	local int d, e;
	local name CompletionTrigger;
	local string SendPlayerURL;
	local Actor TriggerMe;
	local ErrandBase PetErrand;

	if (TheGameState == None || Other == None)
		return false;
	if (ClipboardWeapon(Other) == None)
		return false;

	for (d = 0; d < Days.Length; d++)
	{
		if (d == TheGameState.CurrentDay || Days[d] == None)
			continue;
		e = Days[d].FindErrand("GetSignatures");
		if (e < 0)
			continue;
		PetErrand = Days[d].Errands[e];
		if (PetErrand == None || !PetErrand.IsActive() || PetErrand.bCompleted)
			continue;
		if (PetErrand.CheckForCompletion(Other, Another, ActionPawn, TheGameState, CompletionTrigger, SendPlayerURL))
		{
			PetErrand.SetComplete(bPremature);
			SaveErrandOnAllDays("GetSignatures");
			if (CompletionTrigger != 'None')
			{
				foreach AllActors(class'Actor', TriggerMe, CompletionTrigger)
					TriggerMe.Trigger(None, ActionPawn);
			}
			return true;
		}
	}
	return false;
}

function bool IsAnyDayErrand(string UniqueName)
{
	return UniqueName ~= "GetSignatures";
}

// Petition lives on Tuesday in vanilla. Point every weekday at that same
// object so the map can write it on whichever day you are on, without
// making it a Tuesday unlock.
function EnsureAnyDayPetition()
{
	local int srcDay, srcErr, d, i;
	local ErrandBase Src;

	if (!FindErrand("GetSignatures", srcDay, srcErr))
		return;
	Src = Days[srcDay].Errands[srcErr];
	if (Src == None)
		return;
	for (d = 0; d < Days.Length; d++)
	{
		if (Days[d] == None)
			continue;
		if (Days[d].FindErrand("GetSignatures") >= 0)
			continue;
		i = Days[d].Errands.Length;
		Days[d].Errands.Insert(i, 1);
		Days[d].Errands[i] = Src;
		Days[d].ActiveErrands = -1;
		if (Src.bCompleted && TheGameState != None && !GameStateHasErrand(d, i))
			SaveCompletedErrand(d, i);
	}
}

function SaveErrandOnAllDays(string UniqueName)
{
	local int d, e;

	if (UniqueName == "" || TheGameState == None)
		return;
	for (d = 0; d < Days.Length; d++)
	{
		if (Days[d] == None)
			continue;
		e = Days[d].FindErrand(UniqueName);
		if (e >= 0 && !GameStateHasErrand(d, e))
			SaveCompletedErrand(d, e);
	}
}

///////////////////////////////////////////////////////////////////////////////
// PickupQuery fires for dude pickups. Do not require Super to allow the
// pickup: if you already have MilkInv from the cashier, Super returns false
// and we would otherwise miss the fridge carton.
///////////////////////////////////////////////////////////////////////////////
function bool PickupQuery(Pawn Other, Pickup Item)
{
	local bool bAllow, bAPToken, bMilk;
	local class<Inventory> InvType;
	local string U;

	if (Other != None && P2Player(Other.Controller) != None && Item != None)
	{
		if (APWorldPickup(Item) != None && APWorldPickup(Item).APUnique != ""
			&& HasRecordedCheck(APWorldPickup(Item).APUnique))
		{
			ConsumeAPToken(Item);
			return false;
		}
		if (IsErrandWorldPickup(Item) && IsAPToken(Item))
			RestoreErrandPickup(Item);
		U = UniqueForPickup(Item);
		if (U != "" && HasRecordedCheck(U) && !IsErrandWorldPickup(Item))
		{
			ConsumeAPToken(Item);
			return false;
		}
		bAPToken = !IsErrandWorldPickup(Item) && (IsAPToken(Item) || ShouldBeAPToken(Item));
		MaybePickupCheck(Item);

		InvType = Item.InventoryType;
		U = ErrandUniqueForWorldPickup(Item);
		if (U != "")
		{
			if (IsGatedCampaignErrand(U) && !IsUnlocked("ERRAND:"$U))
				return false;
			CompleteErrandWithPickup(U, Item, Other);
		}

		if (Item.IsA('PaycheckPickup') || Item.Tag == 'PaycheckPickup')
		{
			if (!IsUnlocked("Inventory.PaycheckInv"))
			{
				Item.Destroy();
				return false;
			}
		}

		if (APWorldPickup(Item) == None
			&& (Item.IsA('MilkPickup') || Item.Tag == 'MilkPickup'
			|| (InvType != None && InvType.Name == 'MilkInv'))
			&& IsUnlocked("ERRAND:GetMilk"))
		{
			BindMilkPickup(Item);
			SendCheck("GetMilk");
		}

		if (Item.IsA('CrackColaPickup'))
			SendCheck(ColaUniqueNear(Item.Location));

		if (APRestorePickup(Item) != None)
		{
			RestoreAPLoadout(P2Pawn(Other));
			SendCheck("BreweryRestore");
			ConsumeAPToken(Item);
			return false;
		}

		if (bAPToken)
		{
			U = UniqueForPickup(Item);
			if (U != "")
				SendCheck(U);
			ConsumeAPToken(Item);
			if (U != "")
				MaybePlayAreaTokensDone();
			return false;
		}

		if (P2WeaponPickup(Item) != None
			&& P2WeaponPickupErrand(Item) == None
			&& !(P2PowerupPickup(Item) != None && P2PowerupPickup(Item).bUseForErrands)
			&& ShuffleWeaponsOn()
			&& !IsWeaponAllowed(InvType))
		{
			if (SiphonAmmoFromLockedWeapon(Other, Item))
				return false;
			RefuseLockedWeapon(Item);
			return false;
		}

		if (MeleeDurabilityEnabled()
			&& P2WeaponPickup(Item) != None
			&& P2WeaponPickupErrand(Item) == None
			&& RepairMeleeFromPickup(P2Pawn(Other), Item))
			return false;
	}

	bMilk = (Item != None && IsMilkPickup(Item));
	bAllow = Super.PickupQuery(Other, Item);
	if (bMilk && Other != None)
		BindUnpaidMilkToHabib(P2Pawn(Other));
	return bAllow;
}

function string WeaponPickupName(Pickup Item)
{
	local class<P2Weapon> WC;

	if (Item == None)
		return "that weapon";
	if (Item.InventoryType != None)
	{
		WC = class<P2Weapon>(Item.InventoryType);
		if (WC != None && WC.default.ItemName != "")
			return WC.default.ItemName;
	}
	return "that weapon";
}

function RefuseLockedWeapon(Pickup Item)
{
	local string WName, Key;

	WName = WeaponPickupName(Item);
	Key = string(Item.Class)$WName;
	if (Level.TimeSeconds < LastWeaponRefuseTime + 2.5 && LastWeaponRefuseName ~= Key)
		return;
	LastWeaponRefuseTime = Level.TimeSeconds;
	LastWeaponRefuseName = Key;
	ShowAPMessage("You don't know how to use the "$WName$" yet!");
}

function bool IsShovelPickup(Pickup Item)
{
	if (Item == None)
		return false;
	if (Item.IsA('ShovelPickup'))
		return true;
	if (Item.InventoryType != None
		&& (Item.InventoryType.Name == 'ShovelWeapon'
			|| Item.InventoryType.Name == 'ShovelWeaponSS'))
		return true;
	return false;
}

function bool GameStateHasErrand(int Day, int Errand)
{
	local int i;
	if (TheGameState == None)
		return false;
	for (i = 0; i < TheGameState.CompletedErrands.Length; i++)
		if (TheGameState.CompletedErrands[i].Day == Day
			&& TheGameState.CompletedErrands[i].Errand == Errand)
			return true;
	return false;
}

function PrepareErrand(string UniqueName)
{
	local int d, e;
	if (!FindErrand(UniqueName, d, e))
		return;
	if (Days[d].Errands[e] == None)
		return;
	if (!GameStateHasErrand(d, e))
		Days[d].Errands[e].bCompleted = false;
}

function CompleteErrandWithPickup(string UniqueName, Actor Item, Pawn ActionPawn)
{
	local P2Player P;
	local bool bDid;

	PrepareErrand(UniqueName);
	P = P2Player(ActionPawn.Controller);
	if (P == None)
		P = GetPlayer();
	bDid = Super.CheckForErrandCompletion(Item, None, ActionPawn, P, false);
	if (!bDid)
		ForceErrandByName(UniqueName);
	SendCheck(UniqueName);
}

///////////////////////////////////////////////////////////////////////////////
function string NextPipeToken(out string Rest)
{
	local int p;
	local string U;

	while (Left(Rest, 1) == "|")
		Rest = Mid(Rest, 1);
	if (Rest == "")
		return "";
	p = InStr(Rest, "|");
	if (p == -1)
	{
		U = Rest;
		Rest = "";
		return U;
	}
	U = Left(Rest, p);
	Rest = Mid(Rest, p + 1);
	return U;
}

function bool IsValidCheckUnique(string U)
{
	local int n;

	if (U == "")
		return false;
	n = Len(U);
	if (n < 2 || n > 80)
		return false;
	if (InStr(U, "=") != -1)
		return false;
	if (InStr(U, "(") != -1)
		return false;
	if (InStr(U, ")") != -1)
		return false;
	if (InStr(U, " ") != -1)
		return false;
	if (InStr(U, ",") != -1)
		return false;
	if (InStr(U, "\"") != -1)
		return false;
	return true;
}

function int RecBlobCount(APGameState GS)
{
	local int i, n;

	if (GS == None)
		return 0;
	n = 0;
	for (i = 0; i < RecBlobPartCap; i++)
		if (GS.RecBlobs[i] != "")
			n = i + 1;
	return n;
}

function ClearRecBlobs(APGameState GS)
{
	local int i;

	if (GS == None)
		return;
	for (i = 0; i < RecBlobPartCap; i++)
		GS.RecBlobs[i] = "";
}

function AddPipeUniquesToRecBlob(APGameState GS, string Blob)
{
	local string Rest, U;
	local int Guard;

	if (GS == None || Blob == "")
		return;
	Rest = Blob;
	while (Rest != "" && Guard < 200)
	{
		Guard++;
		U = Caps(NextPipeToken(Rest));
		if (U != "")
			AddToRecBlob(GS, U);
	}
}

function AddToRecBlob(APGameState GS, string U)
{
	local int i, n, last;
	local string Needle, Chunk;

	if (GS == None || !IsValidCheckUnique(U))
		return;
	Needle = "|"$U$"|";
	n = RecBlobCount(GS);
	for (i = 0; i < n; i++)
		if (InStr(GS.RecBlobs[i], Needle) != -1)
			return;
	if (n <= 0)
	{
		GS.RecBlobs[0] = Needle;
		return;
	}
	last = n - 1;
	Chunk = GS.RecBlobs[last];
	if (Chunk == "")
	{
		GS.RecBlobs[last] = Needle;
		return;
	}
	if (Len(Chunk) + Len(U) + 1 < RecBlobLenCap)
	{
		if (Right(Chunk, 1) != "|")
			Chunk = Chunk$"|";
		GS.RecBlobs[last] = Chunk$U$"|";
		return;
	}
	if (n >= RecBlobPartCap)
		return;
	GS.RecBlobs[n] = Needle;
}

function InitRecordedBlob()
{
	if (bRecBlobsRepaired)
		return;
	RepairRecBlobs();
}

function RepairRecBlobs()
{
	local APGameState GS;
	local int i, n;
	local string U;

	GS = APState();
	if (GS == None)
	{
		bRecBlobsRepaired = true;
		return;
	}
	if (GS.RecordedBlob != "")
	{
		AddPipeUniquesToRecBlob(GS, GS.RecordedBlob);
		GS.RecordedBlob = "";
	}
	n = GS.RecordedChecks.Length;
	if (n > RecCheckCap)
		n = RecCheckCap;
	for (i = 0; i < n; i++)
	{
		U = Caps(GS.RecordedChecks[i]);
		if (U != "")
			AddToRecBlob(GS, U);
	}
	n = RecordedChecks.Length;
	if (n > RecCheckCap)
		n = RecCheckCap;
	for (i = 0; i < n; i++)
	{
		U = Caps(RecordedChecks[i]);
		if (U != "")
			AddToRecBlob(GS, U);
	}
	if (RecBlobCount(GS) == 0)
		GS.RecBlobs[0] = "|";
	bRecBlobsRepaired = true;
}

function bool HasRecordedCheck(string UniqueName)
{
	local APGameState GS;
	local string Needle;
	local int i, n;

	if (UniqueName == "")
		return false;
	Needle = "|"$Caps(UniqueName)$"|";
	GS = APState();
	if (GS != None)
	{
		InitRecordedBlob();
		for (i = 0; i < RecBlobPartCap; i++)
			if (GS.RecBlobs[i] != "" && InStr(GS.RecBlobs[i], Needle) != -1)
				return true;
		if (bRecBlobsRepaired)
			return false;
		n = GS.RecordedChecks.Length;
		if (n > RecCheckCap)
			n = RecCheckCap;
		for (i = 0; i < n; i++)
			if (GS.RecordedChecks[i] ~= UniqueName)
				return true;
	}
	n = RecordedChecks.Length;
	if (n > RecCheckCap)
		n = RecCheckCap;
	for (i = 0; i < n; i++)
		if (RecordedChecks[i] ~= UniqueName)
			return true;
	return false;
}

function RecordCheck(string UniqueName)
{
	local APGameState GS;
	local string U;

	if (UniqueName == "" || !IsValidCheckUnique(UniqueName) || HasRecordedCheck(UniqueName))
		return;
	ClinicNeedCached = 0;
	U = Caps(UniqueName);
	GS = APState();
	if (GS != None)
	{
		AddToRecBlob(GS, U);
		if (GS.RecordedChecks.Length < RecCheckCap)
			GS.RecordedChecks[GS.RecordedChecks.Length] = UniqueName;
	}
	if (RecordedChecks.Length < RecCheckCap)
		RecordedChecks[RecordedChecks.Length] = UniqueName;
	NoteCatalogCheck(UniqueName);
	MaybeStartApocalypse();
	if (UniqueName ~= "PickupLaundry")
		SetKeepGimp(false);
}

function MarkRemoteCheck(string UniqueName)
{
	if (HasRecordedCheck(UniqueName))
		return;
	RecordCheck(UniqueName);
	bVendorDirty = true;
}

function MarkRemoteCheckLine(string Arg)
{
	local string Rest, U;
	local int Guard;

	Rest = Arg;
	while (Rest != "" && Guard < 200)
	{
		Guard++;
		U = NextPipeToken(Rest);
		if (U != "")
			MarkRemoteCheck(U);
	}
}

function FindInPickupList(Pickup DelMe, string Lname)
{
	local int i, n;

	if (DelMe == None || TheGameState == None)
		return;
	n = TheGameState.GottenPickups.Length;
	if (n > 400)
		n = 400;
	for (i = 0; i < n; i++)
	{
		if (TheGameState.GottenPickups[i].PickupName == DelMe.Name
			&& TheGameState.GottenPickups[i].LevelName ~= Lname)
		{
			DelMe.Destroy();
			return;
		}
	}
}

function RemoveGottenPickups()
{
	local Pickup CheckP;
	local Pickup KillList[48];
	local name Taken[80];
	local string Lname;
	local int i, n, tn, kn, hits, j;

	if (TheGameState == None)
		return;
	Lname = ParseLevelName(Level.GetLocalURL());
	if (Right(Lname, 4) ~= ".fuk")
		Lname = Left(Lname, Len(Lname) - 4);
	n = TheGameState.GottenPickups.Length;
	if (n > 250)
		n = 250;
	tn = 0;
	for (i = 0; i < n && tn < 80; i++)
	{
		if (TheGameState.GottenPickups[i].LevelName ~= Lname)
		{
			Taken[tn] = TheGameState.GottenPickups[i].PickupName;
			tn++;
		}
	}
	if (tn == 0)
		return;
	kn = 0;
	foreach DynamicActors(class'Pickup', CheckP)
	{
		hits++;
		if (hits > 600)
			break;
		if (CheckP == None || CheckP.bDeleteMe)
			continue;
		if (!((P2WeaponPickup(CheckP) != None && P2WeaponPickup(CheckP).bRecordAfterPickup)
			|| (P2PowerupPickup(CheckP) != None && P2PowerupPickup(CheckP).bRecordAfterPickup)
			|| (P2AmmoPickup(CheckP) != None && P2AmmoPickup(CheckP).bRecordAfterPickup)))
			continue;
		for (j = 0; j < tn; j++)
		{
			if (CheckP.Name == Taken[j])
			{
				KillList[kn] = CheckP;
				kn++;
				break;
			}
		}
		if (kn >= 48)
			break;
	}
	for (i = 0; i < kn; i++)
		if (KillList[i] != None && !KillList[i].bDeleteMe)
			KillList[i].Destroy();
}

function bool IsCollectedWorldPickup(Pickup Item)
{
	local string U;

	if (Item == None || Item.bDeleteMe)
		return false;
	if (IsErrandWorldPickup(Item))
		return false;
	if (APWorldPickup(Item) != None && APWorldPickup(Item).APUnique != "")
		return HasRecordedCheck(APWorldPickup(Item).APUnique);
	U = UniqueForPickup(Item);
	if (U == "" || !HasRecordedCheck(U))
		return false;
	if (IsAPToken(Item))
		return true;
	if (NamedUniqueForPickup(Item) != "")
		return true;
	if (Left(U, 3) == "SC_")
		return true;
	return false;
}

function RemoveCollectedWorldPickups()
{
	local Pickup Item, KillList[80];
	local APWorldPickup Token;
	local int i, N, Pass, Iter;

	for (Pass = 0; Pass < 4; Pass++)
	{
		N = 0;
		foreach DynamicActors(class'APWorldPickup', Token)
		{
			if (Token == None || Token.bDeleteMe)
				continue;
			if (Token.APUnique != "" && HasRecordedCheck(Token.APUnique))
			{
				KillList[N] = Token;
				N++;
				if (N >= 80)
					break;
			}
		}
		if (N == 0)
		{
			Iter = 0;
			foreach AllActors(class'Pickup', Item)
			{
				Iter++;
				if (Iter > 800)
					break;
				if (APWorldPickup(Item) != None)
					continue;
				if (!IsCollectedWorldPickup(Item))
					continue;
				KillList[N] = Item;
				N++;
				if (N >= 80)
					break;
			}
		}
		if (N == 0)
			return;
		for (i = 0; i < N; i++)
			ConsumeAPToken(KillList[i]);
		bVendorDirty = true;
	}
}

function StripUnplayableMapTokens()
{
	local Pickup Item, KillList[64];
	local int i, N, Iter;

	if (!(MapKey() ~= "INTRO"))
		return;
	foreach AllActors(class'Pickup', Item)
	{
		Iter++;
		if (Iter > 800)
			break;
		if (Item == None || Item.bDeleteMe)
			continue;
		if (!IsAPToken(Item))
			continue;
		if (N >= 64)
			break;
		KillList[N] = Item;
		N++;
	}
	for (i = 0; i < N; i++)
		ConsumeAPToken(KillList[i]);
}

function ReplayRecordedChecks(APLink Link)
{
	local int i;
	local APGameState GS;
	local string Blob, Rest, U;
	local int Guard;

	if (Link == None)
		return;
	RepairRecBlobs();
	GS = APState();
	if (GS == None)
		return;
	for (i = 0; i < RecBlobPartCap; i++)
	{
		Blob = GS.RecBlobs[i];
		if (Blob == "")
			continue;
		Rest = Blob;
		Guard = 0;
		while (Rest != "" && Guard < 200)
		{
			Guard++;
			U = NextPipeToken(Rest);
			if (IsValidCheckUnique(U))
				Link.QueueLine("CHECK "$U);
		}
	}
}

function SendCheck(string UniqueName)
{
	if (!IsValidCheckUnique(UniqueName))
		return;
	if (IsGatedCampaignErrand(UniqueName) && !IsUnlocked("ERRAND:"$UniqueName))
		return;
	EnsureBridge();
	if (Bridge != None)
		Bridge.SendCheck(UniqueName);
	else
		RecordCheck(UniqueName);
	if (Left(UniqueName, 5) ~= "VBUY_")
	{
		bVendorDirty = true;
		LastVendorMap = "";
		NextMachineGlowUpdate = 0;
	}
	if (Left(UniqueName, 5) ~= "VUSE_")
		NextMachineGlowUpdate = 0;
	if (UniqueName ~= "GetNapalm")
		ApplyWarpLockGimp();
}

function ApplyAPSeed(string Seed, bool bReset)
{
	local APGameState GS;

	GS = APState();
	if (GS == None)
		return;
	if (bReset)
	{
		GS.RecordedChecks.Length = 0;
		GS.RecordedBlob = "";
		ClearRecBlobs(GS);
		RecordedChecks.Length = 0;
		GS.Unlocks.Length = 0;
		GS.FillerApplied.Length = 0;
		GS.TrapApplied.Length = 0;
		GS.ATMSent.Length = 0;
		GS.VisitedMaps.Length = 0;
		GS.AreaTokenVO.Length = 0;
		GS.ScroungeLock.Length = 0;
		GS.TokenMapK.Length = 0;
		GS.TokenMapD.Length = 0;
		LastMapKey = "";
		LastVisitKey = "";
		bRecBlobsRepaired = false;
		GS.bAPCaughtUp = false;
		ClearScroungeCatalog();
		ClearGreyTokens();
		InvalidateScroungeCache();
		ShowAPMessage("New Archipelago seed. Old checks cleared.");
		ReportMapEntry();
	}
	GS.APSeed = Seed;
	if (Seed != "")
		GS.bAPCaughtUp = true;
	InvalidateScroungeCache();
}

function NotifyCheckSent(string DisplayName)
{
	if (DisplayName == "")
		return;
	ShowAPMessage("Sent check: "$DisplayName);
	PlayAPSound(false);
}

function NotifyItemReceived(string DisplayName, bool bTrap)
{
	if (DisplayName == "")
		return;
	if (bTrap)
		ShowAPMessage("Trap: "$DisplayName);
	else
		ShowAPMessage("Received: "$DisplayName);
	PlayAPSound(true);
}

function PlayAPSound(bool bReceive)
{
	local P2Player P;
	local Pawn Dude;
	local sound S;

	P = GetPlayer();
	if (P == None)
		return;
	Dude = P.Pawn;
	if (Dude == None)
		return;

	if (bReceive)
		S = Sound'WeaponSounds.weapon_pickup';
	else
		S = Sound'WeaponSounds.weapon_picked_up';
	if (S != None)
		Dude.PlaySound(S, SLOT_Interface, 2.0, false, 200);
}

function SendPickup(Pickup Item)
{
	EnsureBridge();
	if (Bridge != None)
		Bridge.SendPickup(Item);
}

function SendGoal()
{
	EnsureBridge();
	if (Bridge != None)
		Bridge.SendGoal();
}

function SendGranted(string ClassName)
{
	EnsureBridge();
	if (Bridge != None)
		Bridge.SendLine("GRANTED "$ClassName);
}

///////////////////////////////////////////////////////////////////////////////
function bool IsQuietStatusMessage(string S)
{
	local string C;

	C = Caps(S);
	if (InStr(C, "CONNECTED") != -1)
		return true;
	if (InStr(C, "CONNECTING") != -1)
		return true;
	if (InStr(C, "COMPANION") != -1)
		return true;
	if (InStr(C, "DISCONNECTED") != -1)
		return true;
	if (InStr(C, "RECONNECT") != -1)
		return true;
	return false;
}

function ShowAPMessage(string Text)
{
	local P2Player P;

	if (IsQuietStatusMessage(Text))
		return;
	log("AP: "$Text, 'Archipelago');
	P = GetPlayer();
	if (P != None)
		P.ClientMessage("AP: "$Text);
}

exec function APHelp()
{
	ShowAPMessage("apconnect host:port slot [password]");
	ShowAPMessage("apstatus  |  apdisconnect");
	ShowAPMessage("Bridge stays local. The game cannot speak WebSocket/WSS itself.");
}

function bool IsListedWorldToken(Pickup Item, out string U)
{
	if (Item == None || Item.bDeleteMe)
		return false;
	U = UniqueForPickup(Item);
	if (U == "" || HasRecordedCheck(U) || IsErrandCheck(U))
		return false;
	if (!IsAPToken(Item) && NamedUniqueForPickup(Item) == "" && Left(U, 3) != "SC_")
		return false;
	return true;
}

function bool FireHintFlares(P2Pawn Dude)
{
	local Pickup Item;
	local vector Spots[96];
	local int N, i, Iter;
	local string U;
	local APHintFlareRocket R;
	local rotator Up;

	foreach AllActors(class'Pickup', Item)
	{
		Iter++;
		if (Iter > 800)
			break;
		if (!IsListedWorldToken(Item, U))
			continue;
		if (N >= 96)
			break;
		Spots[N] = Item.Location + vect(0,0,16);
		N++;
	}
	if (N == 0)
	{
		ShowAPMessage("No AP tokens on this map to flare.");
		return false;
	}
	Up.Pitch = 16384;
	Up.Yaw = 0;
	Up.Roll = 0;
	for (i = 0; i < N; i++)
		R = Spawn(class'APHintFlareRocket',,, Spots[i], Up);
	ShowAPMessage("Hint flare: "$string(N)$" rockets");
	return true;
}

exec function APStatus()
{
	local string Server;

	if (APServer == "")
		Server = "(not set; connect in Postal 2 Client)";
	else
		Server = APServer$" as "$APSlot;
	ShowAPMessage("Server: "$Server);
	if (Bridge != None && Bridge.IsConnected())
		ShowAPMessage("Postal 2 Client TCP: connected");
	else
		ShowAPMessage("Postal 2 Client TCP: down. Open Postal 2 Client.");
}

exec function APDisconnect()
{
	APServer = "";
	APSlot = "";
	APPassword = "";
	SaveConfig();
	EnsureBridge();
	if (Bridge != None)
		Bridge.QueueLine("DISCONNECT");
	ShowAPMessage("Cleared saved server. Postal 2 Client still running.");
}

exec function APConnect(string Address, optional string SlotName, optional string Pass)
{
	if (Address == "")
	{
		APHelp();
		return;
	}
	if (SlotName == "")
	{
		if (APSlot != "")
			SlotName = APSlot;
		else
			SlotName = "Dude";
	}
	APServer = Address;
	APSlot = SlotName;
	APPassword = Pass;
	SaveConfig();
	EnsureBridge();
	SendConnectToBridge();
	ShowAPMessage("Connecting to "$Address$" as "$SlotName$"...");
}

function SendConnectToBridge()
{
	local string Line;

	if (APServer == "")
		return;
	EnsureBridge();
	if (Bridge == None)
		return;
	Line = "CONNECT "$APServer$" "$APSlot;
	if (APPassword != "")
		Line = Line$" "$APPassword;
	Bridge.QueueLine(Line);
}

///////////////////////////////////////////////////////////////////////////////
function QueuePendingItem(string ClassName)
{
	local int i;

	if (ClassName == "")
		return;
	for (i = 0; i < PendingItems.Length; i++)
		if (PendingItems[i] ~= ClassName)
			return;
	PendingItems[PendingItems.Length] = ClassName;
}

function FlushPendingItems()
{
	local int i;

	for (i = PendingItems.Length - 1; i >= 0; i--)
	{
		if (Left(PendingItems[i], 4) ~= "DAY:")
		{
			PendingItems.Remove(i, 1);
			continue;
		}
		if (TryGiveAPItem(PendingItems[i], 0, true))
			PendingItems.Remove(i, 1);
	}
}

function SendSavedErrands()
{
	local int i, DayIndex, ErrandIndex;

	if (TheGameState == None)
		return;

	for (i = 0; i < TheGameState.CompletedErrands.Length; i++)
	{
		DayIndex = TheGameState.CompletedErrands[i].Day;
		ErrandIndex = TheGameState.CompletedErrands[i].Errand;
		if (DayIndex >= 0 && DayIndex < Days.Length
			&& Days[DayIndex] != None
			&& ErrandIndex >= 0 && ErrandIndex < Days[DayIndex].Errands.Length)
			SendCheck(Days[DayIndex].Errands[ErrandIndex].UniqueName);
	}

}

function ApplyTrap(string TrapName)
{
	local P2Player P;
	local P2Pawn Dude;
	local vector Loc, Offset;
	local int i, Idx, Sp;
	local Protestors Guy;
	local rotator SpawnRot;
	local APGameState GS;

	Sp = InStr(TrapName, " ");
	if (Sp != -1)
	{
		Idx = int(Mid(TrapName, Sp + 1));
		TrapName = Left(TrapName, Sp);
		GS = APState();
		if (GS != None)
		{
			if (GS.HasTrap(Idx))
				return;
			GS.RecordTrap(Idx);
		}
	}

	P = GetPlayer();
	if (P != None)
		Dude = P2Pawn(P.Pawn);

	PlayAPSound(true);

	if (TrapName ~= "CatRain")
	{
		// Vanilla cat rain only ticks in RunningApocalypse. Spawn them ourselves.
		APCatRainUntil = Level.TimeSeconds + 20;
		APNextCat = 0;
		ShowAPMessage("It's raining cats!");
		TickCatRainTrap();
	}
	else if (TrapName ~= "Wanted")
	{
		if (TheGameState != None)
		{
			TheGameState.IncreaseCopRadioTime();
			TheGameState.IncreaseCopRadioTime();
			TheGameState.IncreaseCopRadioTime();
		}
		ShowAPMessage("The cops want you!");
	}
	else if (TrapName ~= "DropGun")
	{
		if (Dude != None)
			Dude.TossWeapon(vect(0,0,350));
		ShowAPMessage("Butterfingers!");
	}
	else if (TrapName ~= "Protestors")
	{
		if (Dude != None)
		{
			for (i = 0; i < 4; i++)
			{
				SpawnRot = Dude.Rotation;
				SpawnRot.Yaw += i * 16384;
				Offset = vector(SpawnRot);
				Offset.Z = 0;
				Loc = FloorNear(Dude.Location + Offset * 200);
				SpawnAngryProtestor(Loc, Dude);
			}
			ShowAPMessage("A protest breaks out!");
		}
	}
	else if (TrapName ~= "Piss")
	{
		StartPissTrap();
	}
	else if (TrapName ~= "Gimp")
	{
		StartGimpTrap();
	}
	else if (TrapName ~= "SuicideBomber")
	{
		SpawnSuicideBomberTrap(Dude);
	}
}

function bool IsPissLocked()
{
	if (APPissUntil > 0 && Level.TimeSeconds <= APPissUntil)
		return true;
	return MustKeepPeeing();
}

function bool MustKeepPeeing()
{
	local P2Player P;
	local P2Pawn Dude;
	local UrethraWeapon U;

	if (!PissRealismEnabled())
		return false;
	P = GetPlayer();
	if (P == None)
		return false;
	Dude = P2Pawn(P.Pawn);
	if (Dude == None)
		return false;
	U = UrethraWeapon(Dude.Weapon);
	if (U == None || U.AmmoType == None)
		return false;
	if (U.AmmoType.AmmoAmount < 10)
		return false;
	return (U.IsInState('Streaming') || U.IsInState('StartStream'));
}

function bool IsGimpTrapLocked()
{
	local APGameState GS;
	GS = APState();
	if (GS != None)
		return GS.bGimpTrap;
	return bGimpTrap;
}

function bool WearingGimp()
{
	local DudePlayer DP;

	DP = DudePlayer(GetPlayer());
	return (DP != None && DP.DudeIsGimp());
}

function bool MustWalkHomeApocalypse()
{
	if (TheGameState != None && TheGameState.bIsApocalypse)
		return true;
	if (AllErrandsRecorded() && !HasRecordedCheck("FridayHome"))
		return true;
	return false;
}

function string TimeWarpBlockedReason()
{
	if (IsWaitingForAPClient())
		return "Connect in the Postal 2 Client first.";
	if (MustWalkHomeApocalypse())
		return "Time Warp is broken. Walk home through the Apocalypse.";
	if (IsGimpTrapLocked() || WearingGimp())
		return "Can't Time Warp in the gimp suit.";
	return "";
}

function BreakTimeWarpItem()
{
	local P2Player P;
	local APTimeWarpInv Inv;
	local APTimeWarpPickup Warp, KillList[8];
	local int i, n;

	P = GetPlayer();
	if (P != None && P.Pawn != None)
	{
		Inv = APTimeWarpInv(P.Pawn.FindInventoryType(class'APTimeWarpInv'));
		if (Inv != None)
			Inv.BreakWarp();
	}
	n = 0;
	foreach DynamicActors(class'APTimeWarpPickup', Warp)
	{
		if (Warp != None && n < 8)
		{
			KillList[n] = Warp;
			n++;
		}
	}
	for (i = 0; i < n; i++)
		if (KillList[i] != None)
			KillList[i].Destroy();
}

function MaybeStartApocalypse(optional bool bTravel)
{
	local P2Player P;

	if (TheGameState == None)
		return;
	if (HasRecordedCheck("FridayHome"))
		return;
	if (!AllErrandsRecorded())
		return;
	if (TheGameState.bIsApocalypse)
		return;
	if (bTravel || StartingUp())
	{
		TheGameState.bIsApocalypse = true;
		BreakTimeWarpItem();
		return;
	}
	P = GetPlayer();
	if (P == None || P.MyPawn == None)
	{
		TheGameState.bIsApocalypse = true;
		BreakTimeWarpItem();
		return;
	}
	StartApocalypse();
	BreakTimeWarpItem();
	ShowAPMessage("Time Warp is broken. Walk home through the Apocalypse.");
}

function bool ShouldKeepGimp()
{
	local APGameState GS;

	GS = APState();
	return (GS != None && GS.bKeepGimp);
}

function SetKeepGimp(bool Keep)
{
	local APGameState GS;

	GS = APState();
	if (GS != None)
		GS.bKeepGimp = Keep;
}

function DropGimpTrapLock()
{
	local APGameState GS;

	bGimpTrap = false;
	GimpTrapPrevClothes = None;
	GS = APState();
	if (GS != None)
	{
		GS.bGimpTrap = false;
		GS.GimpTrapPrevClothes = None;
	}
}

function WearGimpNow()
{
	local DudePlayer DP;
	local P2Pawn Dude;

	DP = DudePlayer(GetPlayer());
	if (DP == None)
		return;
	Dude = P2Pawn(DP.Pawn);
	if (!DP.DudeIsGimp())
	{
		DP.CheckForChangeClothes(class'GimpClothesInv');
		DP.ChangeToNewClothes();
	}
	StripInventoryClothes(Dude, false);
	if (TheGameState != None)
		TheGameState.CurrentClothes = class'GimpClothesInv';
}

function PutOnKeepGimp()
{
	local bool bWasKeep;

	bWasKeep = ShouldKeepGimp();
	if (IsGimpTrapLocked())
		DropGimpTrapLock();
	if (!bWasKeep || !WearingGimp())
		WearGimpNow();
	SetKeepGimp(true);
	if (!HasRecordedCheck("PickupLaundry") && !IsErrandActiveByName("PickupLaundry"))
		ActivateErrand("PickupLaundry");
	if (!bWasKeep)
		ShowAPMessage("Walk home in the gimp suit to get your clothes back.");
}

function ApplyWarpLockGimp()
{
	local string K;
	local APGameState GS;
	local P2Pawn Dude;

	GS = APState();
	K = MapKey();
	if (GetPlayer() != None)
		Dude = P2Pawn(GetPlayer().Pawn);
	if (ShouldKeepGimp())
	{
		if (IsGimpTrapLocked())
			DropGimpTrapLock();
		EnforceKeepGimp(Dude);
		return;
	}
	if (IsGimpTrapLocked())
	{
		if (K ~= "BREWERY" && (GS == None || !GS.bWarpBrewery))
			PutOnKeepGimp();
		return;
	}
	if (K ~= "LIBRARY2" && (GS == None || !GS.bWarpLibrary))
		StartGimpTrap();
	else if (K ~= "BREWERY" && (GS == None || !GS.bWarpBrewery))
		PutOnKeepGimp();
	else if (K ~= "NAPALM" && HasRecordedCheck("GetNapalm") && (GS == None || !GS.bWarpNapalm))
		StartGimpTrap();
}

function TickKeepGimp()
{
	local P2Pawn Dude;

	if (!ShouldKeepGimp())
		return;
	if (GetPlayer() != None)
		Dude = P2Pawn(GetPlayer().Pawn);
	EnforceKeepGimp(Dude);
}

function EnforceKeepGimp(P2Pawn Dude)
{
	if (!ShouldKeepGimp())
		return;
	WearGimpNow();
	StripInventoryClothes(Dude, false);
}

function StripInventoryClothes(P2Pawn Dude, bool bGimpOnly)
{
	local Inventory Inv, Next;
	local int n;

	if (Dude == None)
		return;
	Inv = Dude.Inventory;
	n = 0;
	while (Inv != None && n < 96)
	{
		n++;
		Next = Inv.Inventory;
		if (ClothesInv(Inv) != None)
		{
			if (bGimpOnly)
			{
				if (GimpClothesInv(Inv) != None)
				{
					if (Inv.Instigator != None)
						Inv.DetachFromPawn(Inv.Instigator);
					Dude.DeleteInventory(Inv);
					Inv.Destroy();
				}
			}
			else if (GimpClothesInv(Inv) == None)
			{
				if (Inv.Instigator != None)
					Inv.DetachFromPawn(Inv.Instigator);
				Dude.DeleteInventory(Inv);
				Inv.Destroy();
			}
		}
		Inv = Next;
	}
}

function class<Inventory> GimpTrapWantedClothes()
{
	local APGameState GS;
	local class<Inventory> Want;

	GS = APState();
	if (GS != None)
		Want = GS.GimpTrapPrevClothes;
	if (Want == None)
		Want = GimpTrapPrevClothes;
	if (Want == None || ClassIsChildOf(Want, class'GimpClothesInv'))
		Want = class'DudeClothesInv';
	return Want;
}

function bool PlayerHasCopClothes(P2Pawn Dude, DudePlayer DP)
{
	if (DP != None && DP.CurrentClothes != None
		&& ClassIsChildOf(DP.CurrentClothes, class'CopClothesInv'))
		return true;
	if (Dude != None && Dude.FindInventoryType(class'CopClothesInv') != None)
		return true;
	return false;
}

function bool GimpTrapRememberedCop()
{
	local APGameState GS;

	if (bGimpTrapHadCop)
		return true;
	GS = APState();
	return (GS != None && GS.bGimpTrapHadCop);
}

function SetGimpTrapHadCop(bool HadCop)
{
	local APGameState GS;

	bGimpTrapHadCop = HadCop;
	GS = APState();
	if (GS != None)
		GS.bGimpTrapHadCop = HadCop;
}

function RestoreGimpTrapCopClothes(P2Pawn Dude)
{
	local DudePlayer DP;

	if (Dude == None || !GimpTrapRememberedCop())
		return;
	if (Dude.FindInventoryType(class'CopClothesInv') != None)
	{
		SetGimpTrapHadCop(false);
		return;
	}
	DP = DudePlayer(Dude.Controller);
	if (DP != None && DP.CurrentClothes != None
		&& ClassIsChildOf(DP.CurrentClothes, class'CopClothesInv'))
	{
		SetGimpTrapHadCop(false);
		return;
	}
	Dude.CreateInventoryByClass(class'CopClothesInv');
	SetGimpTrapHadCop(false);
}

function StartGimpTrap()
{
	local DudePlayer DP;
	local P2Pawn Dude;
	local APGameState GS;
	local class<Inventory> Prev;
	local bool HadCop;

	GS = APState();
	DP = DudePlayer(GetPlayer());
	if (ShouldKeepGimp())
		return;
	if (IsGimpTrapLocked())
		return;
	if (DP == None || DP.Pawn == None)
		return;
	Dude = P2Pawn(DP.Pawn);
	Prev = DP.CurrentClothes;
	HadCop = PlayerHasCopClothes(Dude, DP);
	if (Prev == None || ClassIsChildOf(Prev, class'GimpClothesInv'))
		Prev = class'DudeClothesInv';
	GimpTrapPrevClothes = Prev;
	if (GS != None)
		GS.GimpTrapPrevClothes = Prev;
	SetGimpTrapHadCop(HadCop);
	if (!DP.DudeIsGimp())
	{
		DP.CheckForChangeClothes(class'GimpClothesInv');
		DP.ChangeToNewClothes();
	}
	StripInventoryClothes(Dude, false);
	if (TheGameState != None)
		TheGameState.CurrentClothes = class'GimpClothesInv';
	bGimpTrap = true;
	if (GS != None)
		GS.bGimpTrap = true;
	ShowAPMessage("Gimp suit's stuck until you leave this map!");
}

function ClearGimpTrap(optional P2Pawn PassedDude)
{
	local DudePlayer DP;
	local P2Pawn Dude;
	local APGameState GS;
	local class<Inventory> Want;
	local bool HadCop;

	GS = APState();
	if (ShouldKeepGimp())
	{
		DropGimpTrapLock();
		return;
	}
	if (!IsGimpTrapLocked())
	{
		RestoreGimpTrapCopClothes(PassedDude);
		return;
	}
	Want = GimpTrapWantedClothes();
	HadCop = GimpTrapRememberedCop();

	DP = DudePlayer(GetPlayer());
	Dude = PassedDude;
	if (Dude == None && DP != None)
		Dude = P2Pawn(DP.Pawn);
	if (DP == None && Dude != None)
		DP = DudePlayer(Dude.Controller);
	if (DP == None)
		return;

	bGimpTrap = false;
	GimpTrapPrevClothes = None;
	if (GS != None)
	{
		GS.bGimpTrap = false;
		GS.GimpTrapPrevClothes = None;
	}

	if (DP.CurrentClothes != Want)
	{
		DP.CheckForChangeClothes(Want);
		DP.ChangeToNewClothes();
	}
	DP.CurrentClothes = Want;
	if (TheGameState != None)
		TheGameState.CurrentClothes = Want;
	StripInventoryClothes(Dude, true);
	if (HadCop)
	{
		SetGimpTrapHadCop(true);
		RestoreGimpTrapCopClothes(Dude);
	}
}

function EnsureEscapeClothes(P2Pawn Dude)
{
	local DudePlayer DP;

	if (Dude == None)
		return;
	if (ShouldKeepGimp())
	{
		EnforceKeepGimp(Dude);
		return;
	}
	if (IsGimpTrapLocked())
		return;
	RestoreGimpTrapCopClothes(Dude);
	DP = DudePlayer(Dude.Controller);
	if (DP == None)
		return;
	if (DP.DudeIsGimp())
		return;
	if (DP.CurrentClothes != None
		&& ClassIsChildOf(DP.CurrentClothes, class'CopClothesInv')
		&& Dude.FindInventoryType(class'DudeClothesInv') == None)
		Dude.CreateInventoryByClass(class'DudeClothesInv');
}

function bool ClinicNeedsGonorrhea()
{
	if (ClinicNeedCached == 1)
		return true;
	if (ClinicNeedCached == 2)
		return false;
	if (!IsUnlocked("ERRAND:VisitClinic") || HasRecordedCheck("VisitClinic"))
	{
		ClinicNeedCached = 2;
		return false;
	}
	ClinicNeedCached = 1;
	return true;
}

function EnsureClinicGonorrhea()
{
	local P2Player P;
	local P2Pawn Dude;
	local PersonPawn PP;
	local UrethraWeapon U;
	local Inventory Gono;

	if (!ClinicNeedsGonorrhea())
		return;
	P = GetPlayer();
	if (P == None)
		return;
	Dude = P2Pawn(P.Pawn);
	if (Dude == None)
		return;
	PP = PersonPawn(Dude);
	if (PP != None && PP.UrethraIsInfected())
		return;

	Gono = Dude.FindInventoryType(class'GonorrheaAmmoInv');
	if (Gono == None)
		Gono = Dude.CreateInventoryByClass(class'GonorrheaAmmoInv');
	if (Gono == None)
		return;

	U = UrethraWeapon(Dude.MyUrethra);
	if (U == None)
		U = UrethraWeapon(Dude.FindInventoryType(class'UrethraWeapon'));
	if (U == None)
		return;
	U.GiveAmmo(Dude);
	if (U.IsInState('Streaming') || U.IsInState('StartStream'))
		U.ChangeStream();
}

function bool ClinicVendShouldStay(Actor A)
{
	local string S;

	if (A == None || !ClinicNeedsGonorrhea())
		return false;
	if (A.IsA('PillsPickup') || A.Tag == 'PillsPickup')
		return true;
	if (A.IsA('SceneManager') && MapKey() ~= "INDUSTRY")
		return true;
	S = Caps(string(A.Name)$" "$string(A.Tag)$" "$string(A.Event));
	if (InStr(S, "VENDACURE") != -1 || InStr(S, "PILLMAKER") != -1
		|| InStr(S, "VENDARM") != -1 || InStr(S, "VEND-A") != -1
		|| InStr(S, "URINEBUCKET") != -1)
		return true;
	return false;
}

function MaybeDispenseClinicPills()
{
	local Actor A, Best;
	local Pickup Item;
	local P2Player P;
	local P2Pawn Dude;
	local PersonPawn PP;
	local UrethraWeapon U;
	local class<Pickup> C;
	local vector Loc;
	local string S;

	if (!ClinicNeedsGonorrhea())
		return;
	if (!(MapKey() ~= "INDUSTRY"))
		return;
	P = GetPlayer();
	if (P == None)
		return;
	Dude = P2Pawn(P.Pawn);
	if (Dude == None)
		return;
	PP = PersonPawn(Dude);
	if (PP == None || !PP.UrethraIsInfected())
		return;
	U = UrethraWeapon(Dude.Weapon);
	if (U == None)
		return;
	if (!U.IsInState('Streaming') && !U.IsInState('StartStream'))
		return;

	foreach AllActors(class'Pickup', Item)
	{
		if (Item != None && !Item.bDeleteMe && Item.IsA('PillsPickup')
			&& !Item.bHidden && Item.bCollideActors)
			return;
	}

	foreach AllActors(class'Actor', A)
	{
		if (A == None)
			continue;
		S = Caps(string(A.Name)$" "$string(A.Tag)$" "$string(A.Event));
		if (InStr(S, "PILLMAKER") != -1 || InStr(S, "VENDARM") != -1)
		{
			Best = A;
			break;
		}
		if (Best == None && InStr(S, "VENDACURE") != -1)
			Best = A;
	}
	if (Best != None && VSize(Dude.Location - Best.Location) > 450)
		return;

	if (!bVendCureTriggered)
	{
		bVendCureTriggered = true;
		VendCureFallbackAt = Level.TimeSeconds + 12.0;
		TriggerEvent('vendacure', Dude, Dude);
		TriggerEvent('pillmaker', Dude, Dude);
		TriggerEvent('vendarm', Dude, Dude);
		TriggerEvent('vendacuresound', Dude, Dude);
		TriggerEvent('vendacuresound2', Dude, Dude);
		foreach AllActors(class'Actor', A)
		{
			if (A == None || A == Dude)
				continue;
			S = Caps(string(A.Name)$" "$string(A.Tag)$" "$string(A.Event));
			if (InStr(S, "VENDACURE") != -1 || InStr(S, "PILLMAKER") != -1
				|| InStr(S, "VENDARM") != -1)
			{
				if (Best == None || VSize(A.Location - Dude.Location) < 800)
					A.Trigger(Self, Dude);
			}
		}
		return;
	}

	if (Level.TimeSeconds < VendCureFallbackAt)
		return;
	if (Best != None)
		Loc = Best.Location + vect(0,0,24);
	else
		Loc = Dude.Location + vect(0,0,40);

	C = class<Pickup>(DynamicLoadObject("Inventory.PillsPickup", class'class'));
	if (C == None)
		return;
	Item = Spawn(C, None, 'PillsPickup', Loc);
	if (Item == None)
		Item = Spawn(C, None, 'PillsPickup', Dude.Location + vect(0,0,40));
	if (Item == None)
		return;
	Item.SetPhysics(PHYS_Falling);
	Item.bHidden = false;
	Item.SetCollision(true, false, false);
	if (P2PowerupPickup(Item) != None)
	{
		P2PowerupPickup(Item).bUseForErrands = true;
		P2PowerupPickup(Item).bOKToGrab = true;
		P2PowerupPickup(Item).PrepForGrabbing();
	}
}

function StartPissTrap()
{
	local P2Player P;
	local P2Pawn Dude;
	local UrethraWeapon U;

	if (IsWaitingForAPClient())
	{
		bPendingPissTrap = true;
		return;
	}

	P = GetPlayer();
	if (P == None)
		return;
	Dude = P2Pawn(P.Pawn);
	if (Dude == None)
		return;

	U = UrethraWeapon(Dude.MyUrethra);
	if (U == None)
		U = UrethraWeapon(Dude.FindInventoryType(class'UrethraWeapon'));
	if (U == None)
	{
		Dude.CreateInventoryByClass(class'UrethraWeapon');
		U = UrethraWeapon(Dude.FindInventoryType(class'UrethraWeapon'));
	}
	if (U == None)
		return;

	APPissUntil = Level.TimeSeconds + 5.0;
	ShowAPMessage("Can't hold it!");
	TickPissTrap();
}

function EndPissTrap()
{
	local P2Player P;
	local P2Pawn Dude;
	local UrethraWeapon U;
	local APDudePlayer AP;

	APPissUntil = 0;
	if (MustKeepPeeing())
		return;
	P = GetPlayer();
	if (P != None)
		Dude = P2Pawn(P.Pawn);
	if (Dude != None)
	{
		U = UrethraWeapon(Dude.MyUrethra);
		if (U == None)
			U = UrethraWeapon(Dude.FindInventoryType(class'UrethraWeapon'));
	}
	if (P != None)
	{
		P.bFire = 0;
		P.StopFiring();
	}
	if (U != None)
	{
		U.ForceEndFire();
		U.RemoveFromLineup();
		if (U.IsInState('Streaming') || U.IsInState('StartStream')
			|| U.IsInState('NormalFire'))
			U.GotoState('Idle');
	}
	if (P != None)
		P.SwitchToHands(true);
	AP = APDudePlayer(P);
	if (AP != None)
		AP.RefreshWeaponSelector();
}

function TickPissTrap()
{
	local P2Player P;
	local P2Pawn Dude;
	local UrethraWeapon U;

	if (APPissUntil <= 0)
		return;

	P = GetPlayer();
	if (P != None)
		Dude = P2Pawn(P.Pawn);
	if (Dude != None)
	{
		U = UrethraWeapon(Dude.MyUrethra);
		if (U == None)
			U = UrethraWeapon(Dude.FindInventoryType(class'UrethraWeapon'));
	}

	if (Level.TimeSeconds > APPissUntil)
	{
		EndPissTrap();
		return;
	}

	if (Level.Pauser != None || P == None || Dude == None || U == None)
		return;
	if (IsWaitingForAPClient())
		return;

	EnsureClinicGonorrhea();

	if (Dude.Weapon != U)
		P.SwitchToThisWeapon(class'UrethraWeapon'.default.InventoryGroup,
			class'UrethraWeapon'.default.GroupOffset, true);

	if (Dude.Weapon == U
		&& !U.IsInState('Streaming')
		&& !U.IsInState('StartStream'))
		U.Fire(1.0);
}

event Tick(float DeltaTime)
{
	Super.Tick(DeltaTime);
	KickBridge();
	TickPissTrap();
	TickPissRealism();
	TickMapTokCounts();
	TickStartDayReload();
	TickClientGate();
}

function vector FloorNear(vector Loc)
{
	local vector HitL, HitN, Start, End;

	Start = Loc;
	Start.Z += 120;
	End = Loc;
	End.Z -= 800;
	if (Trace(HitL, HitN, End, Start, false) != None)
		return HitL + vect(0,0,72);
	return Loc;
}

function bool WalkableFloor(vector Loc, P2Pawn Dude, out vector OutLoc)
{
	local vector HitL, HitN, Start, End;
	local float Dist;

	if (Dude == None)
		return false;
	Start = Loc;
	Start.Z = Start.Z + 120;
	End = Loc;
	End.Z = End.Z - 700;
	if (Trace(HitL, HitN, End, Start, false) == None)
		return false;
	if (HitN.Z < 0.35)
		return false;
	OutLoc = HitL;
	OutLoc.Z = OutLoc.Z + 72;
	if (Abs(OutLoc.Z - Dude.Location.Z) > 220)
		return false;
	Dist = VSize(OutLoc - Dude.Location);
	if (Dist < 1000 || Dist > 4800)
		return false;
	return true;
}

function bool PickBomberSpawn(P2Pawn Dude, out vector OutLoc)
{
	local NavigationPoint N;
	local vector Cand, Offset;
	local rotator R;
	local float Dist, BestDiff, Diff;
	local int i;
	local bool bGot;

	if (Dude == None)
		return false;
	BestDiff = 99999;
	foreach RadiusActors(class'NavigationPoint', N, 4800, Dude.Location)
	{
		if (N == None || Teleporter(N) != None)
			continue;
		if (!WalkableFloor(N.Location, Dude, Cand))
			continue;
		Dist = VSize(Cand - Dude.Location);
		Diff = Dist - 2400;
		if (Diff < 0)
			Diff = -Diff;
		if (!bGot || Diff < BestDiff)
		{
			bGot = true;
			BestDiff = Diff;
			OutLoc = Cand;
		}
	}
	if (bGot)
		return true;
	for (i = 0; i < 16; i++)
	{
		R.Yaw = i * 4096;
		R.Pitch = 0;
		R.Roll = 0;
		Offset = vector(R);
		Offset.Z = 0;
		Cand = Dude.Location + Offset * (1200 + (i % 4) * 900);
		if (WalkableFloor(Cand, Dude, OutLoc))
			return true;
	}
	return false;
}

function SpawnSuicideBomberTrap(P2Pawn Dude)
{
	local APSuicideBomber Guy;
	local APSuicideBomberController PC;
	local vector Loc;
	local int Tries;
	local rotator Face;

	if (Dude == None)
		return;
	for (Tries = 0; Tries < 8; Tries++)
	{
		if (!PickBomberSpawn(Dude, Loc))
			break;
		Face = rotator(Dude.Location - Loc);
		Face.Pitch = 0;
		Face.Roll = 0;
		Guy = Spawn(class'APSuicideBomber',,, Loc, Face);
		if (Guy != None)
			break;
	}
	if (Guy == None)
	{
		ShowAPMessage("Suicide bomber could not find ground.");
		return;
	}
	Guy.Prey = Dude;
	Guy.bStasis = false;
	Guy.bPlayerIsEnemy = true;
	Guy.SetCollision(true, true, true);
	Guy.SetPhysics(PHYS_Falling);
	Guy.BaseEquipment.Length = 0;
	if (Guy.Controller == None)
	{
		PC = Spawn(class'APSuicideBomberController');
		if (PC != None)
			PC.Possess(Guy);
	}
	Guy.StripGuns();
	PC = APSuicideBomberController(Guy.Controller);
	if (PC != None)
		PC.StartChase(Dude);
	Guy.PlayChargeScream();
	ShowAPMessage("Suicide bomber incoming!");
}

function SpawnAngryProtestor(vector Loc, P2Pawn Dude)
{
	local Protestors Guy;
	local PersonController PC;

	Guy = Spawn(class'RWSProtestors',,, Loc, Dude.Rotation);
	if (Guy == None)
		return;
	Guy.bStasis = false;
	Guy.bProjTarget = true;
	Guy.bBlockActors = true;
	Guy.bBlockPlayers = true;
	Guy.SetCollision(true, true, true);
	Guy.SetPhysics(PHYS_Falling);
	Guy.DestroyBolton(0);
	if (Guy.Controller == None)
	{
		Guy.Controller = Spawn(class'BystanderController');
		if (Guy.Controller != None)
			Guy.Controller.Possess(Guy);
	}
	PC = PersonController(Guy.Controller);
	if (PC != None)
		PC.SetToAttackPlayer(Dude);
}

function APGameState APState()
{
	return APGameState(TheGameState);
}

function bool IsUnlocked(string Key)
{
	if (APState() == None)
		return false;
	return APState().HasUnlock(Key);
}

function bool IsWeaponAllowed(class<Inventory> InvType)
{
	local int i, n;
	local class<Inventory> UnlockedClass;
	local APGameState GS;

	if (InvType == None)
		return true;
	if (ClassIsChildOf(InvType, class'UrethraWeapon')
		|| ClassIsChildOf(InvType, class'HandsWeapon')
		|| ClassIsChildOf(InvType, class'FootWeapon'))
		return true;

	GS = APState();
	if (GS == None)
		return false;

	n = GS.Unlocks.Length;
	if (n > 128)
		n = 128;
	for (i = 0; i < n; i++)
	{
		UnlockedClass = class<Inventory>(DynamicLoadObject(GS.Unlocks[i], class'class'));
		if (UnlockedClass == None)
			continue;
		if (InvType == UnlockedClass)
			return true;
		if (ClassIsChildOf(InvType, UnlockedClass) && !IsSeparateUnlockWeapon(InvType))
			return true;
	}
	return false;
}

function bool IsSeparateUnlockWeapon(class<Inventory> InvType)
{
	if (InvType == None)
		return false;
	if (InvType == class'BoxLauncherWeapon')
		return true;
	if (InvType == class'CatLauncherWeapon')
		return true;
	if (InvType == class'MrDKNadeWeapon')
		return true;
	return false;
}

function class<Ammunition> WeaponAmmoClass(class<Inventory> InvType)
{
	local class<P2Weapon> WC;

	WC = class<P2Weapon>(InvType);
	if (WC == None)
		return None;
	return WC.default.AmmoName;
}

function bool AmmoClassesMatch(class<Ammunition> A, class<Ammunition> B)
{
	if (A == None || B == None)
		return false;
	if (A == B || ClassIsChildOf(A, B) || ClassIsChildOf(B, A))
		return true;
	return false;
}

function bool UnlockedWeaponUsesAmmo(class<Ammunition> AmmoClass)
{
	local int i, n;
	local class<Inventory> IC;
	local class<Ammunition> AC;
	local APGameState GS;

	if (AmmoClass == None)
		return false;
	GS = APState();
	if (GS == None)
		return false;
	n = GS.Unlocks.Length;
	if (n > 128)
		n = 128;
	for (i = 0; i < n; i++)
	{
		IC = class<Inventory>(DynamicLoadObject(GS.Unlocks[i], class'class'));
		AC = WeaponAmmoClass(IC);
		if (AmmoClassesMatch(AC, AmmoClass))
			return true;
	}
	return false;
}

function bool DudeOwnsWeaponUsingAmmo(Pawn Dude, class<Ammunition> AmmoClass)
{
	local Inventory Inv;
	local P2Weapon W;

	if (Dude == None || AmmoClass == None)
		return false;
	for (Inv = Dude.Inventory; Inv != None; Inv = Inv.Inventory)
	{
		W = P2Weapon(Inv);
		if (W == None)
			continue;
		if (!IsWeaponAllowed(W.Class))
			continue;
		if (AmmoClassesMatch(W.AmmoName, AmmoClass))
			return true;
	}
	return false;
}

function string AmmoNiceName(class<Ammunition> AmmoClass)
{
	local string C;

	if (AmmoClass == None)
		return "ammo";
	C = Caps(string(AmmoClass));
	if (InStr(C, "SHOTGUN") != -1)
		return "shotgun shells";
	if (InStr(C, "PISTOL") != -1)
		return "pistol ammo";
	if (InStr(C, "NINEAMMO") != -1)
		return "9mm ammo";
	if (InStr(C, "GASCAN") != -1)
		return "gasoline";
	if (InStr(C, "MACHINEGUN") != -1)
		return "machine gun ammo";
	if (InStr(C, "RIFLE") != -1)
		return "rifle rounds";
	if (InStr(C, "GRENADE") != -1)
		return "grenades";
	if (InStr(C, "LAUNCHER") != -1)
		return "rockets";
	return "ammo";
}

function bool GiveSharedAmmoToDude(Pawn Dude, class<Ammunition> AmmoClass, int Amount)
{
	local Inventory Inv;
	local Ammunition Am;

	if (Dude == None || AmmoClass == None || Amount <= 0)
		return false;
	for (Inv = Dude.Inventory; Inv != None; Inv = Inv.Inventory)
	{
		Am = Ammunition(Inv);
		if (Am != None && AmmoClassesMatch(Am.Class, AmmoClass))
		{
			Am.AddAmmo(Amount);
			return true;
		}
	}
	Am = Spawn(AmmoClass);
	if (Am == None)
		return false;
	Dude.AddInventory(Am);
	Am.AddAmmo(Amount);
	return true;
}

function bool SiphonAmmoFromLockedWeapon(Pawn Dude, Pickup Item)
{
	local P2WeaponPickup WP;
	local class<P2Weapon> WC;
	local class<Ammunition> AC;
	local int Amt;

	WP = P2WeaponPickup(Item);
	if (WP == None || Dude == None)
		return false;
	WC = class<P2Weapon>(Item.InventoryType);
	if (WC == None)
		return false;
	AC = WC.default.AmmoName;
	if (AC == None || !DudeOwnsWeaponUsingAmmo(Dude, AC))
		return false;
	Amt = WP.AmmoGiveCount;
	if (Amt <= 0)
		Amt = 1;
	if (!GiveSharedAmmoToDude(Dude, AC, Amt))
		return false;
	ShowAPMessage("Picked up "$AmmoNiceName(AC)$".");
	PlayAPSound(true);
	if (TheGameState != None && WP.bRecordAfterPickup)
		TheGameState.RecordPickup(Item.Name);
	Item.Destroy();
	return true;
}

function UnlockItem(string ClassName)
{
	local APGameState GS;
	local P2Pawn Dude;
	local bool bNew;

	ClinicNeedCached = 0;
	bNew = !IsUnlocked(ClassName);
	GS = APState();
	if (GS != None)
		GS.AddUnlock(ClassName);

	if (Left(ClassName, 4) ~= "DAY:")
	{
		if (bNew)
		{
			ShowAPMessage("Day of the Week: you can go to "$Mid(ClassName, 4)$" now!");
			PlayAPSound(true);
			ApplyAreaLocks();
			PickFeaturedErrandForGrant(ClassName);
		}
		return;
	}
	if (Left(ClassName, 5) ~= "AREA:")
	{
		if (bNew)
		{
			ShowAPMessage("You can enter "$Mid(ClassName, 5)$" now!");
			PlayAPSound(true);
			ApplyAreaLocks();
		}
		return;
	}
	if (Left(ClassName, 7) ~= "ERRAND:")
	{
		if (bNew)
		{
			UnlockCampaignErrand(Mid(ClassName, 7));
			PlayAPSound(true);
		}
		return;
	}
	if (Left(ClassName, 5) ~= "WARP:")
	{
		if (bNew)
		{
			ShowAPMessage("Time Warp: "$WarpPointLabelFromGrant(ClassName)$" is open.");
			PlayAPSound(true);
		}
		return;
	}

	if (GetPlayer() != None)
		Dude = P2Pawn(GetPlayer().Pawn);
	if (Dude != None)
		TryGiveAPItem(ClassName, 0, !bNew);

	if (bNew)
	{
		PlayAPSound(true);
		bVendorDirty = true;
	}

	ActivateIfUnlocked(ClassName);
}

function GiveFiller(string ClassName, int Amount, int Index)
{
	local APGameState GS;

	GS = APState();
	if (GS != None)
	{
		if (GS.HasFiller(Index))
			return;
		GS.RecordFiller(Index);
	}
	if (ClassName ~= "OWNEDAMMO")
		GiveOwnedWeaponAmmo(Amount);
	else
		GiveAPItem(ClassName, Amount);
	PlayAPSound(true);
}

function GiveOwnedWeaponAmmo(int Amount)
{
	local P2Player P;
	local P2Pawn Dude;
	local Inventory Inv;
	local P2Weapon Weap, PickWeap;
	local P2Weapon Cands[16];
	local int N, i, Add;

	P = GetPlayer();
	if (P != None)
		Dude = P2Pawn(P.Pawn);
	if (Dude == None)
		return;

	for (Inv = Dude.Inventory; Inv != None; Inv = Inv.Inventory)
	{
		Weap = P2Weapon(Inv);
		if (Weap == None)
			continue;
		if (HandsWeapon(Weap) != None
			|| FootWeapon(Weap) != None
			|| UrethraWeapon(Weap) != None
			|| ClipboardWeapon(Weap) != None
			|| CellPhoneWeapon(Weap) != None
			|| MatchesWeapon(Weap) != None)
			continue;
		if (MeleeDurabilityEnabled() && IsDurabilityMelee(Weap)
			&& GetMeleeDur(Weap) < 100)
		{
			if (N < 16)
			{
				Cands[N] = Weap;
				N++;
			}
			continue;
		}
		if (Weap.AmmoName == None)
			continue;
		if (Weap.bMeleeWeapon && InStr(Caps(string(Weap.AmmoName)), "GAS") == -1)
			continue;
		if (N < 16)
		{
			Cands[N] = Weap;
			N++;
		}
	}

	if (N == 0)
	{
		ShowAPMessage("No guns to load. Here's $20 instead.");
		GiveAPItem("Inventory.MoneyInv", 20);
		return;
	}

	PickWeap = Cands[Rand(N)];
	if (TryRepairMeleeWeapon(PickWeap))
		return;
	Add = SpareAmmoForWeapon(PickWeap);
	if (Add <= 0)
		Add = Amount;
	if (Add <= 0)
		Add = 1;
	PickWeap.GiveAmmoFromPickup(Dude, Add);
	if (PickWeap.ItemName != "")
		ShowAPMessage("Spare ammo for the "$PickWeap.ItemName$".");
	else
		ShowAPMessage("Spare ammo loaded.");
}

function int SpareAmmoForWeapon(P2Weapon Weap)
{
	local int MaxA;

	if (Weap == None)
		return 0;
	if (Weap.AmmoType != None && Weap.AmmoType.MaxAmmo > 0)
		MaxA = Weap.AmmoType.MaxAmmo;
	else if (Weap.AmmoName != None && Weap.AmmoName.default.MaxAmmo > 0)
		MaxA = Weap.AmmoName.default.MaxAmmo;
	if (MaxA <= 0)
		return 0;
	MaxA = (MaxA * 3) / 10;
	if (MaxA < 1)
		MaxA = 1;
	return MaxA;
}

function P2Weapon FindOwnedWeaponForPickup(P2Pawn Dude, Pickup Item)
{
	local class<Inventory> T, ShortT;
	local P2Weapon Weap;

	if (Dude == None || Item == None)
		return None;
	T = Item.InventoryType;
	if (T != None)
	{
		Weap = P2Weapon(Dude.FindInventoryType(T));
		if (Weap != None)
			return Weap;
	}
	if (P2WeaponPickup(Item) != None)
		ShortT = P2WeaponPickup(Item).ShortSleeveType;
	if (ShortT != None)
		Weap = P2Weapon(Dude.FindInventoryType(ShortT));
	return Weap;
}

function bool TryRepairMeleeWeapon(P2Weapon Weap)
{
	local int Dur, NewDur;
	local string N;

	if (Weap == None || !IsDurabilityMelee(Weap))
		return false;
	Dur = GetMeleeDur(Weap);
	if (Dur >= 100)
		return false;
	NewDur = Dur + 30;
	if (NewDur > 100)
		NewDur = 100;
	SetMeleeDur(Weap, NewDur);
	N = Weap.ItemName;
	if (N == "")
		N = "melee weapon";
	ShowAPMessage("You partially repaired your "$N$".");
	return true;
}

function bool RepairMeleeFromPickup(P2Pawn Dude, Pickup Item)
{
	local P2Weapon Weap;
	local P2AmmoInv Ammo;

	if (Dude == None || Item == None)
		return false;
	Weap = FindOwnedWeaponForPickup(Dude, Item);
	if (Weap == None || !IsDurabilityMelee(Weap))
		return false;
	Ammo = P2AmmoInv(Weap.AmmoType);
	if (Ammo != None && !Ammo.bInfinite)
		return false;
	if (!TryRepairMeleeWeapon(Weap))
		return false;
	if (Item.PickupSound != None)
		Dude.PlaySound(Item.PickupSound,,2.0);
	if (TheGameState != None && P2WeaponPickup(Item) != None
		&& P2WeaponPickup(Item).bRecordAfterPickup)
		TheGameState.RecordPickup(Item.Name);
	Item.SetRespawn();
	return true;
}

function bool MeleeDurabilityEnabled()
{
	local APGameState GS;
	GS = APState();
	if (GS != None && GS.bGotOptions)
		return GS.bMeleeDurability;
	return false;
}

function bool PissRealismEnabled()
{
	local APGameState GS;
	GS = APState();
	if (GS != None && GS.bGotOptions)
		return GS.bPissRealism;
	return false;
}

function int PissRegenSeconds()
{
	local APGameState GS;
	local int S;

	S = 120;
	GS = APState();
	if (GS != None && GS.PissRegen > 0)
		S = GS.PissRegen;
	if (S < 30)
		S = 30;
	if (S > 180)
		S = 180;
	return S;
}

function ApplyPissRealismToDude(P2Pawn Dude)
{
	local UrethraWeapon U;
	local UrethraAmmoInv Ammo;
	local APGameState GS;

	if (Dude == None)
		return;
	U = UrethraWeapon(Dude.MyUrethra);
	if (U == None)
		U = UrethraWeapon(Dude.FindInventoryType(class'UrethraWeapon'));
	if (U == None)
		return;
	Ammo = UrethraAmmoInv(U.AmmoType);
	if (Ammo == None)
		Ammo = UrethraAmmoInv(Dude.FindInventoryType(class'UrethraAmmoInv'));
	if (PissRealismEnabled())
	{
		U.AmmoGainRate = 1.0 / float(PissRegenSeconds());
		if (Ammo != None)
		{
			Ammo.MaxAmmo = 20;
			GS = APState();
			if (GS != None && !GS.bPissRealismPrimed)
			{
				Ammo.AmmoAmount = 1;
				GS.bPissRealismPrimed = true;
			}
			if (Ammo.AmmoAmount > Ammo.MaxAmmo)
				Ammo.AmmoAmount = Ammo.MaxAmmo;
		}
	}
	else
		U.AmmoGainRate = U.default.AmmoGainRate;
}

function TickPissRealism()
{
	local P2Player P;
	local P2Pawn Dude;
	local UrethraWeapon U;
	local int Amt;
	local bool bStreaming;

	P = GetPlayer();
	if (P == None)
		return;
	Dude = P2Pawn(P.Pawn);
	ApplyPissRealismToDude(Dude);
	if (!PissRealismEnabled())
		return;
	if (IsWaitingForAPClient() || Level.Pauser != None)
		return;
	if (Dude == None || Dude.Health <= 0)
		return;
	U = UrethraWeapon(Dude.MyUrethra);
	if (U == None)
		U = UrethraWeapon(Dude.FindInventoryType(class'UrethraWeapon'));
	Amt = 0;
	if (U != None && U.AmmoType != None)
		Amt = U.AmmoType.AmmoAmount;
	bStreaming = (U != None && (U.IsInState('Streaming') || U.IsInState('StartStream')));
	if (Amt >= 18 && !bStreaming && Level.TimeSeconds >= PissComplainAt)
	{
		P.CommentOnNeedingToPee();
		PissComplainAt = Level.TimeSeconds + 14.0;
	}
	if (Amt >= 20 && !bStreaming && Level.TimeSeconds >= PissDamageAt)
	{
		Dude.TakeDamage(1, Dude, Dude.Location, vect(0,0,0), class'GonorrheaDamage');
		PissDamageAt = Level.TimeSeconds + 1.0;
	}
}

function AddPiss(P2Pawn Dude, int N)
{
	local UrethraWeapon U;
	local Ammunition Ammo;

	if (Dude == None || N <= 0)
		return;
	U = UrethraWeapon(Dude.MyUrethra);
	if (U == None)
		U = UrethraWeapon(Dude.FindInventoryType(class'UrethraWeapon'));
	if (U != None)
		Ammo = U.AmmoType;
	if (Ammo == None)
		Ammo = Ammunition(Dude.FindInventoryType(class'UrethraAmmoInv'));
	if (Ammo == None)
		return;
	if (PissRealismEnabled())
		Ammo.MaxAmmo = 20;
	Ammo.AddAmmo(N);
}

function bool DrinkWaterBottle(P2Pawn Dude)
{
	if (Dude == None)
		return false;
	Dude.PlaySound(Sound'xItemSounds.DualWield.CrackolaDrink');
	AddPiss(Dude, 5);
	ShowAPMessage("Your bladder fills a little.");
	return true;
}

function bool IsDurabilityMelee(P2Weapon Weap)
{
	if (Weap == None || !Weap.bMeleeWeapon)
		return false;
	if (HandsWeapon(Weap) != None || FootWeapon(Weap) != None
		|| UrethraWeapon(Weap) != None || ClipboardWeapon(Weap) != None
		|| CellPhoneWeapon(Weap) != None || MatchesWeapon(Weap) != None
		|| ShockerWeapon(Weap) != None)
		return false;
	if (Weap.AmmoName != None && InStr(Caps(string(Weap.AmmoName)), "GAS") != -1)
		return false;
	return true;
}

function string MeleeDurKeyOf(P2Weapon Weap)
{
	if (Weap == None)
		return "";
	return Caps(string(Weap.Class));
}

function int GetMeleeDur(P2Weapon Weap)
{
	local APGameState GS;
	local string K;
	local int i;

	if (!MeleeDurabilityEnabled() || !IsDurabilityMelee(Weap))
		return 100;
	GS = APState();
	if (GS == None)
		return 100;
	K = MeleeDurKeyOf(Weap);
	for (i = 0; i < GS.MeleeDurKey.Length; i++)
		if (GS.MeleeDurKey[i] ~= K)
			return GS.MeleeDurVal[i];
	return 100;
}

function SetMeleeDur(P2Weapon Weap, int Val)
{
	local APGameState GS;
	local string K;
	local int i;

	GS = APState();
	if (GS == None || Weap == None)
		return;
	if (Val < 0)
		Val = 0;
	if (Val > 100)
		Val = 100;
	K = MeleeDurKeyOf(Weap);
	for (i = 0; i < GS.MeleeDurKey.Length; i++)
	{
		if (GS.MeleeDurKey[i] ~= K)
		{
			GS.MeleeDurVal[i] = Val;
			return;
		}
	}
	i = GS.MeleeDurKey.Length;
	GS.MeleeDurKey.Length = i + 1;
	GS.MeleeDurVal.Length = i + 1;
	GS.MeleeDurKey[i] = K;
	GS.MeleeDurVal[i] = Val;
}

function bool IsMeleeBroken(P2Weapon Weap)
{
	return MeleeDurabilityEnabled() && IsDurabilityMelee(Weap) && GetMeleeDur(Weap) <= 0;
}

function NoteMeleeHit(Pawn InstigatedBy, Pawn Injured, class<DamageType> DamageType)
{
	local P2Weapon Weap;
	local int Dur, Wear;
	local string N;

	if (!MeleeDurabilityEnabled() || InstigatedBy == None || Injured == None)
		return;
	if (Injured == InstigatedBy)
		return;
	if (DamageType == None || !ClassIsChildOf(DamageType, class'BludgeonDamage'))
		return;
	Weap = P2Weapon(InstigatedBy.Weapon);
	if (!IsDurabilityMelee(Weap) || IsMeleeBroken(Weap))
		return;
	Wear = Rand(7) + 1;
	Dur = GetMeleeDur(Weap) - Wear;
	SetMeleeDur(Weap, Dur);
	if (Dur <= 0)
	{
		N = Weap.ItemName;
		if (N == "")
			N = "weapon";
		ShowAPMessage("Your "$N$" is broken.");
	}
}

function bool UseRepairKit(P2Pawn Dude)
{
	local P2Weapon Weap;
	local string N;

	if (!MeleeDurabilityEnabled())
	{
		ShowAPMessage("Weapon durability is off.");
		return false;
	}
	if (Dude == None)
		return false;
	Weap = P2Weapon(Dude.Weapon);
	if (!IsDurabilityMelee(Weap))
	{
		ShowAPMessage("Equip a melee weapon to repair it.");
		return false;
	}
	if (GetMeleeDur(Weap) >= 100)
	{
		ShowAPMessage("That weapon is already in good shape.");
		return false;
	}
	SetMeleeDur(Weap, 100);
	N = Weap.ItemName;
	if (N == "")
		N = "weapon";
	ShowAPMessage("Repaired your "$N$".");
	return true;
}

function int ReduceDamage(int Damage, pawn injured, pawn instigatedBy, vector HitLocation, out vector Momentum, class<DamageType> DamageType)
{
	local int Orig, D;

	Orig = Damage;
	D = Super.ReduceDamage(Damage, injured, instigatedBy, HitLocation, Momentum, DamageType);
	if (Orig > 0 && instigatedBy != None && injured != None
		&& P2Player(instigatedBy.Controller) != None)
		NoteMeleeHit(instigatedBy, injured, DamageType);
	return D;
}

function GiveTimeWarp(P2Pawn Dude)
{
	local APTimeWarpInv Inv;

	if (Dude == None)
		return;
	Inv = APTimeWarpInv(Dude.FindInventoryType(class'APTimeWarpInv'));
	if (Inv == None)
	{
		Dude.CreateInventory("Archipelago.APTimeWarpInv");
		Inv = APTimeWarpInv(Dude.FindInventoryType(class'APTimeWarpInv'));
	}
	if (Inv != None && Inv.Amount < 1)
		Inv.Amount = 1;
	if (Inv != None && MustWalkHomeApocalypse())
		Inv.BreakWarp();
}

function int StartDayIndex()
{
	local APGameState GS;

	GS = APState();
	if (GS == None)
		return 0;
	if (GS.APStartDay < 0)
		return 0;
	if (GS.APStartDay > 4)
		return 4;
	return GS.APStartDay;
}

function bool WantStartDayWait()
{
	local APGameState GS;

	if (StartDayWaitLeft <= 0)
		return false;
	if (IsIntroMap() || IsCinematic() || IsMainMenuMap())
		return false;
	if (!(MapKey() ~= "SUBURBS-3"))
		return false;
	GS = APState();
	if (GS != None && GS.bGotStartDay)
		return false;
	EnsureBridge();
	KickBridge();
	StartDayWaitLeft--;
	return true;
}

function bool IsDayUnlocked(int Day)
{
	if (Day == StartDayIndex())
		return true;
	if (Day <= 0)
		return IsUnlocked("DAY:Monday");
	if (Day == 1)
		return IsUnlocked("DAY:Tuesday");
	if (Day == 2)
		return IsUnlocked("DAY:Wednesday");
	if (Day == 3)
		return IsUnlocked("DAY:Thursday");
	if (Day == 4)
		return IsUnlocked("DAY:Friday");
	return false;
}

function SilentUnlockDay(int Day)
{
	local string Key;
	local APGameState GS;

	if (Day < 0 || Day > 4)
		return;
	if (Day == 0)
		Key = "DAY:Monday";
	else if (Day == 1)
		Key = "DAY:Tuesday";
	else if (Day == 2)
		Key = "DAY:Wednesday";
	else if (Day == 3)
		Key = "DAY:Thursday";
	else
		Key = "DAY:Friday";
	if (IsUnlocked(Key))
		return;
	GS = APState();
	if (GS != None)
		GS.AddUnlock(Key);
}

function ApplyStartDay()
{
	local APGameState GS;
	local int D, OldDay;

	if (TheGameState == None)
		return;
	if (IsIntroMap() || IsCinematic() || IsMainMenuMap())
		return;
	GS = APState();
	if (GS == None || !GS.bGotStartDay)
		return;
	if (GS.bStartDayApplied)
		return;
	D = StartDayIndex();
	OldDay = TheGameState.CurrentDay;
	TheGameState.CurrentDay = D;
	TheGameState.bChangeDayPostTravel = false;
	TheGameState.bFirstLevelOfDay = false;
	GS.bStartDayApplied = true;
	SilentUnlockDay(D);
	ApplyAreaLocks();
	ApplyGatedErrands(true);
	NextGlowUpdate = 0;
	if (OldDay != D && !IsInState('StartUp'))
	{
		bPendingStartDayReload = true;
		StartDayReloadAt = Level.TimeSeconds + 1.5;
	}
}

function TickStartDayReload()
{
	local P2Player P;

	if (!bPendingStartDayReload)
		return;
	if (Level.TimeSeconds < StartDayReloadAt)
		return;
	bPendingStartDayReload = false;
	if (IsIntroMap() || IsCinematic() || IsMainMenuMap())
		return;
	P = GetPlayer();
	if (P != None)
		SendPlayerTo(P, StartFirstDayURL);
}

function string ErrandNiceName(string UniqueName)
{
	if (UniqueName ~= "GetPaycheck") return "Pick up paycheck";
	if (UniqueName ~= "CashPaycheck") return "Cash paycheck";
	if (UniqueName ~= "GetMilk") return "Get milk";
	if (UniqueName ~= "VisitPriest") return "Confess sins";
	if (UniqueName ~= "GetSignatures") return "Petition";
	if (UniqueName ~= "ReturnBook") return "Return book";
	if (UniqueName ~= "GetGary") return "Gary autograph";
	if (UniqueName ~= "VisitDad") return "Piss on dad";
	if (UniqueName ~= "Vote") return "Vote";
	if (UniqueName ~= "GetTree") return "Get xmas tree";
	if (UniqueName ~= "PickupLaundry") return "Pickup laundry";
	if (UniqueName ~= "GetNapalm") return "Get napalm launcher";
	if (UniqueName ~= "GetKrotchy") return "Get Krotchy";
	if (UniqueName ~= "GetSteaks") return "Get steaks";
	if (UniqueName ~= "PayTicket") return "Pay ticket";
	if (UniqueName ~= "GetAlternator") return "Get alternator";
	if (UniqueName ~= "PickupPackage") return "Pick up package";
	if (UniqueName ~= "GivePresent") return "Uncle Dave's birthday";
	if (UniqueName ~= "VisitClinic") return "Clinic";
	return UniqueName;
}

function string TimeWarpDayLine(int Day)
{
	local string Line, Name;
	if (Days.Length <= Day)
		return string(Day + 1);
	Name = Days[Day].Description;
	Line = string(Day + 1)$"  "$Name;
	if (TheGameState != None && TheGameState.CurrentDay == Day)
		Line = Line$"  (now)";
	if (!IsDayUnlocked(Day))
		Line = Line$"  LOCKED";
	else
		Line = Line$"  open";
	return Line;
}

function string TimeWarpErrandLine(int Day)
{
	local int i;
	local string S, U, Nice;
	local APGameState GS;
	local ErrandBase E;

	if (!IsDayUnlocked(Day) || Days.Length <= Day)
		return "";
	GS = APState();
	for (i = 0; i < Days[Day].Errands.Length; i++)
	{
		E = Days[Day].Errands[i];
		if (E == None)
			continue;
		U = E.UniqueName;
		if (IsAnyDayErrand(U))
			continue;
		if (!IsUnlocked("ERRAND:"$U) && !(E.bCompleted || HasRecordedCheck(U)))
			continue;
		Nice = ErrandNiceName(U);
		if (E.bCompleted || HasRecordedCheck(U))
			Nice = Nice$" (done)";
		else if (GS != None && GS.FeaturedErrand[Day] ~= U)
			Nice = "* "$Nice;
		if (S == "")
			S = Nice;
		else
			S = S$", "$Nice;
	}
	return S;
}

function string TimeWarpPetitionLine()
{
	if (!IsUnlocked("ERRAND:GetSignatures") && !HasRecordedCheck("GetSignatures"))
		return "";
	if (HasRecordedCheck("GetSignatures"))
		return "Petition (done)";
	return "Petition";
}

function PickFeaturedErrandForGrant(string DayGrant)
{
	local int Day, i, Pick;
	local array<int> Cands;
	local string U, Nice;
	local APGameState GS;

	if (DayGrant ~= "DAY:Tuesday") Day = 1;
	else if (DayGrant ~= "DAY:Wednesday") Day = 2;
	else if (DayGrant ~= "DAY:Thursday") Day = 3;
	else if (DayGrant ~= "DAY:Friday") Day = 4;
	else return;
	if (Days.Length <= Day)
		return;
	GS = APState();
	if (GS == None)
		return;
	if (GS.FeaturedErrand[Day] != "")
		return;
	for (i = 0; i < Days[Day].Errands.Length; i++)
	{
		if (Days[Day].Errands[i] == None)
			continue;
		if (Days[Day].Errands[i].bCompleted)
			continue;
		if (IsVanillaFollowupErrand(Days[Day].Errands[i].UniqueName))
			continue;
		Cands[Cands.Length] = i;
	}
	if (Cands.Length == 0)
		return;
	Pick = Cands[Rand(Cands.Length)];
	U = Days[Day].Errands[Pick].UniqueName;
	GS.FeaturedErrand[Day] = U;
	GS.AddUnlock("ERRAND:"$U);
	UnlockCampaignErrand(U);
	Nice = ErrandNiceName(U);
	ShowAPMessage(Days[Day].Description$" unlocked. Try: "$Nice);
}

function bool IsCampaignErrand(string UniqueName)
{
	local int d, e;

	if (UniqueName == "")
		return false;
	for (d = 0; d < Days.Length; d++)
	{
		if (Days[d] == None)
			continue;
		for (e = 0; e < Days[d].Errands.Length; e++)
			if (Days[d].Errands[e] != None && Days[d].Errands[e].UniqueName ~= UniqueName)
				return true;
	}
	return false;
}

function bool IsVanillaFollowupErrand(string UniqueName)
{
	return UniqueName ~= "PickupLaundry";
}

function bool IsErrandActiveByName(string UniqueName)
{
	local int Day, Errand;

	if (!FindErrand(UniqueName, Day, Errand))
		return false;
	if (Days[Day] == None)
		return false;
	return Days[Day].IsErrandActive(Errand);
}

function bool IsGatedCampaignErrand(string UniqueName)
{
	if (IsVanillaFollowupErrand(UniqueName))
		return false;
	return IsCampaignErrand(UniqueName);
}

function UnlockCampaignErrand(string UniqueName)
{
	local int Day, Errand;
	local P2Player P;
	local bool bWasActive;

	if (UniqueName == "")
		return;
	if (IsAnyDayErrand(UniqueName))
		EnsureAnyDayPetition();
	if (!FindErrand(UniqueName, Day, Errand) || Days[Day] == None)
		return;
	bWasActive = Days[Day].IsErrandActive(Errand);
	SetErrandAvailable(UniqueName, true, true);
	GrantErrandTools(UniqueName);
	if (TheGameState != None && GameStateHasErrand(Day, Errand))
		SendCheck(UniqueName);
	else if (TheGameState != None && !GameStateHasErrand(Day, Errand))
		Days[Day].Errands[Errand].bCompleted = false;
	if (!IsAnyDayErrand(UniqueName))
		UnlockDayFromErrand(Day);
	if (IsAnyDayErrand(UniqueName))
		ShowAPMessage("New errand (any day): "$ErrandNiceName(UniqueName));
	else
		ShowAPMessage("New errand on "$Days[Day].Description$": "$ErrandNiceName(UniqueName));
	RefreshMapErrands();
	if (!bWasActive && TheGameState != None && (IsAnyDayErrand(UniqueName) || Day == TheGameState.CurrentDay))
	{
		P = GetPlayer();
		if (P != None && CanPopupErrandMap())
			P.DisplayMapErrands();
	}
}

function UnlockDayFromErrand(int Day)
{
	local string Key;
	local APGameState GS;

	if (Day == StartDayIndex())
		return;
	if (Day < 0 || Day > 4)
		return;
	if (Day == 0)
		Key = "DAY:Monday";
	else if (Day == 1)
		Key = "DAY:Tuesday";
	else if (Day == 2)
		Key = "DAY:Wednesday";
	else if (Day == 3)
		Key = "DAY:Thursday";
	else
		Key = "DAY:Friday";
	if (IsUnlocked(Key))
		return;
	GS = APState();
	if (GS != None)
		GS.AddUnlock(Key);
	ShowAPMessage("You can Time Warp to "$Days[Day].Description$" now.");
	ApplyAreaLocks();
	NextGlowUpdate = 0;
	bVendorDirty = true;
}

function GrantErrandTools(string UniqueName)
{
	// The errand item *is* the tool. Receiving "Errand - Cash Paycheck"
	// both activates the chore and puts the check in your inventory.
	if (UniqueName ~= "CashPaycheck")
		UnlockItem("Inventory.PaycheckInv");
	else if (UniqueName ~= "ReturnBook")
		UnlockItem("Inventory.LibraryBookInv");
	else if (UniqueName ~= "GetSignatures")
		UnlockItem("Inventory.ClipboardWeapon");
	else if (UniqueName ~= "PayTicket")
		UnlockItem("Inventory.CitationInv");
	else if (UniqueName ~= "GivePresent")
		UnlockItem("Inventory.GiftInv");
	else if (UniqueName ~= "VisitClinic")
		EnsureClinicGonorrhea();
	RestoreErrandPickupsOnMap();
}

function RestoreErrandPickupsOnMap()
{
	local Pickup Item;
	local APCheckGlow Glow;
	local bool bDid;

	foreach AllActors(class'Pickup', Item)
	{
		if (IsErrandWorldPickup(Item) && IsAPToken(Item))
		{
			RestoreErrandPickup(Item);
			bDid = true;
		}
	}
	foreach DynamicActors(class'APCheckGlow', Glow)
	{
		if (Glow.Target != None && Pickup(Glow.Target) != None
			&& IsErrandWorldPickup(Pickup(Glow.Target)))
			Glow.Destroy();
	}
	if (bDid)
		InvalidateScroungeCache();
	SyncErrandWorldPickups();
	StripStrayErrandPickups();
	EnsureMissingErrandPickup();
}

function SyncErrandWorldPickups()
{
	local Pickup Item;
	local string U;
	local bool bShow;

	foreach AllActors(class'Pickup', Item)
	{
		if (Item == None || Item.bDeleteMe || !IsErrandWorldPickup(Item))
			continue;
		U = ErrandUniqueForWorldPickup(Item);
		if (U == "")
			continue;
		if (U ~= "VisitClinic")
			continue;
		if (IsVanillaFollowupErrand(U))
			bShow = IsErrandActiveByName(U) && !HasRecordedCheck(U);
		else
			bShow = IsUnlocked("ERRAND:"$U) && !HasRecordedCheck(U);
		SetErrandPickupVisible(Item, bShow);
	}
}

function SetErrandPickupVisible(Pickup Item, bool bShow)
{
	if (Item == None)
		return;
	if (bShow)
	{
		if (!Item.bHidden && Item.bCollideActors)
		{
			if (P2PowerupPickup(Item) != None)
				P2PowerupPickup(Item).bOKToGrab = true;
			return;
		}
		Item.SetPhysics(PHYS_None);
		Item.bHidden = false;
		Item.SetCollision(true, false, false);
		if (P2PowerupPickup(Item) != None)
			P2PowerupPickup(Item).bOKToGrab = true;
		RestoreErrandPickup(Item);
	}
	else
	{
		if (Item.bHidden && !Item.bCollideActors)
			return;
		Item.SetPhysics(PHYS_None);
		Item.bHidden = true;
		Item.SetCollision(false, false, false);
		if (P2PowerupPickup(Item) != None)
			P2PowerupPickup(Item).bOKToGrab = false;
	}
}

function vector MilkGaneshLoc()
{
	return vect(-9338,-4445,-3606);
}

function vector MilkAisleLoc()
{
	return vect(-9220,-4546,-3640);
}

function vector MilkShelfSlot(int i)
{
	if (i == 0)
		return vect(-9320.4,-4473.9,-3606);
	if (i == 1)
		return vect(-9350.4,-4472.9,-3606);
	if (i == 2)
		return vect(-9336.2,-4399.7,-3606);
	if (i == 3)
		return vect(-9349.2,-4449.3,-3606);
	return vect(-9337.1,-4428.4,-3606);
}

function bool IsMilkPickup(Pickup Item)
{
	if (Item == None)
		return false;
	return Item.IsA('MilkPickup') || Item.Tag == 'MilkPickup';
}

function P2Pawn FindHabibOwner()
{
	local Pawn P;

	foreach AllActors(class'Pawn', P, 'Habib')
	{
		if (P != None && !P.bDeleteMe)
			return P2Pawn(P);
	}
	foreach AllActors(class'Pawn', P)
	{
		if (P == None || P.bDeleteMe || P.Controller == None)
			continue;
		if (P.Controller.IsA('HabibController'))
			return P2Pawn(P);
	}
	return None;
}

function BindMilkPickup(Pickup Item)
{
	local OwnedPickup Own;
	local P2Pawn Habib;

	Own = OwnedPickup(Item);
	if (Own == None || APWorldPickup(Item) != None || !IsMilkPickup(Item))
		return;
	Habib = FindHabibOwner();
	Own.LegalOwnerTag = 'Habib';
	if (Habib != None)
		Own.LegalOwner = Habib;
	Own.bPaidFor = false;
	if (Own.Price <= 0)
		Own.Price = 5;
	Own.Tag = 'MilkPickup';
}

function BindUnpaidMilkToHabib(P2Pawn Dude)
{
	local Inventory Inv;
	local OwnedInv Own;
	local P2Pawn Habib;
	local Pickup Item;

	Habib = FindHabibOwner();
	if (Dude != None)
	{
		Inv = Dude.Inventory;
		while (Inv != None)
		{
			Own = OwnedInv(Inv);
			if (Own != None && Inv.IsA('MilkInv') && !Own.bPaidFor)
			{
				Own.LegalOwnerTag = 'Habib';
				if (Habib != None)
					Own.LegalOwner = Habib;
				if (Own.Price <= 0)
					Own.Price = 5;
			}
			Inv = Inv.Inventory;
		}
	}
	foreach AllActors(class'Pickup', Item)
	{
		if (Item != None && !Item.bDeleteMe && IsMilkPickup(Item))
			BindMilkPickup(Item);
	}
}

function float MilkXYDist(Pickup Item, vector Loc)
{
	local vector D;

	if (Item == None)
		return 99999;
	D = Item.Location - Loc;
	D.Z = 0;
	return VSize(D);
}

function PinMilkInFridge(Pickup Item, vector Shelf)
{
	if (Item == None)
		return;
	if (IsAPToken(Item))
		RestoreErrandPickup(Item);
	BindMilkPickup(Item);
	Item.SetPhysics(PHYS_None);
	Item.bCollideWhenPlacing = false;
	Item.bCollideWorld = false;
	Item.SetCollision(false, false, false);
	Item.SetLocation(Shelf);
	Item.SetPhysics(PHYS_None);
	Item.bCollideWorld = false;
	Item.SetCollision(true, false, false);
	if (P2PowerupPickup(Item) != None)
	{
		P2PowerupPickup(Item).bUseForErrands = true;
		P2PowerupPickup(Item).bOKToGrab = true;
		P2PowerupPickup(Item).bAllowMovement = false;
	}
	SetErrandPickupVisible(Item, true);
	Item.bCollideWorld = false;
	Item.SetPhysics(PHYS_None);
}

function Pickup SpawnMilkOnShelf(vector Shelf)
{
	local class<Pickup> C;
	local Pickup Item;
	local vector Aisle;

	C = class<Pickup>(DynamicLoadObject("Inventory.MilkPickup", class'class'));
	if (C == None)
		return None;
	Aisle = MilkAisleLoc();
	Item = Spawn(C, None, 'MilkPickup', Aisle);
	if (Item == None)
		Item = Spawn(C, None, 'MilkPickup', Aisle + vect(0,0,40));
	if (Item == None)
		return None;
	if (P2PowerupPickup(Item) != None)
		P2PowerupPickup(Item).PrepForGrabbing();
	PinMilkInFridge(Item, Shelf);
	return Item;
}

function PlaceMilkAtGanesh()
{
	local Pickup Item, Assigned[5], Extra[16];
	local vector SlotLoc, Center;
	local int i, n, Best, ExtraN;
	local float BestD, Dist;

	if (!IsUnlocked("ERRAND:GetMilk") || HasRecordedCheck("GetMilk"))
		return;
	if (!(MapKey() ~= "SUBURBS-1"))
		return;

	Center = MilkGaneshLoc();
	foreach AllActors(class'Pickup', Item)
	{
		if (Item == None || Item.bDeleteMe || !IsMilkPickup(Item))
			continue;
		if (APWorldPickup(Item) != None)
		{
			if (ExtraN < 16)
			{
				Extra[ExtraN] = Item;
				ExtraN++;
			}
			continue;
		}
		Best = -1;
		BestD = 40;
		for (i = 0; i < 5; i++)
		{
			if (Assigned[i] != None)
				continue;
			Dist = VSize(Item.Location - MilkShelfSlot(i));
			if (Dist < BestD)
			{
				BestD = Dist;
				Best = i;
			}
		}
		if (Best == -1 && MilkXYDist(Item, Center) < 250)
		{
			for (i = 0; i < 5; i++)
				if (Assigned[i] == None)
				{
					Best = i;
					break;
				}
		}
		if (Best >= 0)
			Assigned[Best] = Item;
		else if (ExtraN < 16)
		{
			Extra[ExtraN] = Item;
			ExtraN++;
		}
	}
	for (i = 0; i < ExtraN; i++)
	{
		if (Extra[i] == None)
			continue;
		if (APWorldPickup(Extra[i]) != None)
		{
			Extra[i].Destroy();
			continue;
		}
		for (n = 0; n < 5; n++)
		{
			if (Assigned[n] == None)
			{
				Assigned[n] = Extra[i];
				Extra[i] = None;
				break;
			}
		}
		if (Extra[i] != None)
			Extra[i].Destroy();
	}
	n = 0;
	for (i = 0; i < 5; i++)
	{
		SlotLoc = MilkShelfSlot(i);
		if (Assigned[i] == None)
			Assigned[i] = SpawnMilkOnShelf(SlotLoc);
		if (Assigned[i] != None)
		{
			PinMilkInFridge(Assigned[i], SlotLoc);
			n++;
		}
	}
	if (GetPlayer() != None)
		BindUnpaidMilkToHabib(P2Pawn(GetPlayer().Pawn));
}

function MaybePlaceMilk()
{
	if (!(MapKey() ~= "SUBURBS-1"))
		return;
	if (Level.TimeSeconds < NextMilkPlace)
		return;
	NextMilkPlace = Level.TimeSeconds + 3.0;
	if (GetPlayer() != None)
		BindUnpaidMilkToHabib(P2Pawn(GetPlayer().Pawn));
	if (!IsUnlocked("ERRAND:GetMilk") || HasRecordedCheck("GetMilk"))
		return;
	PlaceMilkAtGanesh();
}

function EnsureMissingErrandPickup()
{
	local string K;

	K = MapKey();
	if (K ~= "JUNKYARD")
		EnsurePickupForErrand("GetAlternator", "Inventory.AlternatorPickup", 'AlternatorPickup');
	else if (K ~= "PARCELCENTER")
		EnsurePickupForErrand("PickupPackage", "Inventory.ParcelPickup", 'ParcelPickup');
	else if (K ~= "SLAUGHTERHOUSE")
		EnsurePickupForErrand("GetSteaks", "Inventory.SteakPickup", 'SteakPickup');
	else if (K ~= "WESTMALL")
		EnsurePickupForErrand("GetKrotchy", "Inventory.KrotchyPickup", 'KrotchyPickup');
	else if (K ~= "NAPALM")
		EnsurePickupForErrand("GetNapalm", "Inventory.NapalmPickupErrand", 'NapalmPickupErrand');
	else if (K ~= "RWSBLOCK")
		EnsurePickupForErrand("GetPaycheck", "Inventory.PaycheckPickup", 'PaycheckPickup');
	else if (K ~= "FOREST")
		EnsurePickupForErrand("GetTree", "Inventory.TreePickup", 'TreePickup');
	else if (K ~= "SUBURBS-1")
		PlaceMilkAtGanesh();
	else if (K ~= "GREENBELT1")
		EnsurePickupForErrand("CashPaycheck", "Inventory.MoneyPickup", 'BankDeposit');
	else if (K ~= "INDUSTRY" || K ~= "INDUSTRY2" || K ~= "CLINIC")
		EnsurePickupForErrand("VisitClinic", "Inventory.PillsPickup", 'PillsPickup');
	else if (K ~= "BREWERY")
		StripBreweryRestoreTokens();
}

function StripBreweryRestoreTokens()
{
	local APRestorePickup Item;
	local APRestorePickup KillList[8];
	local int i, N;

	foreach AllActors(class'APRestorePickup', Item)
	{
		if (Item == None || Item.bDeleteMe)
			continue;
		if (N < 8)
		{
			KillList[N] = Item;
			N++;
		}
	}
	for (i = 0; i < N; i++)
		if (KillList[i] != None)
			KillList[i].Destroy();
}

function RestoreAPLoadout(P2Pawn Dude)
{
	if (Dude == None)
		return;
	ReapplyUnlocks(Dude);
	SanitizeDudeInventory(Dude);
	ShowAPMessage("Archipelago loadout restored.");
}

function MarkBreweryExitIfNeeded(string URL, PlayerController PC)
{
	local string Dest, K;
	local P2Pawn Dude;
	local APGameState GS;

	Dest = DestMapFromURL(URL);
	if (Dest == "")
		return;
	K = MapKey();
	GS = APState();
	if (GS != None)
	{
		if ((K ~= "LIBRARY1" || K ~= "LIBRARY2")
			&& !(Dest ~= "LIBRARY1") && !(Dest ~= "LIBRARY2")
			&& (GS.HasVisitedMap("LIBRARY2") || K ~= "LIBRARY2"))
			GS.bWarpLibrary = true;
		if (K ~= "NAPALM" && !(Dest ~= "NAPALM"))
			GS.bWarpNapalm = true;
		if (K ~= "PARCELCENTER" && !(Dest ~= "PARCELCENTER"))
			GS.bWarpParcel = true;
	}
	if (!(K ~= "BREWERY") || Dest ~= "BREWERY")
		return;
	if (GS != None)
	{
		GS.bWarpBrewery = true;
		GS.bNeedBreweryResync = true;
	}
	PutOnKeepGimp();
	if (PC != None)
		Dude = P2Pawn(PC.Pawn);
	if (Dude != None)
	{
		ReapplyUnlocks(Dude);
		EnforceKeepGimp(Dude);
	}
	SendCheck("BreweryRestore");
}

function FinishBreweryEscape(P2Pawn Dude)
{
	local APGameState GS;

	GS = APState();
	if (GS != None)
		GS.bNeedBreweryResync = false;
	PutOnKeepGimp();
	RestoreAPLoadout(Dude);
	EnforceKeepGimp(Dude);
	SendCheck("BreweryRestore");
	LastCatchUpTime = 0;
	RequestCatchUp();
}

function EnsurePickupForErrand(string UniqueName, string ClassName, name TagName, optional vector SpawnAt)
{
	local class<Pickup> C;
	local Pickup Item;

	if (!IsUnlocked("ERRAND:"$UniqueName) || HasRecordedCheck(UniqueName))
		return;
	C = class<Pickup>(DynamicLoadObject(ClassName, class'class'));
	if (C == None)
		return;
	foreach AllActors(class'Pickup', Item)
	{
		if (Item == None || Item.bDeleteMe)
			continue;
		if (Item.Class == C || Item.Tag == TagName)
		{
			if (IsAPToken(Item))
				RestoreErrandPickup(Item);
			return;
		}
	}
	if (SpawnAt == vect(0,0,0))
		return;
	Item = Spawn(C, None, TagName, SpawnAt);
	if (Item == None)
		Item = Spawn(C, None, TagName, SpawnAt + vect(0,0,24));
}

function StripStrayErrandPickups()
{
	local Pickup Item, KillList[16];
	local int i, N;
	local string K;

	K = MapKey();
	foreach AllActors(class'Pickup', Item)
	{
		if (Item == None || Item.bDeleteMe)
			continue;
		if ((Item.IsA('MilkPickup') || Item.Tag == 'MilkPickup') && !(K ~= "SUBURBS-1"))
		{
			if (N < 16)
			{
				KillList[N] = Item;
				N++;
			}
		}
	}
	for (i = 0; i < N; i++)
		if (KillList[i] != None)
			KillList[i].Destroy();
}

function ShowTimeWarpMenu(P2Player Player)
{
	local APTimeWarpScreen S;
	local APTimeWarpInv Inv;
	local string Blocked;

	Blocked = TimeWarpBlockedReason();
	if (Blocked != "")
	{
		ShowAPMessage(Blocked);
		return;
	}
	if (Player == None || Player.Player == None)
		return;
	if (Player.Pawn != None)
	{
		Inv = APTimeWarpInv(Player.Pawn.FindInventoryType(class'APTimeWarpInv'));
		if (Inv != None)
			Inv.ClearArm();
	}
	S = APTimeWarpScreen(Player.Player.InteractionMaster.AddInteraction("Archipelago.APTimeWarpScreen", Player.Player));
	if (S == None)
		return;
	S.Show("");
	Player.CurrentScreen = S;
	Player.SetMyOldState();
	Player.GotoState('WaitScreen');
}

function int WarpPointCount()
{
	return 8;
}

function string WarpPointGrant(int i)
{
	if (i == 0) return "WARP:GREENBELT1";
	if (i == 1) return "WARP:GREENBELT2";
	if (i == 2) return "WARP:SUBURBS-1";
	if (i == 3) return "WARP:HIGHLANDS";
	if (i == 4) return "WARP:RWSBLOCK";
	if (i == 5) return "WARP:SUBURBS-2";
	if (i == 6) return "WARP:SUBURBS-4";
	if (i == 7) return "WARP:TORABORA";
	return "";
}

function string WarpPointLabel(int i)
{
	if (i == 0) return "Greenbelt";
	if (i == 1) return "Napalm Factory Exterior";
	if (i == 2) return "Main Street";
	if (i == 3) return "Trainyard";
	if (i == 4) return "Office Complex";
	if (i == 5) return "Ghetto";
	if (i == 6) return "East Suburbs";
	if (i == 7) return "Tora Bora";
	return "";
}

function string WarpPointURL(int i)
{
	if (i == 0) return "Greenbelt1";
	if (i == 1) return "Greenbelt2";
	if (i == 2) return "suburbs-1";
	if (i == 3) return "Highlands";
	if (i == 4) return "rwsblock";
	if (i == 5) return "suburbs-2";
	if (i == 6) return "suburbs-4";
	if (i == 7) return "ToraBora";
	return "";
}

function int WarpPointMinDay(int i)
{
	if (i == 1) return 3;
	if (i == 3) return 1;
	if (i == 6) return 3;
	return 0;
}

function string WarpPointLabelFromGrant(string Grant)
{
	local int i;

	for (i = 0; i < WarpPointCount(); i++)
		if (WarpPointGrant(i) ~= Grant)
			return WarpPointLabel(i);
	return Mid(Grant, 5);
}

function bool WarpPointOpen(int i, int Day)
{
	if (i < 0 || i >= WarpPointCount())
		return false;
	if (Day < WarpPointMinDay(i))
		return false;
	return IsUnlocked(WarpPointGrant(i));
}

function int TimeWarpDestCount(int Day)
{
	local int i, n;

	n = 1;
	for (i = 0; i < WarpPointCount(); i++)
		if (WarpPointOpen(i, Day))
			n++;
	return n;
}

function int TimeWarpDestWarpIndex(int Day, int Slot)
{
	local int i, n;

	if (Slot <= 1)
		return -1;
	n = 1;
	for (i = 0; i < WarpPointCount(); i++)
	{
		if (!WarpPointOpen(i, Day))
			continue;
		n++;
		if (n == Slot)
			return i;
	}
	return -1;
}

function string TimeWarpDestLine(int Day, int Slot)
{
	local int i;

	if (Slot == 1)
		return "1  Home";
	i = TimeWarpDestWarpIndex(Day, Slot);
	if (i < 0)
		return "";
	return string(Slot)$"  "$WarpPointLabel(i);
}

function bool MapAccessibleOnDay(string K, int Day)
{
	local int MinDay;

	if (K == "" || K ~= "INTRO" || K ~= "HOMEATNIGHT")
		return false;
	if (Day < 0)
		return false;
	MinDay = AreaMinDay(K);
	if (MinDay < 0)
		MinDay = 0;
	return Day >= MinDay;
}

function string CurrentLevelURL()
{
	local string S;
	local int i, Guard;

	S = Level.GetLocalURL();
	i = InStr(S, "?");
	if (i != -1)
		S = Left(S, i);
	i = InStr(S, "#");
	if (i != -1)
		S = Left(S, i);
	Guard = 0;
	i = InStr(S, "/");
	while (i != -1 && Guard < 8)
	{
		S = Mid(S, i + 1);
		i = InStr(S, "/");
		Guard++;
	}
	Guard = 0;
	i = InStr(S, "\\");
	while (i != -1 && Guard < 8)
	{
		S = Mid(S, i + 1);
		i = InStr(S, "\\");
		Guard++;
	}
	if (Right(S, 4) ~= ".fuk")
		S = Left(S, Len(S) - 4);
	if (Left(Caps(S), 4) ~= "NGT-")
		S = Mid(S, 4);
	return S;
}

function bool QueueDayWarp(int Day, int DestSlot)
{
	local string Blocked, URL, Label;
	local int i;

	Blocked = TimeWarpBlockedReason();
	if (Blocked != "")
	{
		ShowAPMessage(Blocked);
		return false;
	}
	if (!IsDayUnlocked(Day))
	{
		ShowAPMessage("You haven't unlocked that day yet.");
		return false;
	}
	if (TheGameState == None)
		return false;
	URL = StartFirstDayURL;
	Label = "Home";
	if (DestSlot > 1)
	{
		i = TimeWarpDestWarpIndex(Day, DestSlot);
		if (i < 0)
		{
			ShowAPMessage("That warp point is not open on this day.");
			return false;
		}
		URL = WarpPointURL(i);
		Label = WarpPointLabel(i);
	}
	if (URL == "" || Caps(URL) ~= "INTRO")
		URL = StartFirstDayURL;
	ArmTimeWarpTravel(Day, URL, Label, true);
	return true;
}

function bool QueueStoryWarp(int Slot)
{
	local string URL, Label, Blocked;
	local int Day;

	Blocked = TimeWarpBlockedReason();
	if (Blocked != "")
	{
		ShowAPMessage(Blocked);
		return false;
	}
	if (!StoryWarpUnlocked(Slot))
	{
		if (Slot == 6 || Slot == 7)
			ShowAPMessage("Exit the burning library once first.");
		else if (Slot == 8)
			ShowAPMessage("Leave the Brewery once first.");
		else if (Slot == 9)
			ShowAPMessage("Leave the Napalm Factory once first.");
		else
			ShowAPMessage("Leave the Parcel Center once first.");
		return false;
	}
	if (TheGameState == None)
		return false;
	if (Slot == 6)
	{
		URL = "library1";
		Day = 1;
		Label = "Library";
	}
	else if (Slot == 7)
	{
		URL = "library2";
		Day = 1;
		Label = "Burning Library";
	}
	else if (Slot == 8)
	{
		URL = "Brewery";
		Day = 2;
		Label = "Brewery";
	}
	else if (Slot == 9)
	{
		URL = "Napalm";
		Day = 3;
		Label = "Napalm Factory";
	}
	else if (Slot == 0)
	{
		URL = "parcelcenter";
		Day = 4;
		Label = "Parcel Center";
	}
	else
		return false;
	ArmTimeWarpTravel(Day, URL, Label, false);
	return true;
}

function ArmTimeWarpTravel(int Day, string URL, string Label, bool bShowMap)
{
	local P2Player P;
	local P2Pawn Dude;
	local APTimeWarpInv Inv;
	local string DayName;

	P = GetPlayer();
	if (P == None || P.Pawn == None)
		return;
	Dude = P2Pawn(P.Pawn);
	if (Dude == None)
		return;
	Inv = APTimeWarpInv(Dude.FindInventoryType(class'APTimeWarpInv'));
	if (Inv == None)
	{
		Dude.CreateInventory("Archipelago.APTimeWarpInv");
		Inv = APTimeWarpInv(Dude.FindInventoryType(class'APTimeWarpInv'));
	}
	if (Inv == None)
		return;
	if (Inv.Amount < 1)
		Inv.Amount = 1;
	Inv.ArmWarp(Day, URL, Label, bShowMap);
	DayName = "";
	if (Days.Length > Day && Days[Day] != None)
		DayName = Days[Day].Description;
	if (Label == "" || Label ~= "Home")
		ShowAPMessage("Throw Time Warp, then pick it up when it lights to warp home ("$DayName$").");
	else
		ShowAPMessage("Throw Time Warp, then pick it up when it lights to warp to "$Label$" ("$DayName$").");
}

function CommitTimeWarp(int Day, string URL, string Label, bool bShowMap)
{
	local P2Player P;
	local APTimeWarpInv Inv;
	local string Blocked, DayName;

	Blocked = TimeWarpBlockedReason();
	if (Blocked != "")
	{
		ShowAPMessage(Blocked);
		return;
	}
	if (TheGameState == None || URL == "")
		return;
	P = GetPlayer();
	if (P == None)
		return;
	if (P.Pawn != None)
	{
		Inv = APTimeWarpInv(P.Pawn.FindInventoryType(class'APTimeWarpInv'));
		if (Inv != None)
			Inv.ClearArm();
	}
	TheGameState.CurrentDay = Day;
	TheGameState.bChangeDayPostTravel = false;
	TheGameState.bFirstLevelOfDay = false;
	NextGlowUpdate = 0;
	if (APState() != None)
		APState().bShowMapAfterWarp = bShowMap;
	DayName = "";
	if (Days.Length > Day && Days[Day] != None)
		DayName = Days[Day].Description;
	if (Label == "" || Label ~= "Home")
		ShowAPMessage("Warping home: "$DayName$".");
	else
		ShowAPMessage("Warping to "$Label$" ("$DayName$").");
	SendPlayerTo(P, URL);
}

function bool BeginTimeWarp(int Day)
{
	return QueueDayWarp(Day, 1);
}

function bool BeginTimeWarpStory(int Slot)
{
	return QueueStoryWarp(Slot);
}

function bool FridayErrandsDone()
{
	return HasRecordedCheck("GetAlternator")
		&& HasRecordedCheck("PickupPackage")
		&& HasRecordedCheck("GivePresent")
		&& HasRecordedCheck("VisitClinic");
}

function SanitizeDudeInventory(P2Pawn Dude)
{
	local Inventory Inv, Next, Prev;
	local int Hits;

	if (Dude == None)
		return;
	Inv = Dude.Inventory;
	Prev = None;
	Hits = 0;
	while (Inv != None)
	{
		Hits++;
		if (Hits > 256)
			return;
		Next = Inv.Inventory;
		if (Next == Inv || Next == Dude.Inventory)
		{
			Inv.Inventory = None;
			return;
		}
		Prev = Inv;
		Inv = Next;
	}
}

function StripDuplicateWeapons(P2Pawn Dude)
{
	local Inventory Inv, Next;
	local class<Weapon> Seen[48];
	local int Hits, n, i;
	local bool bDup;
	local Weapon W;

	if (Dude == None)
		return;
	Inv = Dude.Inventory;
	Hits = 0;
	n = 0;
	while (Inv != None && Hits < 128)
	{
		Hits++;
		Next = Inv.Inventory;
		W = Weapon(Inv);
		if (W != None && UrethraWeapon(W) == None && HandsWeapon(W) == None
			&& FootWeapon(W) == None && CellPhoneWeapon(W) == None)
		{
			bDup = false;
			i = 0;
			while (i < n)
			{
				if (Seen[i] == W.Class)
				{
					bDup = true;
					break;
				}
				i++;
			}
			if (bDup)
			{
				if (Inv.Instigator != None)
					Inv.DetachFromPawn(Inv.Instigator);
				Dude.DeleteInventory(Inv);
				Inv.Destroy();
			}
			else if (n < 48)
			{
				Seen[n] = W.Class;
				n++;
			}
		}
		Inv = Next;
	}
}

function SwapStatsClipboard(P2Pawn Dude)
{
	local StatInv Old;

	if (Dude == None)
		return;
	Old = StatInv(Dude.FindInventoryType(class'StatInv'));
	if (Old == None || APStatInv(Old) != None)
		return;
	if (Old.Instigator != None)
		Old.DetachFromPawn(Old.Instigator);
	Dude.DeleteInventory(Old);
	Old.Destroy();
	Dude.CreateInventoryByClass(class'APStatInv');
}

function string ClipboardTitle()
{
	if (APSlot != "")
		return APSlot;
	return "Dude";
}

function string ClipboardConnection()
{
	if (Bridge != None && Bridge.IsConnected())
		return "online";
	return "offline";
}

function string ClipboardDay()
{
	if (TheGameState == None || Days.Length == 0)
		return "?";
	return Days[TheGameState.CurrentDay].Description;
}

function string ClipboardErrandsLeft()
{
	local int i, Left, Active;
	local DayBase Day;

	if (TheGameState == None)
		return "?";
	Day = Days[TheGameState.CurrentDay];
	if (Day == None)
		return "?";
	for (i = 0; i < Day.NumErrands(); i++)
	{
		if (Day.Errands[i] != None && IsAnyDayErrand(Day.Errands[i].UniqueName))
			continue;
		if (Day.IsErrandActive(i))
		{
			Active++;
			if (!Day.IsErrandComplete(i))
				Left++;
		}
	}
	if (Active == 0)
		return "nothing listed yet";
	if (Left == 0)
		return "done for today";
	return Left$" still open";
}

function string ClipboardPetition()
{
	if (HasRecordedCheck("GetSignatures"))
		return "done";
	if (IsUnlocked("ERRAND:GetSignatures"))
		return "open any day";
	return "";
}

function string ClipboardWeek()
{
	return CountCampaignErrandsDone()$" / "$CountCampaignErrandsTotal()$" errands";
}

function SetTrackerCounts(int InLogic, int Left)
{
	APTrackerInLogic = InLogic;
	APTrackerLeft = Left;
}

function string ClipboardTracker()
{
	if (APTrackerLeft <= 0 && APTrackerInLogic <= 0)
		return "";
	return string(APTrackerInLogic)$" / "$string(APTrackerLeft)$" left";
}

function int CountCampaignErrandsDone()
{
	local int d, e, N;
	local string U, Seen;

	for (d = 0; d < Days.Length; d++)
	{
		if (Days[d] == None)
			continue;
		for (e = 0; e < Days[d].Errands.Length; e++)
		{
			if (Days[d].Errands[e] == None)
				continue;
			U = Days[d].Errands[e].UniqueName;
			if (U == "" || InStr(Seen, ";"$U$";") != -1)
				continue;
			Seen = Seen$";"$U$";";
			if (HasRecordedCheck(U))
				N++;
		}
	}
	return N;
}

function int CountCampaignErrandsTotal()
{
	local int d, e, N;
	local string U, Seen;

	for (d = 0; d < Days.Length; d++)
	{
		if (Days[d] == None)
			continue;
		for (e = 0; e < Days[d].Errands.Length; e++)
		{
			if (Days[d].Errands[e] == None)
				continue;
			U = Days[d].Errands[e].UniqueName;
			if (U == "" || InStr(Seen, ";"$U$";") != -1)
				continue;
			Seen = Seen$";"$U$";";
			N++;
		}
	}
	return N;
}

function string ClipboardDaysOpen()
{
	local string S;

	if (IsDayUnlocked(0))
		S = "Mon";
	if (IsDayUnlocked(1))
		S = AppendWait(S, "Tue");
	if (IsDayUnlocked(2))
		S = AppendWait(S, "Wed");
	if (IsDayUnlocked(3))
		S = AppendWait(S, "Thu");
	if (IsDayUnlocked(4))
		S = AppendWait(S, "Fri");
	if (S == "")
		S = "none";
	return S;
}

function string AppendWait(string S, string Piece)
{
	if (S == "")
		return Piece;
	return S$", "$Piece;
}

function string ClipboardMapPickupsLeft()
{
	local int N;

	N = CountGlowingPickups();
	if (!IsMapTokenOpen())
		return "closed today";
	if (N == 0)
		return "none today";
	return string(N)$" today";
}

function string ClipboardHuntMaps()
{
	local string Keys[26];
	local string S, K;
	local int a, Today, D;

	if (TheGameState != None)
		Today = TheGameState.CurrentDay;
	Keys[0] = "SUBURBS-3";
	Keys[1] = "SUBURBS-1";
	Keys[2] = "GREENBELT1";
	Keys[3] = "GREENBELT2";
	Keys[4] = "ESTATES";
	Keys[5] = "RWSBLOCK";
	Keys[6] = "HIGHLANDS";
	Keys[7] = "POLICE";
	Keys[8] = "INDUSTRY";
	Keys[9] = "INDUSTRY2";
	Keys[10] = "UNDERHUB";
	Keys[11] = "TORABORA";
	Keys[12] = "SUBURBS-2";
	Keys[13] = "SUBURBS-4";
	Keys[14] = "LIBRARY1";
	Keys[15] = "LIBRARY2";
	Keys[16] = "EASTMALL";
	Keys[17] = "WESTMALL";
	Keys[18] = "CHURCH";
	Keys[19] = "FOREST";
	Keys[20] = "BREWERY";
	Keys[21] = "NAPALM";
	Keys[22] = "SLAUGHTERHOUSE";
	Keys[23] = "COMPOUND";
	Keys[24] = "PARCELCENTER";
	Keys[25] = "JUNKYARD";
	S = "";
	for (a = 0; a < 26; a++)
	{
		K = Keys[a];
		D = MapTokenDayForKey(K);
		if (D != Today)
			continue;
		if (S == "")
			S = AreaAbbrev(K);
		else
			S = S$", "$AreaAbbrev(K);
	}
	if (S == "")
		return "(none)";
	return S;
}

function string ClipboardMapMachines()
{
	local string S, K, U;
	local int Cap, i, j, Slot, Left, Total;

	K = MapKey();
	Cap = VendorCap(K);
	if (Cap > 0)
	{
		Left = 0;
		Total = Cap + Cap * VendorBuySlotsFor(K);
		for (i = 1; i <= Cap; i++)
		{
			if (!HasRecordedCheck("VUSE_"$K$"_"$TwoDigit(i)))
				Left++;
			for (j = 1; j <= VendorBuySlotsFor(K); j++)
			{
				Slot = (i - 1) * VendorBuyStride() + j;
				if (!HasRecordedCheck("VBUY_"$K$"_"$TwoDigit(Slot)))
					Left++;
			}
		}
		S = AppendWait(S, "vend "$Left$"/"$Total);
	}
	Cap = ColaCap(K);
	if (Cap > 0)
	{
		Left = 0;
		for (i = 1; i <= Cap; i++)
		{
			U = "COLA_"$K$"_"$TwoDigit(i);
			if (!HasRecordedCheck(U))
				Left++;
		}
		S = AppendWait(S, "cola "$Left$"/"$Cap);
	}
	Cap = ATMCap(K);
	if (Cap > 0)
	{
		Left = 0;
		for (i = 1; i <= Cap; i++)
		{
			U = "ATM_"$K$"_"$string(i);
			if (!HasRecordedCheck(U))
				Left++;
		}
		S = AppendWait(S, "ATM "$Left$"/"$Cap);
	}
	if (S == "")
		return "";
	return S;
}

function string ClipboardWeapons()
{
	local APGameState GS;
	local int i, n;
	local string Full, Nice;

	if (!ShuffleWeaponsOn())
		return "world loot";
	GS = APState();
	if (GS == None)
		return "none yet";
	n = GS.Unlocks.Length;
	if (n > 128)
		n = 128;
	for (i = 0; i < n; i++)
	{
		Nice = WeaponNiceName(GS.Unlocks[i]);
		if (Nice == "")
			continue;
		if (Full == "")
			Full = Nice;
		else
			Full = Full$", "$Nice;
	}
	if (Full == "")
		return "none yet";
	return Full;
}

function string WeaponNiceName(string ClassName)
{
	local string C;

	C = Caps(ClassName);
	if (Left(C, 4) == "DAY:")
		return "";
	if (InStr(C, "SHOVELWEAPON") != -1)
		return "Shovel";
	if (InStr(C, "CLIPBOARDWEAPON") != -1)
		return "";
	if (InStr(C, "HANDSWEAPON") != -1)
		return "";
	if (InStr(C, "FOOTWEAPON") != -1)
		return "";
	if (InStr(C, "URETHRAWEAPON") != -1)
		return "";
	if (InStr(C, "CELLPHONEWEAPON") != -1)
		return "";
	if (InStr(C, "MATCHESWEAPON") != -1)
		return "";
	if (InStr(C, "BETASHOTGUN") != -1)
		return "Beta Shotgun";
	if (InStr(C, "SAWNOFF") != -1)
		return "Sawed-Off";
	if (InStr(C, "SHOTGUNWEAPON") != -1)
		return "Shotgun";
	if (InStr(C, "MACHINEGUNWEAPON") != -1)
		return "Machine Gun";
	if (InStr(C, "PISTOLWEAPON") != -1)
		return "Pistol";
	if (InStr(C, "RIFLEWEAPON") != -1)
		return "Rifle";
	if (InStr(C, "CATLAUNCHER") != -1)
		return "Cat Launcher";
	if (InStr(C, "BOXLAUNCHER") != -1)
		return "Box Launcher";
	if (InStr(C, "MRDKNADE") != -1)
		return "Krotchy Grenade";
	if (InStr(C, "LAUNCHERWEAPON") != -1)
		return "Rocket";
	if (InStr(C, "NAPALMWEAPON") != -1)
		return "Napalm";
	if (InStr(C, "GRENADELAUNCHER") != -1)
		return "Grenade Launcher";
	if (InStr(C, "GRENADEWEAPON") != -1)
		return "Grenades";
	if (InStr(C, "FLAMEWEAPON") != -1)
		return "Flamethrower";
	if (InStr(C, "PLAGUEWEAPON") != -1)
		return "WMD";
	if (InStr(C, "NUKEWEAPON") != -1)
		return "Mini-Nuke";
	if (InStr(C, "MACHETEWEAPON") != -1)
		return "Machete";
	if (InStr(C, "SCYTHEWEAPON") != -1)
		return "Scythe";
	if (InStr(C, "CHAINSAWWEAPON") != -1)
		return "Chainsaw";
	if (InStr(C, "COWHEADWEAPON") != -1)
		return "Cow Head";
	if (InStr(C, "DYNAMITEWEAPON") != -1)
		return "Dynamite";
	if (InStr(C, "MOLOTOVWEAPON") != -1)
		return "Molotovs";
	if (InStr(C, "SCISSORSWEAPON") != -1)
		return "Scissors";
	if (InStr(C, "GASCANWEAPON") != -1)
		return "Gas Can";
	if (InStr(C, "SLEDGEWEAPON") != -1)
		return "Sledgehammer";
	if (InStr(C, "GSELECTWEAPON") != -1)
		return "Machine Pistol";
	if (InStr(C, "MP5WEAPON") != -1)
		return "Submachine Gun";
	if (InStr(C, "SHOCKERWEAPON") != -1)
		return "Taser";
	if (InStr(C, "BATONWEAPON") != -1)
		return "Baton";
	if (InStr(C, "BASEBALLBAT") != -1)
		return "Baseball Bat";
	if (InStr(C, "SHEARSWEAPON") != -1)
		return "Hedge Clippers";
	if (InStr(C, "DUSTERSWEAPON") != -1)
		return "Dusters";
	if (InStr(C, "BALIWEAPON") != -1)
		return "Bali";
	return "";
}

function string InventoryNiceName(string ClassName)
{
	local string C;

	C = Caps(ClassName);
	if (InStr(C, "PAYCHECK") != -1)
		return "Paycheck";
	if (InStr(C, "LIBRARYBOOK") != -1 || InStr(C, "BOOKINV") != -1)
		return "Library Book";
	if (InStr(C, "CITATION") != -1)
		return "Traffic Ticket";
	if (InStr(C, "GIFTINV") != -1)
		return "Gift";
	if (InStr(C, "COPCLOTHES") != -1)
		return "Police Uniform";
	if (InStr(C, "GIMPCLOTHES") != -1)
		return "Gimp Suit";
	if (InStr(C, "DUDECLOTHES") != -1)
		return "Postal Uniform";
	if (InStr(C, "GUNRADAR") != -1)
		return "Piranha Plug-in";
	if (InStr(C, "COPRADAR") != -1)
		return "Largemouth Plug-in";
	if (InStr(C, "RADARTARGET") != -1)
		return "Chompy Cartridge";
	if (InStr(C, "RADARINV") != -1)
		return "Bass Sniffer";
	if (InStr(C, "BODYARMOR") != -1)
		return "Body Armor";
	if (InStr(C, "CRACKINV") != -1)
		return "Health Pipe";
	if (InStr(C, "CRACKCOLA") != -1)
		return "Crackola";
	if (InStr(C, "DONUT") != -1)
		return "Donut";
	if (InStr(C, "PIZZA") != -1)
		return "Pizza";
	if (InStr(C, "FASTFOOD") != -1)
		return "Fast Food";
	if (InStr(C, "CATNIP") != -1)
		return "Catnip";
	if (InStr(C, "MEDKIT") != -1)
		return "Medkit";
	if (InStr(C, "APREPAIR") != -1)
		return "Weapon Repair Kit";
	if (InStr(C, "MONEYINV") != -1)
		return "Money";
	if (InStr(C, "MILKINV") != -1)
		return "Milk";
	if (InStr(C, "PARCELINV") != -1)
		return "Parcel";
	if (InStr(C, "ALTERNATOR") != -1)
		return "Alternator";
	if (InStr(C, "KROTCHY") != -1)
		return "Krotchy";
	if (InStr(C, "STEAK") != -1)
		return "Steak";
	if (InStr(C, "PILLS") != -1)
		return "Pills";
	if (InStr(C, "NAPALM") != -1)
		return "Napalm";
	if (InStr(C, "MAPINV") != -1)
		return "Map";
	if (InStr(C, "CATINV") != -1)
		return "Cat";
	return "";
}

function string NextDayGateName()
{
	if (TheGameState == None)
		return "";
	if (TheGameState.CurrentDay == 0)
		return "Tuesday";
	if (TheGameState.CurrentDay == 1)
		return "Wednesday";
	if (TheGameState.CurrentDay == 2)
		return "Thursday";
	if (TheGameState.CurrentDay == 3)
		return "Friday";
	return "";
}

function string NextDayGateKey()
{
	local string N;
	N = NextDayGateName();
	if (N == "")
		return "";
	return "DAY:"$N;
}

function bool HasNextDayGate()
{
	local string Key;
	Key = NextDayGateKey();
	if (Key == "")
		return true;
	return IsUnlocked(Key);
}

function bool AfterFinalErrand()
{
	return AllErrandsRecorded();
}

function StartApocalypse()
{
	if (!AllErrandsRecorded())
		return;
	Super.StartApocalypse();
}

function bool IsPlayerReadyForHome()
{
	// Time Warp replaced clocking out. The trailer is only the
	// end of the week, and only after every errand is done.
	return false;
}

function AtPlayerHouse(P2Player p2p, optional bool bForce)
{
	local string Reminder;
	local int Friday;

	if (AllErrandsRecorded())
	{
		SendCheck("FridayHome");
		SendGoal();
		if (TheGameState != None)
		{
			Friday = 4;
			if (Days.Length > 0 && Days.Length - 1 < Friday)
				Friday = Days.Length - 1;
			TheGameState.CurrentDay = Friday;
		}
		Super.AtPlayerHouse(p2p, true);
		return;
	}
	if (TheGameState != None && TheGameState.CurrentDay == 4)
	{
		Reminder = OpenErrandsReminder();
		if (Reminder != "")
			ShowAPMessage(Reminder);
		else
			ShowAPMessage("The week's not done. Time Warp to other days.");
		return;
	}
	Super.AtPlayerHouse(p2p, bForce);
}

function MaybeNudgeDayGate()
{
	local string Msg;

	if (TheGameState == None)
		return;
	if (!Super.IsPlayerReadyForHome())
		return;
	if (AllErrandsRecorded())
		return;
	if (Level.TimeSeconds < LastGateNudgeTime + 45)
		return;
	Msg = OpenErrandsReminder();
	if (Msg == "")
		return;
	LastGateNudgeTime = Level.TimeSeconds;
	ShowAPMessage(Msg);
}

function string OpenErrandsReminder()
{
	local int d, i;
	local string S, U;
	local ErrandBase E;

	for (d = 0; d < Days.Length; d++)
	{
		if (Days[d] == None || !IsDayUnlocked(d))
			continue;
		for (i = 0; i < Days[d].Errands.Length; i++)
		{
			E = Days[d].Errands[i];
			if (E == None)
				continue;
			U = E.UniqueName;
			if (IsAnyDayErrand(U))
				continue;
			if (!Days[d].IsErrandActive(i) && !IsUnlocked("ERRAND:"$U))
				continue;
			if (E.bCompleted || HasRecordedCheck(U))
				continue;
			if (S == "")
				S = Days[d].Description;
			else
				S = S$", "$Days[d].Description;
			break;
		}
	}
	if (S == "")
		return "No open errands on unlocked days. Time Warp home when you find more.";
	return "Open errands: "$S$". Time Warp to switch days.";
}

function GetLoadOut(optional int myday)
{
	// xPatch day-select dumps shovel/pistol/MG/etc. The randomizer
	// starts you with vanilla Monday pockets; guns come from AP.
}

function StripLockedStartingItems(P2Pawn Dude)
{
	if (Dude == None)
		return;
	StripIfLocked(Dude, "Inventory.LibraryBookInv");
	StripIfLocked(Dude, "Inventory.ClipboardWeapon");
	StripIfLocked(Dude, "Inventory.CitationInv");
	StripIfLocked(Dude, "Inventory.GiftInv");
	StripIfLocked(Dude, "Inventory.CopClothesInv");
	StripIfLocked(Dude, "Inventory.RadarInv");
	StripIfLocked(Dude, "Inventory.PaycheckInv");
	if (ShuffleWeaponsOn())
		StripUnreceivedWeapons(Dude);
}

function StripUnreceivedWeapons(P2Pawn Dude)
{
	local Inventory Inv, Next;
	local int n;

	if (Dude == None)
		return;
	Inv = Dude.Inventory;
	n = 0;
	while (Inv != None && n < 96)
	{
		n++;
		Next = Inv.Inventory;
		if (P2Weapon(Inv) != None
			&& UrethraWeapon(Inv) == None
			&& HandsWeapon(Inv) == None
			&& FootWeapon(Inv) == None
			&& MatchesWeapon(Inv) == None
			&& CellPhoneWeapon(Inv) == None
			&& !IsWeaponAllowed(Inv.Class))
		{
			if (Inv.Instigator != None)
				Inv.DetachFromPawn(Inv.Instigator);
			Dude.DeleteInventory(Inv);
			Inv.Destroy();
		}
		Inv = Next;
	}
}

function StripIfLocked(P2Pawn Dude, string ClassName)
{
	local class<Inventory> IC;
	local Inventory Inv;

	if (IsUnlocked(ClassName))
		return;
	IC = class<Inventory>(DynamicLoadObject(ClassName, class'class'));
	if (IC == None)
		return;
	Inv = Dude.FindInventoryType(IC);
	if (Inv != None)
	{
		if (Inv.Instigator != None)
			Inv.DetachFromPawn(Inv.Instigator);
		Dude.DeleteInventory(Inv);
		Inv.Destroy();
	}
}

function ReapplyUnlocks(P2Pawn Dude)
{
	local int i, n, given;
	local APGameState GS;

	GS = APState();
	if (GS == None || Dude == None)
		return;
	n = GS.Unlocks.Length;
	if (n > 200)
		n = 200;
	for (i = 0; i < n; i++)
	{
		if (Left(GS.Unlocks[i], 4) ~= "DAY:" || Left(GS.Unlocks[i], 5) ~= "AREA:"
			|| Left(GS.Unlocks[i], 7) ~= "ERRAND:" || Left(GS.Unlocks[i], 5) ~= "WARP:")
			continue;
		TryGiveAPItem(GS.Unlocks[i], 0, true);
		given++;
		if (given >= 80)
			break;
	}
}

function bool ShuffleWeaponsOn()
{
	local APGameState GS;
	GS = APState();
	if (GS == None)
		return true;
	return GS.bShuffleWeapons;
}

function ForceErrandByName(string UniqueName)
{
	local int d, e;
	local P2Player P;

	P = GetPlayer();
	for (d = 0; d < Days.Length; d++)
	{
		if (Days[d] == None)
			continue;
		for (e = 0; e < Days[d].Errands.Length; e++)
		{
			if (Days[d].Errands[e] != None
				&& Days[d].Errands[e].UniqueName ~= UniqueName)
			{
				if (TheGameState != None && !GameStateHasErrand(d, e))
				{
					Days[d].Errands[e].bCompleted = false;
					Days[d].Errands[e].ForceCompletion(TheGameState, P);
					SaveCompletedErrand(d, e);
					TheGameState.ErrandsCompletedToday++;
				}
				SendCheck(UniqueName);
				return;
			}
		}
	}
}


function SetOption(string Key, int Value)
{
	local APGameState GS;
	local bool On;

	GS = APState();
	if (GS == None)
		return;
	On = (Value != 0);
	GS.bGotOptions = true;
	if (Key ~= "CLINIC")
		GS.bClinicAlways = true;
	else if (Key ~= "WEAPONS")
		GS.bShuffleWeapons = On;
	else if (Key ~= "VENDING")
		GS.bVendingSanity = On;
	else if (Key ~= "VBUY_GREENBELT1")
		GS.VBuyGB = Clamp(Value, 0, 5);
	else if (Key ~= "VBUY_RWSBLOCK")
		GS.VBuyRWS = Clamp(Value, 0, 5);
	else if (Key ~= "VBUY_EASTMALL")
		GS.VBuyEM = Clamp(Value, 0, 5);
	else if (Key ~= "VBUY_SUBURBS-4")
		GS.VBuySE = Clamp(Value, 0, 5);
	else if (Key ~= "CRACKOLA")
		GS.bCrackolaSanity = On;
	else if (Key ~= "ATM")
		GS.bATMSanity = On;
	else if (Key ~= "GLOW")
	{
		GS.bTokenGlow = On;
		if (!On)
			StripTokenGlows();
		NextGlowUpdate = 0;
		NextMachineGlowUpdate = 0;
	}
	else if (Key ~= "BEEP")
	{
		GS.bTokenBeep = On;
		NextMachineGlowUpdate = 0;
	}
	else if (Key ~= "DURABILITY")
		GS.bMeleeDurability = On;
	else if (Key ~= "PISSREALISM")
	{
		GS.bPissRealism = On;
		if (GetPlayer() != None)
			ApplyPissRealismToDude(P2Pawn(GetPlayer().Pawn));
	}
	else if (Key ~= "PISSREGEN")
	{
		if (Value < 30)
			Value = 30;
		if (Value > 180)
			Value = 180;
		GS.PissRegen = Value;
		if (GetPlayer() != None)
			ApplyPissRealismToDude(P2Pawn(GetPlayer().Pawn));
	}
	else if (Key ~= "LOOTSANITY")
		GS.bLootSanity = On;
	else if (Key ~= "STARTDAY")
	{
		if (Value < 0)
			Value = 0;
		if (Value > 4)
			Value = 4;
		GS.APStartDay = Value;
		GS.bGotStartDay = true;
		ApplyStartDay();
	}
	ApplyGatedErrands(true);
	bVendorDirty = true;
}

function bool TokenGlowEnabled()
{
	local APGameState GS;
	GS = APState();
	if (GS != None && GS.bGotOptions)
		return GS.bTokenGlow;
	return true;
}

function bool TokenBeepEnabled()
{
	local APGameState GS;
	GS = APState();
	if (GS != None && GS.bGotOptions)
		return GS.bTokenBeep;
	return true;
}

function float NearestTokenBeepDist(Pawn Dude)
{
	local APTokenSprite S;
	local float D, Best;

	if (Dude == None)
		return 999999;
	if (TokenBeepScanTime == Level.TimeSeconds)
		return TokenBeepBestDist;
	TokenBeepScanTime = Level.TimeSeconds;
	Best = 999999;
	foreach DynamicActors(class'APTokenSprite', S)
	{
		if (S == None || S.bDeleteMe)
			continue;
		D = VSize(S.Location - Dude.Location);
		if (D < Best)
			Best = D;
	}
	TokenBeepBestDist = Best;
	return Best;
}

function bool LootSanityEnabled()
{
	local APGameState GS;
	GS = APState();
	return (GS != None && GS.bLootSanity);
}

function float CatalogMatchRadius()
{
	if (LootSanityEnabled())
		return 40;
	return 280;
}

function StripTokenGlows()
{
	local APCheckGlow Glow;
	foreach DynamicActors(class'APCheckGlow', Glow)
		if (Glow != None)
			Glow.Destroy();
}

function StripPickupGlows()
{
	local APCheckGlow Glow;
	foreach DynamicActors(class'APCheckGlow', Glow)
		if (Glow != None && Pickup(Glow.Target) != None)
			Glow.Destroy();
}

function SetStarterErrand(string UniqueName)
{
	local APGameState GS;
	local P2Player P;
	local bool bNeedMap;
	local int D;

	if (!IsCampaignStarterUnique(UniqueName))
		return;
	GS = APState();
	if (GS == None)
		return;
	if (GS.FeaturedErrand[0] == "")
		GS.FeaturedErrand[0] = UniqueName;
	D = StartDayIndex();
	if (D >= 0 && D <= 4 && GS.FeaturedErrand[D] == "")
		GS.FeaturedErrand[D] = UniqueName;
	if (IsUnlocked("ERRAND:"$UniqueName))
	{
		bNeedMap = !IsErrandActiveByName(UniqueName);
		ApplyGatedErrands(true);
		if (bNeedMap)
		{
			P = GetPlayer();
			if (P != None && CanPopupErrandMap())
				P.DisplayMapErrands();
		}
		return;
	}
	GS.AddUnlock("ERRAND:"$UniqueName);
	UnlockCampaignErrand(UniqueName);
	ApplyGatedErrands(true);
}

function bool IsCampaignStarterUnique(string UniqueName)
{
	if (UniqueName ~= "GetPaycheck" || UniqueName ~= "CashPaycheck" || UniqueName ~= "GetMilk")
		return true;
	if (UniqueName ~= "VisitPriest" || UniqueName ~= "ReturnBook" || UniqueName ~= "GetGary")
		return true;
	if (UniqueName ~= "VisitDad" || UniqueName ~= "Vote" || UniqueName ~= "GetTree")
		return true;
	if (UniqueName ~= "GetNapalm" || UniqueName ~= "GetKrotchy"
		|| UniqueName ~= "GetSteaks" || UniqueName ~= "PayTicket")
		return true;
	if (UniqueName ~= "GetAlternator" || UniqueName ~= "PickupPackage"
		|| UniqueName ~= "GivePresent" || UniqueName ~= "VisitClinic")
		return true;
	return false;
}

function bool HasMondayStarter()
{
	return HasStarterErrand();
}

function bool HasStarterErrand()
{
	local APGameState GS;
	local int D;

	GS = APState();
	if (GS == None)
		return false;
	if (GS.FeaturedErrand[0] != "")
		return true;
	D = StartDayIndex();
	if (D >= 0 && D <= 4 && GS.FeaturedErrand[D] != "")
		return true;
	return false;
}

function MarkClientGateDone()
{
	local APGameState GS;

	GS = APState();
	if (GS != None)
		GS.bClientGateDone = true;
}

function bool IsWaitingForAPClient()
{
	local string K;
	local APGameState GS;

	GS = APState();
	if (GS != None && GS.bClientGateDone)
		return false;
	if (GS == None)
		return false;
	if (IsIntroMap() || IsCinematic() || IsMainMenuMap() || IsFinishedDayMap())
		return false;
	K = MapKey();
	if (K ~= "HOMEATNIGHT" || K ~= "INTRO")
		return false;
	if (!(K ~= "SUBURBS-3"))
	{
		MarkClientGateDone();
		return false;
	}
	if (HasStarterErrand())
	{
		MarkClientGateDone();
		return false;
	}
	return true;
}

function TickClientGate()
{
	local P2Player P;
	local P2Pawn Dude;

	if (!IsWaitingForAPClient())
	{
		if (bPendingPissTrap)
		{
			bPendingPissTrap = false;
			StartPissTrap();
		}
		return;
	}
	EnsureBridge();
	if (Bridge != None && Bridge.IsConnected())
		RequestCatchUp(2.0);
	P = GetPlayer();
	if (P == None || P.Pawn == None)
		return;
	Dude = P2Pawn(P.Pawn);
	if (Dude == None)
		return;
	Dude.Acceleration = vect(0,0,0);
	Dude.Velocity.X = 0;
	Dude.Velocity.Y = 0;
	Dude.StopAcc();
}

function KickBridge()
{
	EnsureBridge();
	if (Bridge != None && Bridge.bNeedReplace)
		ReplaceBridge();
	if (Bridge != None)
		Bridge.KickConnect();
}

function ReplaceBridge()
{
	local APLink Old;

	Old = Bridge;
	Bridge = None;
	if (Old != None && !Old.bDeleteMe)
	{
		Old.APGame = None;
		Old.bNeedReplace = false;
		Old.Destroy();
	}
	EnsureBridge();
}

function bool AllErrandsRecorded()
{
	return HasRecordedCheck("GetPaycheck")
		&& HasRecordedCheck("CashPaycheck")
		&& HasRecordedCheck("GetMilk")
		&& HasRecordedCheck("VisitPriest")
		&& HasRecordedCheck("GetSignatures")
		&& HasRecordedCheck("ReturnBook")
		&& HasRecordedCheck("GetGary")
		&& HasRecordedCheck("VisitDad")
		&& HasRecordedCheck("Vote")
		&& HasRecordedCheck("GetTree")
		&& HasRecordedCheck("PickupLaundry")
		&& HasRecordedCheck("GetNapalm")
		&& HasRecordedCheck("GetKrotchy")
		&& HasRecordedCheck("GetSteaks")
		&& HasRecordedCheck("PayTicket")
		&& HasRecordedCheck("GetAlternator")
		&& HasRecordedCheck("PickupPackage")
		&& HasRecordedCheck("GivePresent")
		&& HasRecordedCheck("VisitClinic");
}

function RefreshMapErrands()
{
	ApplyGatedErrands(true);
	PruneInactiveRevealedErrands();
}

function ApplyGatedErrands(optional bool bSilent)
{
	local int d, e;
	local string U;
	local bool bOn;

	if (TheGameState == None)
		return;
	EnsureAnyDayPetition();
	SyncVoteBooth();
	SyncErrandCompletion();
	for (d = 0; d < Days.Length; d++)
	{
		if (Days[d] == None)
			continue;
		for (e = 0; e < Days[d].Errands.Length; e++)
		{
			if (Days[d].Errands[e] == None)
				continue;
			U = Days[d].Errands[e].UniqueName;
			if (Days[d].Errands[e].bCompleted || HasRecordedCheck(U))
				continue;
			if (IsVanillaFollowupErrand(U))
				continue;
			bOn = IsUnlocked("ERRAND:"$U);
			SetErrandAvailable(U, bOn, true);
		}
	}
}

function SyncErrandCompletion()
{
	local int d, e;
	local string U;
	local ErrandBase EB;
	local bool bDone;

	if (TheGameState == None)
		return;
	for (d = 0; d < Days.Length; d++)
	{
		if (Days[d] == None)
			continue;
		for (e = 0; e < Days[d].Errands.Length; e++)
		{
			EB = Days[d].Errands[e];
			if (EB == None)
				continue;
			U = EB.UniqueName;
			bDone = EB.bCompleted || HasRecordedCheck(U) || GameStateHasErrand(d, e);
			if (bDone)
			{
				EB.bCompleted = true;
				if (!Days[d].IsErrandActive(e))
					Days[d].ActivateErrand(e);
			}
		}
	}
}

function SetErrandAvailable(string UniqueName, bool bAvail, bool bSilent)
{
	local int Day, Errand;

	if (UniqueName == "" || !FindErrand(UniqueName, Day, Errand))
		return;
	if (Days[Day] == None || Days[Day].Errands[Errand] == None)
		return;

	if (bAvail)
	{
		if (!Days[Day].IsErrandActive(Errand))
			ActivateGated(UniqueName, bSilent);
	}
	else if (Days[Day].IsErrandActive(Errand) && !Days[Day].IsErrandComplete(Errand))
		DeActivateErrand(UniqueName);
}

function PruneInactiveRevealedErrands()
{
	local int i, Day, Errand;

	if (TheGameState == None)
		return;

	i = 0;
	while (i < TheGameState.RevealedErrands.Length)
	{
		Day = TheGameState.RevealedErrands[i].Day;
		Errand = TheGameState.RevealedErrands[i].Errand;
		if (Day >= 0 && Day < Days.Length && Days[Day] != None
			&& Errand >= 0 && Errand < Days[Day].Errands.Length
			&& !Days[Day].IsErrandActive(Errand)
			&& !Days[Day].IsErrandComplete(Errand))
			TheGameState.RevealedErrands.Remove(i, 1);
		else
			i++;
	}

	i = 0;
	while (i < TheGameState.RevealedLocationTex.Length)
	{
		Day = TheGameState.RevealedLocationTex[i].Day;
		Errand = TheGameState.RevealedLocationTex[i].Errand;
		if (Day >= 0 && Day < Days.Length && Days[Day] != None
			&& Errand >= 0 && Errand < Days[Day].Errands.Length
			&& !Days[Day].IsErrandActive(Errand)
			&& !Days[Day].IsErrandComplete(Errand))
			TheGameState.RevealedLocationTex.Remove(i, 1);
		else
			i++;
	}
}

function ActivateGated(string UniqueName, optional bool bSilent)
{
	local int Day, Errand;
	local P2Player P;

	if (UniqueName == "")
		return;
	if (!FindErrand(UniqueName, Day, Errand))
		return;
	if (Days[Day].IsErrandActive(Errand))
		return;
	ActivateErrand(UniqueName);
	if (bSilent)
		return;
	ShowAPMessage("New errand on "$Days[Day].Description$": "$ErrandNiceName(UniqueName));
	if (TheGameState != None && Day == TheGameState.CurrentDay)
	{
		P = GetPlayer();
		if (P != None && CanPopupErrandMap())
			P.DisplayMapErrands();
	}
}

function bool CanPopupErrandMap()
{
	if (IsIntroMap() || IsCinematic() || IsMainMenuMap())
		return false;
	return true;
}

function ActivateIfUnlocked(string ClassName)
{
	if (ClassName ~= "Inventory.PaycheckInv")
		ShowAPMessage("You got your paycheck. The bank will take it now.");
}

function MaybeRefuseErrand(Actor Other, Pawn ActionPawn)
{
	local string TagStr;

	if (Other == None)
		return;
	if (Level.TimeSeconds < RefuseCooldown)
		return;
	TagStr = string(Other.Tag);

	if (!IsUnlocked("Inventory.ClipboardWeapon") && !HasRecordedCheck("GetSignatures")
		&& Other.IsA('ClipboardWeapon'))
	{
		RefuseCooldown = Level.TimeSeconds + 8;
		ShowAPMessage("I left my do-gooder paperwork in my other pants.");
	}
	else if ((TagStr ~= "UncleDave") && !IsUnlocked("Inventory.GiftInv")
		&& !HasRecordedCheck("GivePresent"))
	{
		RefuseCooldown = Level.TimeSeconds + 8;
		ShowAPMessage("I got nothing for you, you inbred freak.");
	}
	else if (Other.Tag == 'VoteScreen' && !IsUnlocked("ERRAND:Vote"))
	{
		RefuseCooldown = Level.TimeSeconds + 8;
		ShowAPMessage("I'm not filling out a ballot until that's on my list.");
	}
}

function bool VoteBoothShouldWork()
{
	return IsUnlocked("ERRAND:Vote") && !HasRecordedCheck("Vote");
}

function RefuseVoteBooth()
{
	if (Level.TimeSeconds < RefuseCooldown)
		return;
	RefuseCooldown = Level.TimeSeconds + 8;
	ShowAPMessage("I'm not filling out a ballot until that's on my list.");
}

function SyncVoteBooth()
{
	local ScriptedSequence SS;
	local ACTION_P2Screen ScrAct;
	local Triggers T;
	local UseTrigger UT;
	local Trigger Tr;
	local int i, n, j;
	local name VoteTags[8];
	local bool bVote, bOn;

	if (!(MapKey() ~= "SUBURBS-1"))
		return;
	bOn = VoteBoothShouldWork();
	n = 0;
	foreach AllActors(class'ScriptedSequence', SS)
	{
		if (SS == None || SS.Tag == '')
			continue;
		bVote = false;
		for (i = 0; i < SS.Actions.Length; i++)
		{
			ScrAct = ACTION_P2Screen(SS.Actions[i]);
			if (ScrAct != None && string(ScrAct.Screen) ~= "EVoteScreen")
			{
				bVote = true;
				break;
			}
		}
		if (!bVote)
			continue;
		if (n < 8)
		{
			VoteTags[n] = SS.Tag;
			n++;
		}
	}
	if (n == 0)
		return;
	foreach AllActors(class'Triggers', T)
	{
		if (T == None)
			continue;
		bVote = false;
		for (j = 0; j < n; j++)
			if (T.Event == VoteTags[j])
			{
				bVote = true;
				break;
			}
		if (!bVote)
			continue;
		UT = UseTrigger(T);
		if (UT != None)
		{
			UT.bInitiallyActive = bOn;
			if (bOn)
				UT.SetCollision(UT.bSavedInitialCollision, UT.bBlockActors, UT.bBlockPlayers);
			else
				UT.SetCollision(false, UT.bBlockActors, UT.bBlockPlayers);
			continue;
		}
		Tr = Trigger(T);
		if (Tr != None)
		{
			Tr.bInitiallyActive = bOn;
			Tr.SetCollision(bOn, Tr.bBlockActors, Tr.bBlockPlayers);
		}
	}
}


function string StripMapLeaf(string S)
{
	local int i;

	S = Caps(S);
	i = InStr(S, "?");
	if (i != -1)
		S = Left(S, i);
	i = InStr(S, "#");
	if (i != -1)
		S = Left(S, i);
	i = InStr(S, "\\");
	while (i != -1)
	{
		S = Mid(S, i + 1);
		i = InStr(S, "\\");
	}
	i = InStr(S, "/");
	while (i != -1)
	{
		S = Mid(S, i + 1);
		i = InStr(S, "/");
	}
	if (Right(S, 4) ~= ".FUK")
		S = Left(S, Len(S) - 4);
	i = InStr(S, ".");
	if (i != -1)
		S = Left(S, i);
	if (Left(S, 4) ~= "NGT-")
		S = Mid(S, 4);
	return S;
}

function string CurrentMap()
{
	local string S;
	S = GetURLMap();
	if (S == "")
		S = string(Level);
	return StripMapLeaf(S);
}

function string MapKey()
{
	local string M;
	M = CurrentMap();
	if (Left(M, 4) ~= "NGT-")
		M = Mid(M, 4);
	return M;
}

function string VisitKey()
{
	local string K;
	K = MapKey();
	if (K ~= "GREENBELT1" || K ~= "GREENBELT2" || K ~= "PARADE")
		return "GREENBELT";
	if (K ~= "INDUSTRY" || K ~= "INDUSTRY2")
		return "INDUSTRY";
	if (K ~= "LIBRARY1" || K ~= "LIBRARY2")
		return "LIBRARY";
	if (K ~= "HOMEATNIGHT")
		return "SUBURBS-3";
	return K;
}

function string DestMapFromURL(string URL)
{
	return StripMapLeaf(URL);
}

function string AreaLockGrant(string Dest)
{
	if (Dest ~= "LIBRARY1" || Dest ~= "LIBRARY2" || Dest ~= "LIBRARY"
		|| Dest ~= "EASTMALL" || Dest ~= "WESTMALL" || Dest ~= "CHURCH"
		|| Dest ~= "HIGHLANDS")
		return "DAY:Tuesday";
	if (Dest ~= "FOREST" || Dest ~= "BREWERY")
		return "DAY:Wednesday";
	if (Dest ~= "NAPALM" || Dest ~= "GREENBELT2" || Dest ~= "SLAUGHTERHOUSE"
		|| Dest ~= "SUBURBS-4")
		return "DAY:Thursday";
	if (Dest ~= "COMPOUND" || Dest ~= "PARCELCENTER" || Dest ~= "JUNKYARD")
		return "DAY:Friday";
	return "";
}

function string AreaLockHint(string Grant)
{
	if (Grant ~= "AREA:ToraBora")
		return "The tunnel to Tora Bora is sealed. Need Tora Bora Access.";
	if (Grant ~= "DAY:Tuesday")
		return "That area is locked until you have Tuesday.";
	if (Grant ~= "DAY:Wednesday")
		return "That area is locked until you have Wednesday.";
	if (Grant ~= "DAY:Thursday")
		return "That area is locked until you have Thursday.";
	if (Grant ~= "DAY:Friday")
		return "That area is locked until you have Friday.";
	return "That area is locked.";
}

function int AreaMinDay(string Dest)
{
	if (Dest ~= "LIBRARY1" || Dest ~= "LIBRARY2" || Dest ~= "LIBRARY"
		|| Dest ~= "EASTMALL" || Dest ~= "WESTMALL" || Dest ~= "CHURCH"
		|| Dest ~= "HIGHLANDS")
		return 1;
	if (Dest ~= "FOREST" || Dest ~= "BREWERY")
		return 2;
	if (Dest ~= "NAPALM" || Dest ~= "GREENBELT2" || Dest ~= "SLAUGHTERHOUSE"
		|| Dest ~= "SUBURBS-4")
		return 3;
	if (Dest ~= "COMPOUND" || Dest ~= "PARCELCENTER" || Dest ~= "JUNKYARD")
		return 4;
	return -1;
}

function bool AllowTravelURL(string URL)
{
	local string Dest, Need;
	local int MinDay;
	local APGameState GS;

	Dest = DestMapFromURL(URL);
	if (Dest == "" || Dest ~= "INTRO" || Dest ~= "HOMEATNIGHT"
		|| InStr(Dest, "JAIL") != -1 || Dest ~= "SUBURBS-3")
		return true;
	GS = APState();
	if (GS != None)
	{
		if ((Dest ~= "LIBRARY1" || Dest ~= "LIBRARY2") && GS.bWarpLibrary)
			return true;
		if (Dest ~= "BREWERY" && GS.bWarpBrewery)
			return true;
		if (Dest ~= "NAPALM" && GS.bWarpNapalm)
			return true;
		if (Dest ~= "PARCELCENTER" && GS.bWarpParcel)
			return true;
	}
	if (IsUnlocked("WARP:"$Dest))
	{
		MinDay = AreaMinDay(Dest);
		if (MinDay < 0)
			MinDay = 0;
		if (TheGameState != None && TheGameState.CurrentDay >= MinDay)
			return true;
		return false;
	}
	MinDay = AreaMinDay(Dest);
	if (MinDay < 0)
		return true;
	if (TheGameState != None && TheGameState.CurrentDay >= MinDay)
		return true;
	return IsDayUnlocked(MinDay);
}

function NudgeAreaLock(string URL)
{
	local string Need;
	Need = AreaLockGrant(DestMapFromURL(URL));
	if (Need == "")
		return;
	if (Level.TimeSeconds < LastLockMsgTime + 4)
		return;
	LastLockMsgTime = Level.TimeSeconds;
	ShowAPMessage(AreaLockHint(Need));
}

function bool WeLockedTeleporter(string TName)
{
	local int i;
	for (i = 0; i < AreaLockedTeles.Length; i++)
		if (AreaLockedTeles[i] ~= TName)
			return true;
	return false;
}

function RememberLockedTeleporter(string TName)
{
	if (TName == "" || WeLockedTeleporter(TName))
		return;
	AreaLockedTeles[AreaLockedTeles.Length] = TName;
}

function ForgetLockedTeleporter(string TName)
{
	local int i;
	for (i = AreaLockedTeles.Length - 1; i >= 0; i--)
		if (AreaLockedTeles[i] ~= TName)
			AreaLockedTeles.Remove(i, 1);
}

function ApplyAreaLocks()
{
	local Teleporter T;
	local string Dest, Need;
	local bool bLock;

	foreach AllActors(class'Teleporter', T)
	{
		if (T == None)
			continue;
		Dest = DestMapFromURL(T.URL);
		Need = AreaLockGrant(Dest);
		if (Need == "")
		{
			if (WeLockedTeleporter(string(T.Name)) && !T.bEnabled)
			{
				T.bEnabled = true;
				ForgetLockedTeleporter(string(T.Name));
			}
			continue;
		}
		bLock = !AllowTravelURL(T.URL);
		if (bLock)
		{
			if (T.bEnabled)
			{
				T.bEnabled = false;
				RememberLockedTeleporter(string(T.Name));
			}
		}
		else if (!T.bEnabled)
		{
			T.bEnabled = true;
			ForgetLockedTeleporter(string(T.Name));
		}
	}
}

function SendPlayer(PlayerController aPlayer, string URL)
{
	if (!AllowTravelURL(URL))
	{
		NudgeAreaLock(URL);
		return;
	}
	MarkBreweryExitIfNeeded(URL, aPlayer);
	Super.SendPlayer(aPlayer, URL);
}

function SendPlayerLevelTransition(PlayerController player, string URL, bool bRealLevelExit)
{
	if (!AllowTravelURL(URL))
	{
		NudgeAreaLock(URL);
		return;
	}
	MarkBreweryExitIfNeeded(URL, player);
	Super.SendPlayerLevelTransition(player, URL, bRealLevelExit);
}

function string TwoDigit(int N)
{
	if (N < 10)
		return "0"$string(N);
	return string(N);
}

function int LastUnderscore(string S)
{
	local int i, p;

	p = -1;
	i = InStr(S, "_");
	while (i != -1)
	{
		p = i;
		i = InStr(Mid(S, p + 1), "_");
		if (i != -1)
			i = p + 1 + i;
	}
	return p;
}

function string StripLeadingZeros(string S)
{
	while (Len(S) > 1 && Left(S, 1) == "0")
		S = Mid(S, 1);
	return S;
}

function string PickupClassLabel(string Cls)
{
	if (Cls ~= "ShotgunAmmoPickup") return "Shotgun Ammo";
	if (Cls ~= "ShotGunPickup") return "Shotgun";
	if (Cls ~= "PistolAmmoPickup") return "Pistol Ammo";
	if (Cls ~= "PistolPickup") return "Pistol";
	if (Cls ~= "GSelectAmmoPickup") return "Glock Ammo";
	if (Cls ~= "GSelectPickup") return "Glock";
	if (Cls ~= "MP5AmmoPickup") return "MP5 Ammo";
	if (Cls ~= "MP5Pickup") return "MP5";
	if (Cls ~= "MachinegunAmmoPickup") return "Machine Gun Ammo";
	if (Cls ~= "MachineGunPickup") return "Machine Gun";
	if (Cls ~= "RifleAmmoPickup") return "Rifle Ammo";
	if (Cls ~= "RiflePickup") return "Hunting Rifle";
	if (Cls ~= "LauncherAmmoPickup") return "Rocket Ammo";
	if (Cls ~= "LauncherPickup") return "Rocket Launcher";
	if (Cls ~= "NapalmAmmoPickup") return "Napalm Ammo";
	if (Cls ~= "NapalmPickup") return "Napalm Launcher";
	if (Cls ~= "GrenadePickup") return "Grenades";
	if (Cls ~= "GrenadeLauncherPickup") return "Grenade Launcher";
	if (Cls ~= "AWPGrenadeLauncherPickup") return "Grenade Launcher";
	if (Cls ~= "MolotovPickup") return "Molotovs";
	if (Cls ~= "DynamitePickup") return "Dynamite";
	if (Cls ~= "MedKitPickup") return "Medkit";
	if (Cls ~= "MoneyPickup") return "Money";
	if (Cls ~= "DonutPickup") return "Donut";
	if (Cls ~= "PizzaPickup") return "Pizza";
	if (Cls ~= "FastFoodPickup") return "Fast Food";
	if (Cls ~= "CrackPickup") return "Health Pipe";
	if (Cls ~= "CatnipPickup") return "Catnip";
	if (Cls ~= "KevlarPickup") return "Kevlar";
	if (Cls ~= "BodyArmorPickup") return "Body Armor";
	if (Cls ~= "GasCanPickup") return "Gas Can";
	if (Cls ~= "SledgePickup") return "Sledgehammer";
	if (Cls ~= "MachetePickup") return "Machete";
	if (Cls ~= "ScythePickup") return "Scythe";
	if (Cls ~= "ChainsawPickup") return "Chainsaw";
	if (Cls ~= "ShovelPickup") return "Shovel";
	if (Cls ~= "BatonPickup") return "Baton";
	if (Cls ~= "BaseballBatPickup") return "Baseball Bat";
	if (Cls ~= "ShearsPickup") return "Hedge Clippers";
	if (Cls ~= "ShockerPickup") return "Taser";
	if (Cls ~= "ScissorsPickup") return "Scissors";
	if (Cls ~= "AxePickup") return "Axe";
	if (Cls ~= "BaliPickup") return "Bali";
	if (Cls ~= "DustersPickup") return "Dusters";
	if (Cls ~= "SawnOffPickup") return "Sawed-Off Shotgun";
	if (Cls ~= "BetaShotgunPickup") return "Beta Shotgun";
	if (Cls ~= "CowHeadPickup") return "Cow Head";
	if (Cls ~= "FlamePickup") return "Flamethrower";
	if (Cls ~= "GaryHeadPickup") return "Gary Head";
	if (Cls ~= "RadarPickup") return "Bass Sniffer";
	if (Cls ~= "RadarTargetPickup") return "Chompy Cartridge";
	if (Cls ~= "GunRadarPlugPickup") return "Piranha Plug-in";
	if (Cls ~= "CopRadarPlugPickup") return "Largemouth Plug-in";
	if (Cls ~= "DogTreatPickup") return "Dog Treat";
	if (Cls ~= "DogTreatBoxPickup") return "Dog Treats";
	if (Cls ~= "NewspaperPickup") return "Newspaper";
	if (Cls ~= "PlaguePickup") return "WMD";
	if (Cls ~= "PlagueAmmoPickup") return "WMD Ammo";
	if (Cls ~= "NukePickup") return "Mini-Nuke";
	if (Cls ~= "NukeAmmoPickup") return "Mini-Nuke Ammo";
	if (Cls ~= "MrDKNadePickup") return "Krotchy Grenade";
	if (Cls ~= "BoxLauncherPickup") return "Box Launcher";
	if (Cls ~= "CatLauncherPickup") return "Cat Launcher";
	if (Cls ~= "PitchforkPickup") return "Pitchfork";
	if (Cls ~= "ProtestSignPickup") return "Protest Sign";
	if (Cls ~= "RocketCamPickup") return "Rocket Cam";
	if (Cls ~= "DudeClothesPickup") return "Dude Clothes";
	if (Cls ~= "CopClothesPickup") return "Cop Uniform";
	if (Cls ~= "GimpClothesPickup") return "Gimp Suit";
	if (Right(Cls, 6) ~= "Pickup")
		return Left(Cls, Len(Cls) - 6);
	return Cls;
}

function string PrettyLocName(string U)
{
	local string Rest, Cls, Num;
	local int last, prev;

	if (U == "")
		return "";
	if (Left(U, 3) ~= "SC_")
	{
		last = LastUnderscore(U);
		if (last <= 0)
			return U;
		Num = StripLeadingZeros(Mid(U, last + 1));
		Rest = Left(U, last);
		prev = LastUnderscore(Rest);
		if (prev <= 0)
			return PickupClassLabel(Rest)$" "$Num;
		Cls = Mid(Rest, prev + 1);
		return PickupClassLabel(Cls)$" "$Num;
	}
	if (Left(U, 4) ~= "ATM_")
	{
		last = LastUnderscore(U);
		if (last <= 0)
			return "ATM";
		return "ATM "$Mid(U, last + 1);
	}
	if (Left(U, 5) ~= "COLA_")
	{
		last = LastUnderscore(U);
		if (last <= 0)
			return "Crackola";
		return "Crackola "$StripLeadingZeros(Mid(U, last + 1));
	}
	if (Left(U, 5) ~= "VBUY_")
	{
		last = LastUnderscore(U);
		if (last <= 0)
			return "Vending Item";
		return "Vending Item "$StripLeadingZeros(Mid(U, last + 1));
	}
	if (Left(U, 5) ~= "VUSE_")
	{
		last = LastUnderscore(U);
		if (last <= 0)
			return "Vending Machine";
		return "Vending Machine "$StripLeadingZeros(Mid(U, last + 1));
	}
	if (Left(U, 6) ~= "Enter_")
		return "Enter "$Mid(U, 6);
	return U;
}

function int MapPickupCap(string K)
{
	if (K == "")
		return 0;
	if (K ~= "INTRO" || K ~= "GREENBELT1" || K ~= "GREENBELT2" || K ~= "ESTATES"
		|| K ~= "RWSBLOCK" || K ~= "HIGHLANDS" || K ~= "POLICE" || K ~= "INDUSTRY"
		|| K ~= "INDUSTRY2" || K ~= "UNDERHUB" || K ~= "TORABORA" || K ~= "LIBRARY1"
		|| K ~= "LIBRARY2" || K ~= "EASTMALL" || K ~= "WESTMALL" || K ~= "CHURCH"
		|| K ~= "FOREST" || K ~= "BREWERY" || K ~= "NAPALM" || K ~= "SUBURBS-1"
		|| K ~= "SUBURBS-2" || K ~= "SUBURBS-3" || K ~= "SUBURBS-4"
		|| K ~= "SLAUGHTERHOUSE" || K ~= "COMPOUND" || K ~= "PARCELCENTER"
		|| K ~= "JUNKYARD")
		return 12;
	return 0;
}

function string MapGroup()
{
	local string M;
	M = CurrentMap();
	if (InStr(M, "INTRO") != -1 || InStr(M, "HOME") != -1)
		return "HOME";
	if (InStr(M, "RWS") != -1)
		return "RWS";
	if (InStr(M, "GREENBELT1") != -1 || InStr(M, "PARADE") != -1)
		return "MAINSTREET";
	if (InStr(M, "GREENBELT") != -1)
		return "GREENBELT";
	if (InStr(M, "POLICE") != -1)
		return "POLICE";
	if (InStr(M, "INDUSTRY") != -1)
		return "INDUSTRIAL";
	if (InStr(M, "TORA") != -1)
		return "TORABORA";
	if (InStr(M, "EASTMALL") != -1)
		return "EASTMALL";
	if (InStr(M, "WESTMALL") != -1)
		return "WESTMALL";
	if (InStr(M, "LIBRARY") != -1)
		return "LIBRARY";
	if (InStr(M, "CHURCH") != -1)
		return "CHURCH";
	if (InStr(M, "FOREST") != -1)
		return "FOREST";
	if (InStr(M, "NAPALM") != -1)
		return "NAPALM";
	if (InStr(M, "SUBURB") != -1)
		return "SUBURBS";
	if (InStr(M, "SLAUGHTER") != -1)
		return "MEAT";
	if (InStr(M, "PARCEL") != -1)
		return "PARCEL";
	if (InStr(M, "COMPOUND") != -1)
		return "COMPOUND";
	if (InStr(M, "JUNK") != -1)
		return "JUNKYARD";
	if (InStr(M, "ESTATE") != -1)
		return "ESTATES";
	if (InStr(M, "UNDERHUB") != -1 || InStr(M, "SEWER") != -1)
		return "SEWER";
	if (InStr(M, "BREWERY") != -1)
		return "BREWERY";
	if (InStr(M, "HIGHLAND") != -1)
		return "GHETTO";
	if (InStr(M, "TRAIN") != -1)
		return "TRAINYARD";
	if (InStr(M, "CLINIC") != -1)
		return "CLINIC";
	return M;
}

function ReportMapEntry()
{
	local string K, V;
	local APGameState GS;

	K = MapKey();
	if (K == "")
		return;
	if (K != LastMapKey)
	{
		NoteOneShotExit(LastMapKey, K);
		InvalidateScroungeCache();
		ResetMapTokenAnnounce();
	}
	LastMapKey = K;
	if (K ~= "INTRO")
		return;

	GS = APState();
	if (GS == None)
	{
		V = VisitKey();
		LastVisitKey = V;
		return;
	}
	if (GS.HasVisitedMap("PARCELCENTER") && !(K ~= "PARCELCENTER"))
		GS.bWarpParcel = true;
	if (!IsMapTokenOpen(K))
	{
		V = VisitKey();
		LastVisitKey = V;
		return;
	}
	bReturnVisit = GS.HasVisitedMap(K);
	if (GS.HasVisitedMap(K))
	{
		V = VisitKey();
		LastVisitKey = V;
		return;
	}
	GS.RecordVisitedMap(K);

	SendCheck("Enter_"$K);
	V = VisitKey();
	LastVisitKey = V;
}

function NoteOneShotExit(string Prev, string Next)
{
	local APGameState GS;

	GS = APState();
	if (GS == None || Prev == "")
		return;
	if ((Prev ~= "LIBRARY1" || Prev ~= "LIBRARY2")
		&& !(Next ~= "LIBRARY1") && !(Next ~= "LIBRARY2")
		&& (GS.HasVisitedMap("LIBRARY2") || Prev ~= "LIBRARY2"))
		GS.bWarpLibrary = true;
	if (Prev ~= "BREWERY" && !(Next ~= "BREWERY"))
	{
		GS.bWarpBrewery = true;
		GS.bNeedBreweryResync = true;
	}
	if (Prev ~= "NAPALM" && !(Next ~= "NAPALM"))
		GS.bWarpNapalm = true;
	if (Prev ~= "PARCELCENTER" && !(Next ~= "PARCELCENTER"))
		GS.bWarpParcel = true;
}

function bool StoryWarpUnlocked(int Slot)
{
	local APGameState GS;

	GS = APState();
	if (GS == None)
		return false;
	if (Slot == 6 || Slot == 7)
		return GS.bWarpLibrary;
	if (Slot == 8)
		return GS.bWarpBrewery;
	if (Slot == 9)
		return GS.bWarpNapalm;
	if (Slot == 0)
		return GS.bWarpParcel;
	return false;
}

function string TimeWarpStoryLine(int Slot)
{
	local string Line;

	if (Slot == 6)
		Line = "6  Library";
	else if (Slot == 7)
		Line = "7  Burning Library";
	else if (Slot == 8)
		Line = "8  Brewery";
	else if (Slot == 9)
		Line = "9  Napalm Factory";
	else if (Slot == 0)
		Line = "0  Parcel Center";
	else
		return "";
	if (StoryWarpUnlocked(Slot))
		Line = Line$"  open";
	else
		Line = Line$"  LOCKED";
	return Line;
}

function InvalidateScroungeCache()
{
	NextGlowUpdate = 0;
}


function int CountGlowingPickups()
{
	local Pickup Item;
	local string U, Seen;
	local int N, Iter;

	foreach AllActors(class'Pickup', Item)
	{
		Iter++;
		if (Iter > 800)
			break;
		if (Item == None || Item.bDeleteMe || Item.bHidden)
			continue;
		U = UniqueForPickup(Item);
		if (U == "" || HasRecordedCheck(U))
			continue;
		if (!IsAPToken(Item) && NamedUniqueForPickup(Item) == "" && Left(U, 3) != "SC_")
			continue;
		if (InStr(Seen, ";"$U$";") != -1)
			continue;
		Seen = Seen$";"$U$";";
		N++;
	}
	return N;
}

function InvalidateMapTokCounts()
{
	bMapTokDirty = true;
	MapTokScan = 0;
	MapTokK.Length = 0;
	MapTokN.Length = 0;
}

function int FindMapTok(string K)
{
	local int i;

	if (K == "")
		return -1;
	for (i = 0; i < MapTokK.Length; i++)
		if (MapTokK[i] ~= K)
			return i;
	return -1;
}

function IncMapTok(string K)
{
	local int i;

	if (K == "")
		return;
	K = Caps(K);
	i = FindMapTok(K);
	if (i >= 0)
	{
		MapTokN[i] = MapTokN[i] + 1;
		return;
	}
	i = MapTokK.Length;
	MapTokK.Length = i + 1;
	MapTokN.Length = i + 1;
	MapTokK[i] = K;
	MapTokN[i] = 1;
}

function DecMapTok(string K)
{
	local int i;

	if (K == "")
		return;
	i = FindMapTok(Caps(K));
	if (i >= 0 && MapTokN[i] > 0)
		MapTokN[i] = MapTokN[i] - 1;
}

function NoteCatalogCheck(string UniqueName)
{
	local int i, n;

	if (bMapTokDirty || UniqueName == "")
		return;
	n = CatU.Length;
	if (n > 4000)
		n = 4000;
	for (i = 0; i < n; i++)
	{
		if (CatU[i] ~= UniqueName)
		{
			DecMapTok(CatMap[i]);
			return;
		}
	}
}

function TickMapTokCounts()
{
	local int n, added;
	local string U, K;

	if (!bMapTokDirty || !bCheckedSyncReady)
		return;
	n = CatU.Length;
	if (n > 4000)
		n = 4000;
	added = 0;
	while (MapTokScan < n && added < 80)
	{
		U = CatU[MapTokScan];
		K = CatMap[MapTokScan];
		MapTokScan++;
		added++;
		if (U == "" || K == "")
			continue;
		if (HasRecordedCheck(U))
			continue;
		IncMapTok(K);
	}
	if (MapTokScan >= n)
		bMapTokDirty = false;
}

function int CountCatalogLeftForMap(string K)
{
	local int i;

	if (bMapTokDirty)
		return -1;
	i = FindMapTok(Caps(K));
	if (i < 0)
		return 0;
	return MapTokN[i];
}

function int CountAreaTokens(string K)
{
	if (!bCheckedSyncReady)
		return -1;
	return CountCatalogLeftForMap(K);
}

function int MapUnlockDay(string K)
{
	local int D;

	D = AreaMinDay(K);
	if (D < 0)
		return 0;
	return D;
}

function SetMapTokenDay(string K, int D)
{
	local APGameState GS;
	local int i;

	GS = APState();
	if (GS == None || K == "")
		return;
	if (D < 0)
		D = 0;
	if (D > 4)
		D = 4;
	for (i = 0; i < GS.TokenMapK.Length; i++)
	{
		if (GS.TokenMapK[i] ~= K)
		{
			GS.TokenMapD[i] = D;
			NextGlowUpdate = 0;
			return;
		}
	}
	i = GS.TokenMapK.Length;
	GS.TokenMapK.Length = i + 1;
	GS.TokenMapD.Length = i + 1;
	GS.TokenMapK[i] = K;
	GS.TokenMapD[i] = D;
	NextGlowUpdate = 0;
}

function bool HasHuntSchedule()
{
	local APGameState GS;

	GS = APState();
	return (GS != None && GS.TokenMapK.Length > 0);
}

function int MapTokenDayForKey(string K)
{
	local APGameState GS;
	local int i;

	if (K ~= "HOMEATNIGHT" || K ~= "INTRO")
		K = "SUBURBS-3";
	GS = APState();
	if (GS != None)
	{
		for (i = 0; i < GS.TokenMapK.Length; i++)
			if (Caps(GS.TokenMapK[i]) == Caps(K))
				return GS.TokenMapD[i];
	}
	return MapUnlockDay(K);
}

function int HuntDayForKey(string K)
{
	local APGameState GS;
	local int i;

	if (K ~= "HOMEATNIGHT" || K ~= "INTRO")
		K = "SUBURBS-3";
	GS = APState();
	if (GS == None)
		return -1;
	for (i = 0; i < GS.TokenMapK.Length; i++)
		if (Caps(GS.TokenMapK[i]) == Caps(K))
			return GS.TokenMapD[i];
	return -1;
}

function bool IsHuntUnlocked(optional string K)
{
	local int D;

	if (K == "")
		K = MapKey();
	if (K ~= "INTRO")
		return false;
	if (K ~= "HOMEATNIGHT")
		K = "SUBURBS-3";
	if (!HasHuntSchedule())
		return false;
	D = HuntDayForKey(K);
	if (D < 0)
		return false;
	return IsDayUnlocked(D);
}

function bool IsMapTokenOpen(optional string K)
{
	local int D, Today;

	if (K == "")
		K = MapKey();
	if (K ~= "INTRO")
		return false;
	if (K ~= "HOMEATNIGHT")
		K = "SUBURBS-3";
	if (!HasHuntSchedule())
		return false;
	D = HuntDayForKey(K);
	if (D < 0)
		return false;
	if (!IsDayUnlocked(D))
		return false;
	Today = 0;
	if (TheGameState != None)
		Today = TheGameState.CurrentDay;
	return Today == D;
}

function bool HasVisitedArea(string K)
{
	local APGameState GS;

	GS = APState();
	if (GS == None || K == "")
		return false;
	if (K ~= "HOMEATNIGHT" || K ~= "INTRO")
		K = "SUBURBS-3";
	return GS.HasVisitedMap(K);
}

function string AreaAbbrev(string K)
{
	if (K ~= "SUBURBS-3" || K ~= "INTRO") return "Home";
	if (K ~= "SUBURBS-1") return "Main Street";
	if (K ~= "SUBURBS-2") return "Ghetto";
	if (K ~= "SUBURBS-4") return "Suburbs East";
	if (K ~= "RWSBLOCK") return "Office Complex";
	if (K ~= "WESTMALL") return "West Mall";
	if (K ~= "EASTMALL") return "East Mall";
	if (K ~= "HIGHLANDS") return "Trainyard Area";
	if (K ~= "INDUSTRY") return "Clinic Area";
	if (K ~= "INDUSTRY2") return "Industrial Area";
	if (K ~= "GREENBELT1") return "Greenbelt";
	if (K ~= "GREENBELT2") return "Napalm Factory Exterior";
	if (K ~= "NAPALM") return "Napalm Factory";
	if (K ~= "COMPOUND") return "Compound";
	if (K ~= "LIBRARY1") return "Library";
	if (K ~= "LIBRARY2") return "Burning Library";
	if (K ~= "PARCELCENTER") return "Parcel Center";
	if (K ~= "POLICE") return "Police Station";
	if (K ~= "SLAUGHTERHOUSE") return "Meat World";
	if (K ~= "CHURCH") return "Church and Cemetery";
	if (K ~= "BREWERY") return "Brewery";
	if (K ~= "ESTATES") return "Chicken Queen Estates";
	if (K ~= "JUNKYARD") return "Junkyard";
	if (K ~= "FOREST") return "Forest";
	if (K ~= "UNDERHUB") return "Sewers";
	if (K ~= "TORABORA") return "Tora Bora";
	return "";
}

function string HuntDayAbbrev(int D)
{
	if (D == 0) return "M";
	if (D == 1) return "T";
	if (D == 2) return "W";
	if (D == 3) return "Th";
	if (D == 4) return "F";
	return "";
}

function string AreaMapTitle(string K)
{
	local string Title, Tag;
	local int D;

	Title = AreaAbbrev(K);
	if (Title == "")
		return "";
	D = HuntDayForKey(K);
	if (D < 0)
		return Title;
	if (!IsDayUnlocked(D))
		return Title;
	Tag = HuntDayAbbrev(D);
	if (Tag == "")
		return Title;
	return Title$" ("$Tag$")";
}

function ResetMapTokenAnnounce()
{
	bAnnouncedMapPickups = false;
	bRemindedMapPickups = false;
	bAnnouncedAllFound = false;
	MapAnnounceAt = Level.TimeSeconds + 2.0;
	MapRemindAt = Level.TimeSeconds + 90.0;
	bVendCureTriggered = false;
	VendCureFallbackAt = 0;
}

function int CountMapTokensLeft()
{
	if (IsMapTokenOpen())
		return CountGlowingPickups();
	return CountCatalogLeftForMap(MapKey());
}

function AnnounceMapPickups()
{
	local int N;

	if (!IsMapTokenOpen())
		return;
	if (!bCheckedSyncReady)
		return;
	if (MapPickupCap(MapKey()) <= 0)
		return;
	if (APState() != None && APState().APSeed == "")
		return;
	if (CatU.Length == 0 && Level.TimeSeconds < MapAnnounceAt + 8.0)
		return;

	N = CountMapTokensLeft();
	if (N <= 0)
	{
		if (!bAnnouncedAllFound)
		{
			ShowAPMessage("All AP Tokens found in this area.");
			bAnnouncedAllFound = true;
			bAnnouncedMapPickups = true;
			bRemindedMapPickups = true;
		}
		return;
	}

	if (!bAnnouncedMapPickups)
	{
		if (Level.TimeSeconds < MapAnnounceAt)
			return;
		ShowAPMessage("There are "$string(N)$" AP tokens in this area.");
		bAnnouncedMapPickups = true;
		return;
	}

	if (!bRemindedMapPickups && Level.TimeSeconds >= MapRemindAt)
	{
		N = CountMapTokensLeft();
		if (N <= 0)
		{
			if (!bAnnouncedAllFound)
			{
				ShowAPMessage("All AP Tokens found in this area.");
				bAnnouncedAllFound = true;
			}
		}
		else
			ShowAPMessage("There are still "$string(N)$" AP Tokens left in this area.");
		bRemindedMapPickups = true;
	}
}

function bool IsErrandWorldPickup(Pickup Item)
{
	if (Item == None)
		return false;
	if (P2WeaponPickupErrand(Item) != None)
		return true;
	if (P2PowerupPickup(Item) != None && P2PowerupPickup(Item).bUseForErrands)
		return true;
	if (Item.IsA('AlternatorPickup') || Item.IsA('ParcelPickup') || Item.IsA('SteakPickup')
		|| Item.IsA('KrotchyPickup') || Item.IsA('NapalmPickupErrand')
		|| Item.IsA('MilkPickup') || Item.IsA('PaycheckPickup')
		|| Item.IsA('CitationPickup') || Item.IsA('GiftPickup')
		|| Item.IsA('LibraryBookPickup') || Item.IsA('DudeClothesPickup')
		|| Item.IsA('GaryBookPickup') || Item.IsA('PillsPickup')
		|| Item.IsA('TreePickup'))
		return true;
	if (Item.Tag == 'AlternatorPickup' || Item.Tag == 'NapalmPickupErrand'
		|| Item.Tag == 'KrotchyPickup' || Item.Tag == 'ParcelPickup'
		|| Item.Tag == 'SteakPickup' || Item.Tag == 'MilkPickup'
		|| Item.Tag == 'PaycheckPickup' || Item.Tag == 'PillsPickup'
		|| Item.Tag == 'TreePickup' || Item.Tag == 'GaryBookPickup'
		|| Item.Tag == 'DudeClothesPickup' || Item.Tag == 'BankDeposit')
		return true;
	return false;
}

function string ErrandUniqueForWorldPickup(Pickup Item)
{
	if (Item == None)
		return "";
	if (Item.IsA('AlternatorPickup') || Item.Tag == 'AlternatorPickup')
		return "GetAlternator";
	if (Item.IsA('ParcelPickup') || Item.Tag == 'ParcelPickup')
		return "PickupPackage";
	if (Item.IsA('SteakPickup') || Item.Tag == 'SteakPickup')
		return "GetSteaks";
	if (Item.IsA('KrotchyPickup') || Item.Tag == 'KrotchyPickup')
		return "GetKrotchy";
	if (Item.IsA('NapalmPickupErrand') || Item.Tag == 'NapalmPickupErrand')
		return "GetNapalm";
	if (Item.IsA('MilkPickup') || Item.Tag == 'MilkPickup')
		return "GetMilk";
	if (Item.IsA('PaycheckPickup') || Item.Tag == 'PaycheckPickup')
		return "GetPaycheck";
	if (Item.IsA('PillsPickup') || Item.Tag == 'PillsPickup')
		return "VisitClinic";
	if (Item.IsA('TreePickup') || Item.Tag == 'TreePickup')
		return "GetTree";
	if (Item.IsA('DudeClothesPickup') || Item.Tag == 'DudeClothesPickup')
		return "PickupLaundry";
	if (Item.IsA('GaryBookPickup') || Item.Tag == 'GaryBookPickup')
		return "GetGary";
	if (Item.Tag == 'BankDeposit')
		return "CashPaycheck";
	return "";
}


function RestoreErrandPickup(Pickup Item)
{
	local class<Pickup> C;
	local APTokenSprite S;

	if (Item == None)
		return;
	S = FindTokenSprite(Item);
	if (S != None)
		S.Destroy();
	if (Item.DrawType != DT_Sprite || Item.Texture != Texture'Archipelago.APLogo')
	{
		if (S == None)
			return;
	}
	C = Item.Class;
	Item.SetDrawType(C.default.DrawType);
	if (C.default.StaticMesh != None)
		Item.SetStaticMesh(C.default.StaticMesh);
	Item.Texture = C.default.Texture;
	Item.Style = C.default.Style;
	Item.bUnlit = C.default.bUnlit;
	Item.AmbientGlow = C.default.AmbientGlow;
	Item.LightType = LT_None;
	Item.bDynamicLight = false;
	if (C.default.DrawScale > 0)
		Item.SetDrawScale(C.default.DrawScale);
}

function ClearScroungeCatalog()
{
	CatU.Length = 0;
	CatCls.Length = 0;
	CatMap.Length = 0;
	CatX.Length = 0;
	CatY.Length = 0;
	CatZ.Length = 0;
	CatHere.Length = 0;
	CatHereKey = "";
	InvalidateMapTokCounts();
	bCheckedSyncReady = false;
	if (Level != None)
	{
		LastCatchUpTime = Level.TimeSeconds;
		if (LastCatchUpTime <= 0)
			LastCatchUpTime = 0.01;
	}
}

function AddScroungeCatalog(string UniqueName, string Cls, string MapK, int X, int Y, int Z)
{
	local int n;
	local vector Loc;

	if (MapK ~= "INTRO")
		return;
	if (Cls ~= "CrackColaPickup")
		return;
	Loc.X = X;
	Loc.Y = Y;
	Loc.Z = Z;
	if (IsBlockedTokenSpot(MapK, Loc))
		return;
	n = CatU.Length;
	if (n > 0 && CatU[n - 1] ~= UniqueName)
		return;
	if (n > 4000)
		return;
	CatU[n] = UniqueName;
	CatCls[n] = Cls;
	CatMap[n] = MapK;
	CatX[n] = X;
	CatY[n] = Y;
	CatZ[n] = Z;
	CatHereKey = "";
}

function bool CatalogHasUnique(string U)
{
	local int i;

	if (U == "")
		return false;
	for (i = 0; i < CatU.Length; i++)
		if (CatU[i] ~= U)
			return true;
	return false;
}

function RebuildCatHere()
{
	local int i;
	local string K;

	K = MapKey();
	CatHere.Length = 0;
	CatHereKey = K;
	if (K == "")
		return;
	for (i = 0; i < CatU.Length; i++)
	{
		if (Caps(CatMap[i]) == Caps(K))
			CatHere[CatHere.Length] = i;
	}
}

function bool CatalogClassMatch(Pickup Item, string Cls)
{
	local string C, Want;

	if (Item == None || Cls == "")
		return false;
	Want = Caps(Cls);
	C = Caps(string(Item.Class.Name));
	if (C ~= Want)
		return true;
	C = Caps(string(Item.Class));
	if (C ~= Want)
		return true;
	if (Right(C, Len(Want) + 1) ~= ("."$Want))
		return true;
	return false;
}

function ParseScroungeLine(string Arg)
{
	local string U, Cls, MapK, Rest;
	local int i, X, Y, Z;

	i = InStr(Arg, " ");
	if (i == -1)
		return;
	U = Left(Arg, i);
	Rest = Mid(Arg, i + 1);
	i = InStr(Rest, " ");
	if (i == -1)
		return;
	Cls = Left(Rest, i);
	Rest = Mid(Rest, i + 1);
	i = InStr(Rest, " ");
	if (i == -1)
		return;
	MapK = Left(Rest, i);
	Rest = Mid(Rest, i + 1);
	i = InStr(Rest, " ");
	if (i == -1)
		return;
	X = int(Left(Rest, i));
	Rest = Mid(Rest, i + 1);
	i = InStr(Rest, " ");
	if (i == -1)
		return;
	Y = int(Left(Rest, i));
	Z = int(Mid(Rest, i + 1));
	AddScroungeCatalog(U, Cls, MapK, X, Y, Z);
	NextGlowUpdate = 0;
}

function bool IsBlockedTokenSpot(string MapK, vector Loc)
{
	local vector Box;

	if (MapK ~= "RWSBLOCK")
	{
		Box.X = -4261;
		Box.Y = -4189;
		Box.Z = -150;
		if (VSize(Loc - Box) < 120)
			return true;
		Box.X = -8315;
		Box.Y = -2402;
		Box.Z = -768;
		if (VSize(Loc - Box) < 120)
			return true;
		// Unbreakable box around MP5 Ammo 3: MP5 1-5, Glock Ammo 1-5, BoxLauncher.
		Box.X = -7576;
		Box.Y = 1960;
		Box.Z = -387;
		if (VSize(Loc - Box) < 80)
			return true;
	}
	if (MapK ~= "SUBURBS-3")
	{
		Box.X = 5875;
		Box.Y = -2718;
		Box.Z = -4782;
		if (VSize(Loc - Box) < 32)
			return true;
		// Load-zone pocket: Kevlar 6, Grenade 13/14, Pistol 8/9. 160 covers all five.
		Box.X = 10668;
		Box.Y = -12391;
		Box.Z = -6154;
		if (VSize(Loc - Box) < 160)
			return true;
		Box.X = 10622;
		Box.Y = -12459;
		Box.Z = -6159;
		if (VSize(Loc - Box) < 40)
			return true;
		Box.X = 10765;
		Box.Y = -12290;
		Box.Z = -6166;
		if (VSize(Loc - Box) < 40)
			return true;
	}
	if (MapK ~= "SUBURBS-2")
	{
		Box.X = -5228;
		Box.Y = -5115;
		Box.Z = 0;
		if (VSize(Loc - Box) < 50)
			return true;
		Box.X = 2401;
		Box.Y = 2401;
		Box.Z = 0;
		if (VSize(Loc - Box) < 50)
			return true;
		// Glock Ammo 4 on the derailed train bridge (cheat-only). Tight so
		// MP5 Ammo 3 ~28 UU away is not swallowed. Radius 20 still covers
		// catalog spawn at Z+16.
		Box.X = -3537;
		Box.Y = -2019;
		Box.Z = -4662;
		if (VSize(Loc - Box) < 20)
			return true;
	}
	if (Abs(Loc.Z) < 8)
	{
		if (MapK ~= "SUBURBS-2" || MapK ~= "SUBURBS-4"
			|| MapK ~= "GREENBELT1" || MapK ~= "GREENBELT2"
			|| MapK ~= "HIGHLANDS" || MapK ~= "SLAUGHTERHOUSE"
			|| MapK ~= "TORABORA")
			return true;
	}
	if (MapK ~= "HIGHLANDS")
	{
		Box.X = 1646;
		Box.Y = -10207;
		Box.Z = -1004;
		if (VSize(Loc - Box) < 20)
			return true;
		Box.X = 1687;
		Box.Y = -9784;
		Box.Z = -972;
		if (VSize(Loc - Box) < 40)
			return true;
	}
	if (MapK ~= "UNDERHUB")
	{
		Box.X = -2218;
		Box.Y = -398;
		Box.Z = 0;
		if (VSize(Loc - Box) < 50)
			return true;
	}
	if (MapK ~= "ESTATES")
	{
		Box.X = -5754;
		Box.Y = -514;
		Box.Z = 0;
		if (VSize(Loc - Box) < 40)
			return true;
	}
	if (MapK ~= "POLICE")
	{
		Box.X = -4616;
		Box.Y = -10559;
		Box.Z = -5209;
		if (VSize(Loc - Box) < 40)
			return true;
		// Catnip 1 inside a cardboard box. Tight so Catnip 2 stays.
		Box.X = -5415;
		Box.Y = -13112;
		Box.Z = -5018;
		if (VSize(Loc - Box) < 40)
			return true;
	}
	if (MapK ~= "BREWERY")
	{
		Box.X = -1819;
		Box.Y = -204;
		Box.Z = 0;
		if (VSize(Loc - Box) < 40)
			return true;
	}
	return false;
}

function string WorldPickupUnique(Pickup Item)
{
	local int i, idx;
	local string K;
	local vector Want;

	if (Item == None)
		return "";
	K = MapKey();
	if (K == "" || CatU.Length == 0)
		return "";
	if (CatHereKey != K)
		RebuildCatHere();
	for (i = 0; i < CatHere.Length; i++)
	{
		idx = CatHere[i];
		if (!CatalogClassMatch(Item, CatCls[idx]))
			continue;
		Want.X = CatX[idx];
		Want.Y = CatY[idx];
		Want.Z = CatZ[idx];
		if (IsBlockedTokenSpot(K, Want))
			continue;
		if (VSize(Item.Location - Want) < CatalogMatchRadius())
			return CatU[idx];
	}
	return "";
}

function string CatalogUniqueForPickup(Pickup Item)
{
	local string U;

	if (Item == None)
		return "";
	if (APWorldPickup(Item) != None && APWorldPickup(Item).APUnique != "")
		return APWorldPickup(Item).APUnique;
	U = NamedUniqueForPickup(Item);
	if (U != "" && !IsErrandCheck(U) && !(U ~= "BreweryRestore") && APShopPickup(Item) == None)
	{
		if (!CatalogHasUnique(U))
			U = "";
	}
	if (U == "")
		U = WorldPickupUnique(Item);
	return U;
}

function string UniqueForPickup(Pickup Item)
{
	local string U;

	if (Item == None)
		return "";
	if (APTimeWarpPickup(Item) != None)
		return "";
	U = CatalogUniqueForPickup(Item);
	if (U == "")
		return "";
	if (!IsAPToken(Item) && APShopPickup(Item) == None && !IsErrandCheck(U)
		&& !(U ~= "BreweryRestore"))
	{
		if (!IsMapTokenOpen())
			return "";
		if (TokenExistsForUnique(U, Item))
			return "";
		if (HasRecordedCheck(U))
			return "";
	}
	return U;
}

function string NamedUniqueForPickup(Pickup Item)
{
	local string K;

	if (Item == None)
		return "";
	K = MapKey();

	if (Item.IsA('PaycheckPickup') || Item.Tag == 'PaycheckPickup')
		return "GetPaycheck";
	if (Item.IsA('MilkPickup') || Item.Tag == 'MilkPickup')
		return "GetMilk";
	if (APRestorePickup(Item) != None && K ~= "BREWERY")
		return "BreweryRestore";
	if (Item.IsA('GimpClothesPickup') && K ~= "BREWERY")
		return "BreweryGimp";
	if (APShopPickup(Item) != None)
		return VendorBuyUniqueForPickup(Item);
	return "";
}

function bool IsErrandCheck(string U)
{
	if (U ~= "GetPaycheck" || U ~= "GetMilk")
		return true;
	if (U ~= "BreweryGimp" || U ~= "BreweryRestore")
		return true;
	return false;
}

function bool IsAPToken(Pickup Item)
{
	if (Item == None)
		return false;
	if (APTimeWarpPickup(Item) != None)
		return false;
	if (APWorldPickup(Item) != None)
		return true;
	if (Item.DrawType == DT_Sprite && (Item.Texture == Texture'Archipelago.APLogo'
		|| Item.Texture == Texture'Archipelago.APLogoGrey'))
		return true;
	if (Item.DrawType == DT_None && FindTokenSprite(Item) != None)
		return true;
	return false;
}

function APTokenSprite FindTokenSprite(Pickup Item)
{
	local APTokenSprite S;

	if (Item == None)
		return None;
	foreach Item.BasedActors(class'APTokenSprite', S)
		return S;
	return None;
}

function ForceAPLogoFlags()
{
	local Texture T;

	T = Texture'Archipelago.APLogo';
	if (T != None)
	{
		T.bAlphaTexture = true;
		T.bMasked = true;
	}
	T = Texture'Archipelago.APLogoGrey';
	if (T != None)
	{
		T.bAlphaTexture = true;
		T.bMasked = true;
	}
}

function bool ShouldBeAPToken(Pickup Item)
{
	local string U;
	local int i;

	if (Item == None || Item.bDeleteMe)
		return false;
	if (MapKey() ~= "INTRO")
		return false;
	if (APRestorePickup(Item) != None)
		return false;
	if (APTimeWarpPickup(Item) != None)
		return false;
	if (!IsMapTokenOpen())
		return false;
	if (IsErrandWorldPickup(Item))
		return false;
	if (IsAPToken(Item))
		return true;
	if (P2WeaponPickupErrand(Item) != None)
		return false;
	if (P2PowerupPickup(Item) != None && P2PowerupPickup(Item).bUseForErrands)
		return false;
	U = UniqueForPickup(Item);
	if (U == "" || IsErrandCheck(U))
		return false;
	if (HasRecordedCheck(U))
		return false;
	return true;
}

function bool ShouldConsumeAsAPToken(Pickup Item)
{
	local string U;

	if (IsErrandWorldPickup(Item))
		return false;
	if (IsAPToken(Item))
		return true;
	U = UniqueForPickup(Item);
	if (U == "" || IsErrandCheck(U))
		return false;
	if (P2WeaponPickupErrand(Item) != None)
		return false;
	if (P2PowerupPickup(Item) != None && P2PowerupPickup(Item).bUseForErrands)
		return false;
	return true;
}

function bool PickupHasHeadroom(Pickup Item)
{
	local vector Start, End, HL, HN;
	local Actor Hit;

	if (Item == None)
		return false;
	Start = Item.Location + vect(0,0,10);
	End = Start + vect(0,0,48);
	Hit = Item.Trace(HL, HN, End, Start, true);
	if (Hit == None || Hit == Item || Pickup(Hit) != None || Pawn(Hit) != None)
		return true;
	return false;
}

function ApplyTokenSpawnNudge(out vector Loc, string U)
{
	// Police locker cop uniform: catalog Z sits in the locker ceiling, and
	// UncoverIfBuried used to lift it through the top-floor roof.
	if (U ~= "SC_POLICE_CopClothesPickup_01")
	{
		// Catalog Z is in the locker ceiling. A live locker pile already
		// sits at ~-4606 with the other locker tokens.
		if (Loc.Z > -4595)
		{
			Loc.X += 24;
			Loc.Y += 24;
			Loc.Z -= 40;
		}
		return;
	}
	// Locker Room Health Pipe: catalog is in the east locker back. Aisle is -X.
	if (U ~= "SC_POLICE_CrackPickup_01")
	{
		Loc.X -= 56;
		if (Loc.Z > -4606)
			Loc.Z = -4606;
		return;
	}
	// Evidence Room bottom shelves. The catalog origin is against the brick,
	// so the 34-radius token sits inside the shelf. South wall (dynamite,
	// shotgun) pulls toward -Y. North wall (gimp suit) pulls toward +Y.
	// Z below -5268 on the north wall keeps the next shelf up. The armory
	// row near X -2600 is outside this box.
	if (Left(U, 10) ~= "SC_POLICE_"
		&& Loc.X > -4900 && Loc.X < -4300
		&& Loc.Z > -5295 && Loc.Z < -5240)
	{
		if (Loc.Y > -10220 && Loc.Y < -10130)
		{
			Loc.Y -= 56;
			return;
		}
		if (Loc.Y > -10620 && Loc.Y < -10540 && Loc.Z < -5268)
		{
			Loc.Y += 56;
			return;
		}
	}
	// Clinic Area Warehouse North: Medkit 2 catalog is west of the shelf.
	if (U ~= "SC_INDUSTRY_MedKitPickup_02")
	{
		Loc.X += 72;
		return;
	}
}

function PullFromWall(Pickup Item)
{
	local int i;
	local vector Dirs[4], Start, End, HL, HN, Pull;
	local Actor Hit;
	local float Clear, BestClear, MinClear, Dist;
	local vector BestDir;

	if (Item == None)
		return;

	Dirs[0] = vect(1,0,0);
	Dirs[1] = vect(-1,0,0);
	Dirs[2] = vect(0,1,0);
	Dirs[3] = vect(0,-1,0);

	BestClear = 0;
	MinClear = 9999;
	BestDir = vect(0,0,0);

	for (i = 0; i < 4; i++)
	{
		Start = Item.Location + vect(0,0,12);
		End = Start + Dirs[i] * 120;
		Hit = Item.Trace(HL, HN, End, Start, true);
		if (Hit == None || Hit == Item || Pickup(Hit) != None || Pawn(Hit) != None)
			Clear = 120;
		else
			Clear = VSize(HL - Start);
		if (Clear > BestClear)
		{
			BestClear = Clear;
			BestDir = Dirs[i];
		}
		if (Clear < MinClear)
			MinClear = Clear;
	}

	if (MinClear >= 40)
		return;
	Dist = 48;
	if (Dist > BestClear - 8)
		Dist = BestClear - 8;
	if (Dist < 16)
		Dist = 16;
	Pull = Item.Location + BestDir * Dist;
	Item.SetLocation(Pull);
}

function UncoverIfBuried(Pickup Item)
{
	local int i, Ring;
	local float Dist;
	local vector Try, Off, Start, End, HL, HN;
	local Actor Hit;
	local vector Dirs[8];
	local APWorldPickup W;

	if (Item == None)
		return;

	PullFromWall(Item);

	W = APWorldPickup(Item);
	if (W != None && (W.APUnique ~= "SC_POLICE_CopClothesPickup_01"
		|| W.APUnique ~= "SC_POLICE_CrackPickup_01"))
		return;

	if (PickupHasHeadroom(Item))
		return;

	Dirs[0] = vect(1,0,0);
	Dirs[1] = vect(1,1,0);
	Dirs[2] = vect(0,1,0);
	Dirs[3] = vect(-1,1,0);
	Dirs[4] = vect(-1,0,0);
	Dirs[5] = vect(-1,-1,0);
	Dirs[6] = vect(0,-1,0);
	Dirs[7] = vect(1,-1,0);

	for (Ring = 1; Ring <= 3; Ring++)
	{
		Dist = 56 * Ring;
		for (i = 0; i < 8; i++)
		{
			Off = Dirs[i];
			if (VSize(Off) > 1)
				Off = Normal(Off);
			Try = Item.Location + Off * Dist;
			Start = Try + vect(0,0,80);
			End = Try - vect(0,0,48);
			Hit = Item.Trace(HL, HN, End, Start, false);
			if (Hit != None)
				Try = HL + vect(0,0,12);
			if (PickupHasHeadroomAt(Item, Try))
			{
				Item.SetLocation(Try);
				return;
			}
		}
	}

	// Cap the Z lift so a top-floor locker cannot punch through to the roof.
	for (i = 1; i <= 4; i++)
	{
		Try = Item.Location;
		Try.Z += 24 * i;
		if (PickupHasHeadroomAt(Item, Try))
		{
			Item.SetLocation(Try);
			return;
		}
	}
}

function bool PickupHasHeadroomAt(Pickup Item, vector Loc)
{
	local vector Start, End, HL, HN;
	local Actor Hit;

	if (Item == None)
		return false;
	Start = Loc + vect(0,0,10);
	End = Start + vect(0,0,48);
	Hit = Item.Trace(HL, HN, End, Start, true);
	if (Hit == None || Hit == Item || Pickup(Hit) != None || Pawn(Hit) != None)
		return true;
	return false;
}

function bool ListHasUnique(out array<string> List, string U)
{
	local int i, n;

	if (U == "")
		return false;
	n = List.Length;
	if (n > 4000)
		n = 4000;
	for (i = 0; i < n; i++)
		if (List[i] ~= U)
			return true;
	return false;
}

function RememberUnique(out array<string> List, string U)
{
	if (U == "" || ListHasUnique(List, U))
		return;
	if (List.Length >= 4000)
		return;
	List[List.Length] = U;
}

function bool TokenExistsForUnique(string U, optional Pickup Ignore)
{
	local APWorldPickup T;
	local APTokenSprite S;
	local Pickup P;
	local string PU;
	local int Hits;

	if (U == "")
		return false;
	foreach DynamicActors(class'APWorldPickup', T)
	{
		Hits++;
		if (Hits > 4000)
			break;
		if (T == None || T == Ignore || T.bDeleteMe || T.bHidden)
			continue;
		if (T.APUnique ~= U)
			return true;
	}
	Hits = 0;
	foreach DynamicActors(class'APTokenSprite', S)
	{
		Hits++;
		if (Hits > 4000)
			break;
		if (S == None || S.bDeleteMe)
			continue;
		P = Pickup(S.Owner);
		if (P == None)
			P = S.Target;
		if (P == None || P == Ignore || P.bDeleteMe || P.bHidden)
			continue;
		if (APWorldPickup(P) != None)
			continue;
		PU = CatalogUniqueForPickup(P);
		if (PU ~= U)
			return true;
	}
	return false;
}

function Pickup ConvertToAPToken(Pickup Item, optional string ForcedUnique)
{
	local APWorldPickup Token;
	local string U;
	local vector Loc;

	if (Item == None || Item.bDeleteMe)
		return None;
	if (MapKey() ~= "INTRO")
		return None;
	if (APRestorePickup(Item) != None)
	{
		Item.Destroy();
		return None;
	}
	if (APTimeWarpPickup(Item) != None)
		return Item;
	if (!IsMapTokenOpen())
		return None;
	if (IsErrandWorldPickup(Item))
		return Item;
	if (Item.bHidden)
		return None;

	ForceAPLogoFlags();

	if (APShopPickup(Item) != None)
	{
		DressAPToken(Item);
		return Item;
	}

	if (ForcedUnique != "")
		U = ForcedUnique;
	else
		U = UniqueForPickup(Item);

	if (APWorldPickup(Item) != None)
	{
		if (U == "" || HasRecordedCheck(U))
		{
			ConsumeAPToken(Item);
			return None;
		}
		DressAPToken(Item);
		return Item;
	}

	if (U == "")
		return None;
	if (HasRecordedCheck(U))
	{
		ConsumeAPToken(Item);
		return None;
	}
	if (TokenExistsForUnique(U, Item))
		return None;
	if (IsBlockedTokenSpot(MapKey(), Item.Location))
		return None;

	Loc = Item.Location;
	Token = SpawnAPWorldAt(Loc, U);
	if (Token == None)
	{
		DressAPToken(Item);
		UncoverIfBuried(Item);
		DressAPToken(Item);
		return Item;
	}

	Token.SourceName = Item.Name;
	Token.Tag = Item.Tag;

	Item.SetCollision(false, false, false);
	Item.bHidden = true;
	Item.bAlwaysRelevant = false;

	return Token;
}

function APWorldPickup SpawnAPWorldAt(vector Loc, string U)
{
	local APWorldPickup Token;
	local P2Player P;
	local vector Try;
	local int i;

	if (U ~= "SC_GREENBELT1_MedKitPickup_04")
		Loc.Z += 96;
	ApplyTokenSpawnNudge(Loc, U);

	Try = Loc;
	Try.Z += 16;
	Token = Spawn(class'APWorldPickup',,, Try);
	if (Token == None && !(U ~= "SC_POLICE_CopClothesPickup_01")
		&& !(U ~= "SC_POLICE_CrackPickup_01"))
	{
		for (i = 1; i <= 8; i++)
		{
			Token = Spawn(class'APWorldPickup',,, Loc + vect(0,0,24) * i);
			if (Token != None)
				break;
		}
	}
	if (Token == None)
	{
		P = GetPlayer();
		if (P != None && P.Pawn != None)
		{
			Token = Spawn(class'APWorldPickup',,, P.Pawn.Location + vect(0,0,48));
			if (Token != None)
				Token.SetLocation(Try);
		}
	}
	if (Token == None)
		return None;
	Token.APUnique = U;
	UncoverIfBuried(Token);
	DressAPToken(Token);
	return Token;
}

function SpawnMissingCatalogTokens()
{
	local int i, idx, Iter;
	local string K, U;
	local vector Loc;
	local APWorldPickup Token, T;
	local APTokenSprite Spr;
	local Pickup P, Made, Src;
	local array<string> SeenU;

	K = MapKey();
	if (K == "" || K ~= "INTRO" || !IsMapTokenOpen(K))
		return;
	if (!bCheckedSyncReady)
		return;
	if (CatHereKey != K)
		RebuildCatHere();

	foreach DynamicActors(class'APWorldPickup', T)
	{
		if (T == None || T.bDeleteMe || T.bHidden)
			continue;
		if (T.APUnique != "")
			RememberUnique(SeenU, T.APUnique);
	}
	foreach DynamicActors(class'APTokenSprite', Spr)
	{
		if (Spr == None || Spr.bDeleteMe)
			continue;
		Src = Pickup(Spr.Owner);
		if (Src == None)
			Src = Spr.Target;
		if (Src == None || Src.bDeleteMe || APWorldPickup(Src) != None)
			continue;
		U = CatalogUniqueForPickup(Src);
		if (U != "")
			RememberUnique(SeenU, U);
	}

	foreach AllActors(class'Pickup', P)
	{
		Iter++;
		if (Iter > 2000)
			break;
		if (P == None || P.bDeleteMe || P.bHidden)
			continue;
		if (APWorldPickup(P) != None || APShopPickup(P) != None)
			continue;
		if (APTimeWarpPickup(P) != None || APRestorePickup(P) != None)
			continue;
		if (P.DrawType == DT_None)
			continue;
		if (IsErrandWorldPickup(P))
			continue;
		U = CatalogUniqueForPickup(P);
		if (U == "" || HasRecordedCheck(U) || ListHasUnique(SeenU, U))
			continue;
		Made = ConvertToAPToken(P, U);
		if (Made != None)
		{
			EnsureCheckGlow(Made);
			RememberUnique(SeenU, U);
		}
	}

	for (i = 0; i < CatHere.Length; i++)
	{
		idx = CatHere[i];
		U = CatU[idx];
		if (U == "" || HasRecordedCheck(U) || ListHasUnique(SeenU, U))
			continue;
		Loc.X = CatX[idx];
		Loc.Y = CatY[idx];
		Loc.Z = CatZ[idx];
		if (IsBlockedTokenSpot(K, Loc))
			continue;
		if (Left(U, 3) != "SC_")
			continue;
		Token = SpawnAPWorldAt(Loc, U);
		if (Token == None)
			continue;
		EnsureCheckGlow(Token);
		RememberUnique(SeenU, U);
	}
}

function bool IsGreyToken(string U)
{
	local string Needle;
	local int i, n;

	if (U == "")
		return false;
	Needle = "|"$Caps(U)$"|";
	if (GreyBlob != "" && InStr(GreyBlob, Needle) != -1)
		return true;
	n = GreyBlobs.Length;
	if (n > RecBlobPartCap)
		n = RecBlobPartCap;
	for (i = 0; i < n; i++)
		if (InStr(GreyBlobs[i], Needle) != -1)
			return true;
	return false;
}

function DropTravelledGreyList()
{
	local APGameState GS;

	GS = APState();
	if (GS == None)
		return;
	GS.GreyBlob = "";
	GS.GreyBlobs.Length = 0;
}

function ClearGreyTokens()
{
	GreyBlob = "|";
	GreyBlobs.Length = 0;
	DropTravelledGreyList();
}

function AddGreyToken(string U)
{
	local int n, last;
	local string Needle, Chunk;

	if (U == "")
		return;
	if (IsGreyToken(U))
		return;
	U = Caps(U);
	Needle = "|"$U$"|";
	if (GreyBlob == "")
		GreyBlob = "|";
	if (Len(GreyBlob) + Len(U) + 1 < RecBlobLenCap)
		GreyBlob = GreyBlob $ U $ "|";
	n = GreyBlobs.Length;
	if (n > RecBlobPartCap)
	{
		GreyBlobs.Length = RecBlobPartCap;
		n = RecBlobPartCap;
	}
	if (n <= 0)
	{
		GreyBlobs[0] = Needle;
		return;
	}
	last = n - 1;
	Chunk = GreyBlobs[last];
	if (Chunk == "")
	{
		GreyBlobs[last] = Needle;
		return;
	}
	if (Len(Chunk) + Len(U) + 1 < RecBlobLenCap)
	{
		if (Right(Chunk, 1) != "|")
			Chunk = Chunk$"|";
		GreyBlobs[last] = Chunk$U$"|";
		return;
	}
	if (n >= RecBlobPartCap)
		return;
	GreyBlobs[n] = Needle;
}

function string TokenUniqueOf(Pickup Item)
{
	if (Item == None)
		return "";
	if (APWorldPickup(Item) != None && APWorldPickup(Item).APUnique != "")
		return APWorldPickup(Item).APUnique;
	return UniqueForPickup(Item);
}

function StyleCheckGlow(APCheckGlow Glow, Pickup Item)
{
	if (Glow == None)
		return;
	Glow.SetGreyMode(IsGreyToken(TokenUniqueOf(Item)));
}

function RefreshTokenLooks(optional bool bKeepGlowTimer)
{
	local APWorldPickup Token;
	local Pickup Item;
	local int N;

	ForceAPLogoFlags();
	foreach DynamicActors(class'APWorldPickup', Token)
	{
		if (Token == None || Token.bDeleteMe)
			continue;
		DressAPToken(Token);
		EnsureCheckGlow(Token);
		N++;
		if (N > 40)
			break;
	}
	N = 0;
	foreach DynamicActors(class'Pickup', Item)
	{
		if (Item == None || Item.bDeleteMe || APWorldPickup(Item) != None)
			continue;
		if (!IsAPToken(Item))
			continue;
		DressAPToken(Item);
		EnsureCheckGlow(Item);
		N++;
		if (N > 40)
			break;
	}
	if (!bKeepGlowTimer)
		NextGlowUpdate = 0;
}

function APTokenSprite ReuseOrSpawnTokenSprite(Pickup Item)
{
	local APTokenSprite S, Keep;
	local array<APTokenSprite> Extra;
	local int i;

	if (Item == None)
		return None;
	Keep = None;
	foreach DynamicActors(class'APTokenSprite', S)
	{
		if (S == None || S.bDeleteMe)
			continue;
		if (S.Target != Item && S.Owner != Item && S.Base != Item)
			continue;
		if (Keep == None)
			Keep = S;
		else
		{
			i = Extra.Length;
			Extra.Length = i + 1;
			Extra[i] = S;
		}
	}
	for (i = 0; i < Extra.Length; i++)
	{
		if (Extra[i] != None)
			Extra[i].Destroy();
	}
	if (Keep == None)
		Keep = Spawn(class'APTokenSprite', Item,, Item.Location);
	if (Keep != None)
		Keep.AttachToPickup(Item);
	return Keep;
}

function DressAPToken(Pickup Item)
{
	local APTokenSprite S;
	local string U;
	local Texture Logo;

	if (Item == None)
		return;

	Item.SetStaticMesh(None);
	Item.SetDrawType(DT_None);
	Item.bUnlit = true;
	Item.bDynamicLight = false;
	Item.LightType = LT_None;
	Item.bAcceptsProjectors = false;
	Item.SetDrawScale3D(vect(1,1,1));
	Item.SetCollision(true, false, false);
	Item.SetCollisionSize(34, 36);
	if (P2PowerupPickup(Item) != None)
		P2PowerupPickup(Item).bOKToGrab = true;
	Item.SetPhysics(PHYS_None);
	if (APWorldPickup(Item) != None)
		APWorldPickup(Item).PrepForGrabbing();

	S = ReuseOrSpawnTokenSprite(Item);
	if (S != None)
	{
		if (APWorldPickup(Item) != None)
			U = APWorldPickup(Item).APUnique;
		if (U == "")
			U = UniqueForPickup(Item);
		Logo = Texture'Archipelago.APLogo';
		if (IsGreyToken(U))
			Logo = Texture'Archipelago.APLogoGrey';
		S.Texture = Logo;
		S.Style = STY_Masked;
		S.bUnlit = true;
		S.bAcceptsProjectors = false;
		S.AmbientGlow = 255;
		S.SetDrawScale(class'APTokenSprite'.default.DrawScale);
	}
}



function ConsumeAPToken(Pickup Item)
{
	local APTokenSprite S;
	local APWorldPickup Token;
	local Pickup Src;
	local APCheckGlow Glow;

	if (Item == None || Item.bDeleteMe)
		return;
	S = FindTokenSprite(Item);
	if (S != None)
		S.Destroy();
	foreach DynamicActors(class'APCheckGlow', Glow)
		if (Glow.Target == Item)
			Glow.Destroy();
	Token = APWorldPickup(Item);
	if (TheGameState != None)
	{
		if (Token != None && Token.SourceName != '')
			TheGameState.RecordPickup(Token.SourceName);
		else if (P2WeaponPickup(Item) != None)
		{
			if (P2WeaponPickup(Item).bRecordAfterPickup)
				TheGameState.RecordPickup(Item.Name);
		}
		else if (P2PowerupPickup(Item) != None)
		{
			if (P2PowerupPickup(Item).bRecordAfterPickup)
				TheGameState.RecordPickup(Item.Name);
		}
	}
	if (Token != None && Token.SourceName != '')
	{
		foreach AllActors(class'Pickup', Src)
		{
			if (Src != None && Src != Item && Src.Name == Token.SourceName)
			{
				Src.Destroy();
				break;
			}
		}
	}
	Item.Destroy();
}

function MaybePlayAreaTokensDone()
{
	local string K;
	local APGameState GS;

	K = MapKey();
	if (K ~= "HOMEATNIGHT" || K ~= "INTRO")
		K = "SUBURBS-3";
	if (K == "" || K ~= "INTRO")
		return;
	if (!IsMapTokenOpen(K))
		return;
	if (CountAreaTokens(K) != 0)
		return;
	GS = APState();
	if (GS == None)
		return;
	if (GS.HasAreaTokenVO(K))
		return;
	GS.RecordAreaTokenVO(K);
	PlayAreaTokensDoneVO();
}

function PlayAreaTokensDoneVO()
{
	local P2Player P;
	local Pawn Dude;
	local sound S;
	local int i;
	local string Path;

	P = GetPlayer();
	if (P == None || P.Pawn == None)
		return;
	Dude = P.Pawn;
	i = Rand(7);
	if (i == 0)
		Path = "DudeDialog.dude_map_anddone";
	else if (i == 1)
		Path = "DudeDialog.dude_map_missionaccom";
	else if (i == 2)
		Path = "DudeDialog.dude_map_tooeasy";
	else if (i == 3)
		Path = "DudeDialog.dude_map_closeenough";
	else if (i == 4)
		Path = "DudeDialog.dude_map_donebitch";
	else if (i == 5)
		Path = "DudeDialog.dude_map_next";
	else
		Path = "DudeDialog.dude_map_anotherone";
	S = Sound(DynamicLoadObject(Path, class'Sound'));
	if (S != None)
		Dude.PlaySound(S, SLOT_Talk, 1.0,,,,, false);
}

function MaybePickupCheck(Pickup Item)
{
	local string U;

	U = UniqueForPickup(Item);
	if (U != "")
		SendCheck(U);
}

function EnsureCheckGlow(Pickup Item)
{
	local APCheckGlow Glow;

	if (Item == None)
		return;
	if (!TokenGlowEnabled())
		return;
	foreach DynamicActors(class'APCheckGlow', Glow)
	{
		if (Glow.Target == Item)
		{
			StyleCheckGlow(Glow, Item);
			return;
		}
	}
	Glow = Spawn(class'APCheckGlow', Item,, Item.Location);
	if (Glow != None)
	{
		Glow.AttachToPickup(Item);
		StyleCheckGlow(Glow, Item);
	}
}

function EnsureActorGlow(Actor A)
{
	local APCheckGlow Glow;

	if (A == None)
		return;
	if (!TokenGlowEnabled() && !TokenBeepEnabled())
		return;
	foreach DynamicActors(class'APCheckGlow', Glow)
	{
		if (Glow.Target == A)
			return;
	}
	Glow = Spawn(class'APCheckGlow', A,, A.Location);
	if (Glow != None)
		Glow.AttachToActor(A);
}

function bool ColaHasCheck(CrackolaTrigger Cola)
{
	local string U;

	if (Cola == None || ColaCap(MapKey()) <= 0)
		return false;
	U = ColaUnique(Cola);
	return U != "" && !HasRecordedCheck(U);
}

function bool ATMHasCheck(ATMTrigger ATM)
{
	local string U;

	if (ATM == None || CrackolaTrigger(ATM) != None)
		return false;
	U = ATMUnique(ATM);
	return U != "" && !HasRecordedCheck(U);
}

function bool VendorHasCheck(P2EVendingMachineTrigger V)
{
	local string U;
	local int S, j, Slot;

	if (V == None || VendorCap(MapKey()) <= 0)
		return false;
	S = NamedActorSlot(V, class'P2EVendingMachineTrigger', VendorCap(MapKey()));
	if (S <= 0)
		return false;
	for (j = 1; j <= VendorBuySlots(); j++)
	{
		Slot = (S - 1) * VendorBuyStride() + j;
		U = "VBUY_"$MapKey()$"_"$TwoDigit(Slot);
		if (!HasRecordedCheck(U))
			return true;
	}
	U = VendorUseUnique(V);
	return (U != "" && !HasRecordedCheck(U));
}

function bool ActorStillHasCheck(Actor A)
{
	if (A == None)
		return false;
	if (CrackolaTrigger(A) != None)
		return ColaHasCheck(CrackolaTrigger(A));
	if (ATMTrigger(A) != None)
		return ATMHasCheck(ATMTrigger(A));
	if (P2EVendingMachineTrigger(A) != None)
		return VendorHasCheck(P2EVendingMachineTrigger(A));
	return false;
}

function SyncMachineGlows()
{
	local ATMTrigger ATM;
	local CrackolaTrigger Cola;
	local P2EVendingMachineTrigger V;
	local APCheckGlow Glow, Kill[24];
	local int N, i;

	if (MapKey() ~= "INTRO")
		return;
	if (Level.TimeSeconds < NextMachineGlowUpdate)
		return;
	NextMachineGlowUpdate = Level.TimeSeconds + 2.0;
	if (!TokenGlowEnabled() && !TokenBeepEnabled())
	{
		foreach DynamicActors(class'APCheckGlow', Glow)
			if (Glow != None && Pickup(Glow.Target) == None && N < 24)
			{
				Kill[N] = Glow;
				N++;
			}
		for (i = 0; i < N; i++)
			if (Kill[i] != None)
				Kill[i].Destroy();
		return;
	}

	foreach AllActors(class'CrackolaTrigger', Cola)
		if (ColaHasCheck(Cola))
			EnsureActorGlow(Cola);
	foreach AllActors(class'ATMTrigger', ATM)
		if (ATMHasCheck(ATM))
			EnsureActorGlow(ATM);
	foreach AllActors(class'P2EVendingMachineTrigger', V)
		if (VendorHasCheck(V))
			EnsureActorGlow(V);

	N = 0;
	foreach DynamicActors(class'APCheckGlow', Glow)
	{
		if (Glow == None || Pickup(Glow.Target) != None)
			continue;
		if (Glow.Target == None || Glow.Target.bDeleteMe || !ActorStillHasCheck(Glow.Target))
		{
			if (N < 24)
			{
				Kill[N] = Glow;
				N++;
			}
		}
	}
	for (i = 0; i < N; i++)
		if (Kill[i] != None)
			Kill[i].Destroy();
}

function UpdateCheckGlows()
{
	local Pickup Item, Chosen[32];
	local string U, ChosenU[32];
	local APCheckGlow Glow;
	local int i, j, Iter, ChosenN, Slot;

	if (MapKey() ~= "INTRO")
	{
		StripUnplayableMapTokens();
		NextGlowUpdate = Level.TimeSeconds + 10.0;
		return;
	}
	if (Level.TimeSeconds < NextGlowUpdate)
		return;
	if (!IsMapTokenOpen())
	{
		NextGlowUpdate = Level.TimeSeconds + 10.0;
		return;
	}

	RemoveCollectedWorldPickups();
	if (!bCheckedSyncReady)
	{
		if (LastCatchUpTime > 0 && Level.TimeSeconds < LastCatchUpTime + 20.0)
		{
			NextGlowUpdate = Level.TimeSeconds + 0.25;
			return;
		}
		bCheckedSyncReady = true;
	}
	NextGlowUpdate = Level.TimeSeconds + 10.0;
	if (!TokenGlowEnabled())
		StripPickupGlows();

	foreach AllActors(class'Pickup', Item)
	{
		if (IsErrandWorldPickup(Item) && IsAPToken(Item))
			RestoreErrandPickup(Item);
	}

	ChosenN = 0;
	foreach AllActors(class'Pickup', Item)
	{
		Iter++;
		if (Iter > 400)
			break;
		if (IsErrandWorldPickup(Item))
			continue;
		U = UniqueForPickup(Item);
		if (U == "" || HasRecordedCheck(U) || IsErrandCheck(U))
			continue;
		if (IsAPToken(Item))
			continue;
		if (P2WeaponPickupErrand(Item) != None)
			continue;
		if (P2PowerupPickup(Item) != None && P2PowerupPickup(Item).bUseForErrands)
			continue;
		Slot = -1;
		for (j = 0; j < ChosenN; j++)
			if (ChosenU[j] ~= U)
			{
				Slot = j;
				break;
			}
		if (Slot == -1)
		{
			if (ChosenN >= 32)
				continue;
			ChosenU[ChosenN] = U;
			Chosen[ChosenN] = Item;
			ChosenN++;
		}
		else if (!PickupHasHeadroom(Chosen[Slot]) && PickupHasHeadroom(Item))
			Chosen[Slot] = Item;
	}
	for (i = 0; i < ChosenN; i++)
	{
		if (Chosen[i] == None)
			continue;
		Item = ConvertToAPToken(Chosen[i]);
		if (Item != None)
			EnsureCheckGlow(Item);
	}
	SpawnMissingCatalogTokens();
	RefreshTokenLooks(true);
	foreach DynamicActors(class'APCheckGlow', Glow)
	{
		if (Glow.Target == None || Glow.Target.bDeleteMe)
		{
			Glow.Destroy();
			continue;
		}
		if (Pickup(Glow.Target) == None)
			continue;
		U = UniqueForPickup(Pickup(Glow.Target));
		if (U == "" || HasRecordedCheck(U))
			Glow.Destroy();
	}
}

function int VendorBuyStride()
{
	return 5;
}

function int VendorBuySlotsFor(string K)
{
	local APGameState GS;
	local int N;

	GS = APState();
	if (GS != None && GS.bGotOptions && !GS.bVendingSanity)
		return 0;
	N = 3;
	if (GS != None)
	{
		if (K ~= "GREENBELT1")
			N = GS.VBuyGB;
		else if (K ~= "RWSBLOCK")
			N = GS.VBuyRWS;
		else if (K ~= "EASTMALL")
			N = GS.VBuyEM;
		else if (K ~= "SUBURBS-4")
			N = GS.VBuySE;
		else
			return 0;
	}
	if (N < 0)
		N = 0;
	if (N > 5)
		N = 5;
	return N;
}

function int VendorBuySlots()
{
	return VendorBuySlotsFor(MapKey());
}

function bool IsVendorMap(string K)
{
	if (K ~= "GREENBELT1") return true;
	if (K ~= "RWSBLOCK") return true;
	if (K ~= "EASTMALL") return true;
	if (K ~= "SUBURBS-4") return true;
	return false;
}

function int VendorCap(string K)
{
	local APGameState GS;
	GS = APState();
	if (GS != None && GS.bGotOptions && !GS.bVendingSanity)
		return 0;
	if (IsVendorMap(K))
		return 1;
	return 0;
}

function int ATMCap(string K)
{
	local APGameState GS;
	GS = APState();
	if (GS != None && GS.bGotOptions && !GS.bATMSanity)
		return 0;
	if (K ~= "EASTMALL") return 2;
	if (K ~= "GREENBELT1") return 1;
	if (K ~= "WESTMALL") return 1;
	if (K ~= "SUBURBS-1") return 1;
	if (K ~= "SUBURBS-2") return 1;
	if (K ~= "SUBURBS-3") return 1;
	return 0;
}

function string ATMUnique(ATMTrigger ATM)
{
	local ATMTrigger A, List[8], Tmp;
	local int i, j, N, Cap, Slot;
	local string Ni, Nj;

	Cap = ATMCap(MapKey());
	if (ATM == None || Cap <= 0 || CrackolaTrigger(ATM) != None)
		return "";
	foreach AllActors(class'ATMTrigger', A)
	{
		if (CrackolaTrigger(A) != None)
			continue;
		if (N >= 8)
			break;
		List[N] = A;
		N++;
	}
	for (i = 0; i < N; i++)
	{
		for (j = i + 1; j < N; j++)
		{
			Ni = Caps(string(List[i].Name));
			Nj = Caps(string(List[j].Name));
			if (Nj < Ni)
			{
				Tmp = List[i];
				List[i] = List[j];
				List[j] = Tmp;
			}
		}
	}
	if (N > Cap)
		N = Cap;
	for (i = 0; i < N; i++)
		if (List[i] == ATM)
			return "ATM_"$MapKey()$"_"$string(i + 1);
	return "";
}

function int ColaCap(string K)
{
	local APGameState GS;
	GS = APState();
	if (GS != None && GS.bGotOptions && !GS.bCrackolaSanity)
		return 0;
	if (K ~= "EASTMALL") return 1;
	if (K ~= "GREENBELT1") return 1;
	if (K ~= "RWSBLOCK") return 1;
	if (K ~= "POLICE") return 1;
	if (K ~= "WESTMALL") return 1;
	if (K ~= "SUBURBS-3") return 1;
	if (K ~= "PARCELCENTER") return 1;
	return 0;
}

function bool AreaColaDone(string K)
{
	local int Cap, i;

	Cap = ColaCap(K);
	if (Cap <= 0)
		return false;
	for (i = 1; i <= Cap; i++)
		if (!HasRecordedCheck("COLA_"$K$"_"$TwoDigit(i)))
			return false;
	return true;
}

function bool AreaATMDone(string K)
{
	local int Cap, i;

	Cap = ATMCap(K);
	if (Cap <= 0)
		return false;
	for (i = 1; i <= Cap; i++)
		if (!HasRecordedCheck("ATM_"$K$"_"$string(i)))
			return false;
	return true;
}

function bool AreaVendDone(string K)
{
	local int Cap, i, j, Slot, Buys;

	Cap = VendorCap(K);
	if (Cap <= 0)
		return false;
	Buys = VendorBuySlotsFor(K);
	for (i = 1; i <= Cap; i++)
	{
		if (!HasRecordedCheck("VUSE_"$K$"_"$TwoDigit(i)))
			return false;
		for (j = 1; j <= Buys; j++)
		{
			Slot = (i - 1) * VendorBuyStride() + j;
			if (!HasRecordedCheck("VBUY_"$K$"_"$TwoDigit(Slot)))
				return false;
		}
	}
	return true;
}

function int NamedActorSlot(Actor Me, class<Actor> BaseClass, int Cap)
{
	local Actor A, List[8], Tmp;
	local int i, j, N;
	local string Ni, Nj;

	if (Me == None || Cap <= 0)
		return 0;
	foreach AllActors(BaseClass, A)
	{
		if (N >= 8)
			break;
		List[N] = A;
		N++;
	}
	for (i = 0; i < N; i++)
	{
		for (j = i + 1; j < N; j++)
		{
			Ni = Caps(string(List[i].Name));
			Nj = Caps(string(List[j].Name));
			if (Nj < Ni)
			{
				Tmp = List[i];
				List[i] = List[j];
				List[j] = Tmp;
			}
		}
	}
	if (N > Cap)
		N = Cap;
	for (i = 0; i < N; i++)
		if (List[i] == Me)
			return i + 1;
	return 0;
}

function string VendorUseUnique(P2EVendingMachineTrigger V)
{
	local int S;
	S = NamedActorSlot(V, class'P2EVendingMachineTrigger', VendorCap(MapKey()));
	if (S <= 0)
		return "";
	return "VUSE_"$MapKey()$"_"$TwoDigit(S);
}

function string VendorBuyUnique(P2EVendingMachineTrigger V)
{
	local int S, j, Slot;
	local string U;

	S = NamedActorSlot(V, class'P2EVendingMachineTrigger', VendorCap(MapKey()));
	if (S <= 0)
		return "";
	for (j = 1; j <= VendorBuySlots(); j++)
	{
		Slot = (S - 1) * VendorBuyStride() + j;
		U = "VBUY_"$MapKey()$"_"$TwoDigit(Slot);
		if (!HasRecordedCheck(U))
			return U;
	}
	return "";
}

function string VendorBuyUniqueNear(vector Loc)
{
	local P2EVendingMachineTrigger V, Best;
	local float Dist, BestDist;

	BestDist = 500;
	foreach AllActors(class'P2EVendingMachineTrigger', V)
	{
		Dist = VSize(V.Location - Loc);
		if (Dist < BestDist)
		{
			BestDist = Dist;
			Best = V;
		}
	}
	if (Best == None)
		return "";
	return VendorBuyUnique(Best);
}

function int APShopSlotIndex(Pickup Item)
{
	if (APShopPickup5(Item) != None)
		return 5;
	if (APShopPickup4(Item) != None)
		return 4;
	if (APShopPickup3(Item) != None)
		return 3;
	if (APShopPickup2(Item) != None)
		return 2;
	if (APShopPickup1(Item) != None)
		return 1;
	return 0;
}

function class<Pickup> APShopPickupClass(int j)
{
	if (j == 1)
		return class'APShopPickup1';
	if (j == 2)
		return class'APShopPickup2';
	if (j == 3)
		return class'APShopPickup3';
	if (j == 4)
		return class'APShopPickup4';
	return class'APShopPickup5';
}

function string VendorBuyUniqueForPickup(Pickup Item)
{
	local P2EVendingMachineTrigger V, Best;
	local float Dist, BestDist;
	local int S, j, Slot;

	j = APShopSlotIndex(Item);
	if (j <= 0)
		return VendorBuyUniqueNear(Item.Location);
	BestDist = 600;
	foreach AllActors(class'P2EVendingMachineTrigger', V)
	{
		Dist = VSize(V.Location - Item.Location);
		if (Dist < BestDist)
		{
			BestDist = Dist;
			Best = V;
		}
	}
	if (Best == None)
		return "";
	S = NamedActorSlot(Best, class'P2EVendingMachineTrigger', VendorCap(MapKey()));
	if (S <= 0)
		S = 1;
	Slot = (S - 1) * VendorBuyStride() + j;
	return "VBUY_"$MapKey()$"_"$TwoDigit(Slot);
}

function string ColaUnique(CrackolaTrigger C)
{
	local int S;
	S = NamedActorSlot(C, class'CrackolaTrigger', ColaCap(MapKey()));
	if (S <= 0)
		return "COLA_"$MapKey()$"_01";
	return "COLA_"$MapKey()$"_"$TwoDigit(S);
}

function string ColaUniqueNear(vector Loc)
{
	local CrackolaTrigger C, Best;
	local float Dist, BestDist;

	BestDist = 600;
	foreach AllActors(class'CrackolaTrigger', C)
	{
		Dist = VSize(C.Location - Loc);
		if (Dist < BestDist)
		{
			BestDist = Dist;
			Best = C;
		}
	}
	if (Best != None)
		return ColaUnique(Best);
	if (ColaCap(MapKey()) > 0)
		return "COLA_"$MapKey()$"_01";
	return "";
}

function int VendorAPCount(P2EVendingMachineTrigger V)
{
	local int i, N;
	if (V == None)
		return 0;
	for (i = 0; i < V.ItemList.Length; i++)
		if (ClassIsChildOf(V.ItemList[i].ItemPickup, class'APShopPickup'))
			N++;
	return N;
}

function string VendorHintName(string U)
{
	local int i;
	for (i = 0; i < VHintCount; i++)
		if (VHintU[i] ~= U)
			return VHintN[i];
	return "Archipelago Check";
}

function int VendorHintPrice(string U)
{
	local int i;
	for (i = 0; i < VHintCount; i++)
		if (VHintU[i] ~= U && VHintP[i] > 0)
			return VHintP[i];
	return UniqueHashPrice(U, 0);
}

function int UniqueHashPrice(string U, int Flags)
{
	local int h, i, c, high, n;

	h = 5381;
	for (i = 0; i < Len(U); i++)
	{
		c = Asc(Mid(U, i, 1));
		h = h * 33 + c;
	}
	if (h < 0)
		h = -h;
	high = (h / 65536) % 2;
	n = h % 65536;
	if (n < 0)
		n = -n;
	if ((Flags & 1) != 0)
	{
		if (high != 0)
			return 260 + (n % 191);
		return 150 + (n % 91);
	}
	if ((Flags & 4) != 0)
	{
		if (high != 0)
			return 28 + (n % 33);
		return 8 + (n % 18);
	}
	if ((Flags & 2) != 0)
	{
		if (high != 0)
			return 85 + (n % 66);
		return 35 + (n % 46);
	}
	if (high != 0)
		return 25 + (n % 36);
	return 5 + (n % 16);
}

function string VendorHintKind(string U)
{
	local int i, F;
	for (i = 0; i < VHintCount; i++)
	{
		if (VHintU[i] ~= U)
		{
			F = VHintF[i];
			if ((F & 1) != 0)
				return "Progression";
			if ((F & 4) != 0)
				return "Trap";
			if ((F & 2) != 0)
				return "Useful";
			return "Filler";
		}
	}
	return "Unknown";
}

function SetVendorHint(string U, int Flags, int Price, string N)
{
	local int i;
	if (U == "")
		return;
	for (i = 0; i < VHintCount; i++)
	{
		if (VHintU[i] ~= U)
		{
			VHintN[i] = N;
			VHintF[i] = Flags;
			VHintP[i] = Price;
			bVendorDirty = true;
			return;
		}
	}
	if (VHintCount >= 32)
		return;
	VHintU[VHintCount] = U;
	VHintN[VHintCount] = N;
	VHintF[VHintCount] = Flags;
	VHintP[VHintCount] = Price;
	VHintCount++;
	bVendorDirty = true;
}

function FilterLockedVendorWeapons(P2EVendingMachineTrigger V)
{
	local int i;
	local class<Pickup> PC;
	local class<Inventory> IC;
	local class<Ammunition> AC;

	if (V == None || !ShuffleWeaponsOn())
		return;
	for (i = V.ItemList.Length - 1; i >= 0; i--)
	{
		PC = V.ItemList[i].ItemPickup;
		if (PC == None && V.ItemList[i].ItemPickupName != "")
		{
			PC = class<Pickup>(DynamicLoadObject(V.ItemList[i].ItemPickupName, class'Class'));
			V.ItemList[i].ItemPickup = PC;
		}
		if (PC == None || ClassIsChildOf(PC, class'APShopPickup'))
			continue;
		if (ClassIsChildOf(PC, class'P2WeaponPickup') || ClassIsChildOf(PC, class'WeaponPickup'))
		{
			IC = PC.default.InventoryType;
			if (IsWeaponAllowed(IC))
				continue;
			AC = WeaponAmmoClass(IC);
			if (AC != None && UnlockedWeaponUsesAmmo(AC))
				continue;
			V.ItemList.Remove(i, 1);
			continue;
		}
		if (ClassIsChildOf(PC, class'P2AmmoPickup') || ClassIsChildOf(PC, class'Ammo'))
		{
			AC = class<Ammunition>(PC.default.InventoryType);
			if (AC != None && UnlockedWeaponUsesAmmo(AC))
				continue;
			V.ItemList.Remove(i, 1);
		}
	}
}

function StripVendorAPItems(P2EVendingMachineTrigger V)
{
	local int i;

	if (V == None)
		return;
	for (i = V.ItemList.Length - 1; i >= 0; i--)
		if (ClassIsChildOf(V.ItemList[i].ItemPickup, class'APShopPickup')
			|| ClassIsChildOf(V.ItemList[i].ItemPickup, class'APRepairPickup')
			|| ClassIsChildOf(V.ItemList[i].ItemPickup, class'APHintFlarePickup')
			|| ClassIsChildOf(V.ItemList[i].ItemPickup, class'APWaterBottlePickup'))
			V.ItemList.Remove(i, 1);
}

function P2EVendingMachineTrigger.Item MakeVendorRepairItem()
{
	local P2EVendingMachineTrigger.Item Shop;
	local P2EVendingMachineTrigger.ExchangeRate Buy;

	Shop.ItemPickup = class'Archipelago.APRepairPickup';
	Shop.ItemPickupName = "Archipelago.APRepairPickup";
	Shop.ItemName = "Weapon Repair Kit";
	Shop.ItemDescription = "Restores your equipped melee weapon to full durability. $50.";
	Shop.ItemIcon = Texture'Archipelago.APRepair';
	Buy.ItemPrice = 50;
	Buy.ItemAmount = 1;
	Buy.PriceIncreasePerDay = 0;
	Shop.ItemBuyRate = Buy;
	Shop.QuantityAvailable = 0;
	return Shop;
}

function P2EVendingMachineTrigger.Item MakeVendorHintFlareItem()
{
	local P2EVendingMachineTrigger.Item Shop;
	local P2EVendingMachineTrigger.ExchangeRate Buy;

	Shop.ItemPickup = class'Archipelago.APHintFlarePickup';
	Shop.ItemPickupName = "Archipelago.APHintFlarePickup";
	Shop.ItemName = "Hint Flare";
	Shop.ItemDescription = "Fires a flare rocket from every AP token on this map. $30.";
	Shop.ItemIcon = Texture'Archipelago.APHintFlare';
	Buy.ItemPrice = 30;
	Buy.ItemAmount = 1;
	Buy.PriceIncreasePerDay = 0;
	Shop.ItemBuyRate = Buy;
	Shop.QuantityAvailable = 0;
	return Shop;
}

function P2EVendingMachineTrigger.Item MakeVendorWaterItem()
{
	local P2EVendingMachineTrigger.Item Shop;
	local P2EVendingMachineTrigger.ExchangeRate Buy;

	Shop.ItemPickup = class'Archipelago.APWaterBottlePickup';
	Shop.ItemPickupName = "Archipelago.APWaterBottlePickup";
	Shop.ItemName = "Water Bottle";
	Shop.ItemDescription = "Chug to fill your bladder by 5. $5.";
	Shop.ItemIcon = Texture'Archipelago.APWaterBottle';
	Buy.ItemPrice = 5;
	Buy.ItemAmount = 1;
	Buy.PriceIncreasePerDay = 0;
	Shop.ItemBuyRate = Buy;
	Shop.QuantityAvailable = 0;
	return Shop;
}

function EnsureVendorItemDisplay(P2EVendingMachineTrigger V)
{
	local int i;
	local class<Pickup> PC;
	local string Path;

	if (V == None)
		return;
	for (i = 0; i < V.ItemList.Length; i++)
	{
		if (V.ItemList[i].ItemPickup == None)
		{
			Path = V.ItemList[i].ItemPickupName;
			if (Path != "" && InStr(Path, ".") != -1)
			{
				PC = class<Pickup>(DynamicLoadObject(Path, class'Class'));
				if (PC != None)
					V.ItemList[i].ItemPickup = PC;
			}
		}
		PC = V.ItemList[i].ItemPickup;
		if (V.ItemList[i].ItemName == "" && PC != None && PC.default.InventoryType != None
			&& PC.default.InventoryType.default.ItemName != "")
			V.ItemList[i].ItemName = PC.default.InventoryType.default.ItemName;
		if (V.ItemList[i].ItemIcon == None && PC != None && PC.default.InventoryType != None)
			V.ItemList[i].ItemIcon = Texture(PC.default.InventoryType.default.Texture);
	}
}

function P2EVendingMachineTrigger.Item MakeVendorAPItem(string U, int j, int Price)
{
	local P2EVendingMachineTrigger.Item Shop;
	local P2EVendingMachineTrigger.ExchangeRate Buy;
	local string Disp, Kind;

	Disp = VendorHintName(U);
	Kind = VendorHintKind(U);
	if (Disp == "")
		Disp = "Archipelago Check";
	Shop.ItemPickup = APShopPickupClass(j);
	Shop.ItemPickupName = U;
	if (!(Kind ~= "Unknown"))
		Shop.ItemName = Disp$" ("$Kind$")";
	else
		Shop.ItemName = Disp;
	Shop.ItemDescription = Kind$" multiworld item. Price $"$string(Price)$".";
	Shop.ItemIcon = Texture'Archipelago.APLogo';
	Buy.ItemPrice = Price;
	Buy.ItemAmount = 1;
	Buy.PriceIncreasePerDay = 0;
	Shop.ItemBuyRate = Buy;
	Shop.QuantityAvailable = 1;
	return Shop;
}

function RefreshVendorAPNames(P2EVendingMachineTrigger V)
{
	local int i, Price;
	local string U, Disp, Kind;
	local P2EVendingMachineTrigger.Item Shop;
	local P2EVendingMachineTrigger.ExchangeRate Buy;

	if (V == None)
		return;
	for (i = 0; i < V.ItemList.Length; i++)
	{
		U = V.ItemList[i].ItemPickupName;
		if (!(Left(U, 5) ~= "VBUY_"))
			continue;
		if (V.ItemList[i].ItemPickup != None
			&& !ClassIsChildOf(V.ItemList[i].ItemPickup, class'APShopPickup'))
			continue;
		Disp = VendorHintName(U);
		Kind = VendorHintKind(U);
		if (Disp == "" || Disp ~= "Archipelago Check")
			continue;
		Shop = V.ItemList[i];
		if (!(Kind ~= "Unknown"))
			Shop.ItemName = Disp$" ("$Kind$")";
		else
			Shop.ItemName = Disp;
		Price = VendorHintPrice(U);
		if (Price <= 0)
			Price = UniqueHashPrice(U, 0);
		Buy = Shop.ItemBuyRate;
		Buy.ItemPrice = Price;
		Buy.ItemAmount = 1;
		Buy.PriceIncreasePerDay = 0;
		Shop.ItemBuyRate = Buy;
		Shop.ItemDescription = Kind$" multiworld item. Price $"$string(Price)$".";
		if (Shop.ItemIcon == None)
			Shop.ItemIcon = Texture'Archipelago.APLogo';
		V.ItemList[i] = Shop;
	}
}

function InjectVendorAPItems()
{
	local P2EVendingMachineTrigger V;
	local int S, j, Slot, Price, Cap;
	local string U, K;
	local P2EVendingMachineTrigger.Item Shop;
	local bool WantWater, WantVendorStuff;

	K = MapKey();
	WantWater = PissRealismEnabled();
	WantVendorStuff = IsVendorMap(K);
	if (!WantWater && !WantVendorStuff)
		return;
	if (!bVendorDirty && LastVendorMap ~= K)
		return;
	LastVendorMap = K;
	Cap = VendorCap(K);
	foreach AllActors(class'P2EVendingMachineTrigger', V)
	{
		if (V == None)
			continue;
		V.InitializeDayItemList();
		EnsureVendorItemDisplay(V);
		FilterLockedVendorWeapons(V);
		StripVendorAPItems(V);
		if (WantVendorStuff)
		{
			S = NamedActorSlot(V, class'P2EVendingMachineTrigger', Cap);
			if (S > 0)
			{
				for (j = 1; j <= VendorBuySlotsFor(K); j++)
				{
					Slot = (S - 1) * VendorBuyStride() + j;
					U = "VBUY_"$K$"_"$TwoDigit(Slot);
					if (HasRecordedCheck(U))
						continue;
					Price = VendorHintPrice(U);
					if (Price <= 0)
						Price = UniqueHashPrice(U, 0);
					Shop = MakeVendorAPItem(U, j, Price);
					V.ItemList.Insert(V.ItemList.Length, 1);
					V.ItemList[V.ItemList.Length - 1] = Shop;
				}
			}
			if (MeleeDurabilityEnabled())
			{
				Shop = MakeVendorRepairItem();
				V.ItemList.Insert(V.ItemList.Length, 1);
				V.ItemList[V.ItemList.Length - 1] = Shop;
			}
			Shop = MakeVendorHintFlareItem();
			V.ItemList.Insert(V.ItemList.Length, 1);
			V.ItemList[V.ItemList.Length - 1] = Shop;
		}
		if (WantWater)
		{
			Shop = MakeVendorWaterItem();
			V.ItemList.Insert(V.ItemList.Length, 1);
			V.ItemList[V.ItemList.Length - 1] = Shop;
		}
	}
	bVendorDirty = false;
}

function PollVendorMenus()
{
	local P2Player P;
	local Player PL;
	local int i;
	local P2EVendingMachineInteraction VM;
	local string U;

	P = GetPlayer();
	if (P == None)
		return;
	PL = P.Player;
	if (PL == None)
		return;
	for (i = 0; i < PL.LocalInteractions.Length; i++)
	{
		VM = P2EVendingMachineInteraction(PL.LocalInteractions[i]);
		if (VM != None && VM.VMT != None)
		{
			U = VendorUseUnique(VM.VMT);
			if (U != "")
				SendCheck(U);
			RefreshVendorAPNames(VM.VMT);
			if (!VendorHasCheck(VM.VMT))
				NextMachineGlowUpdate = 0;
		}
	}
}

function PollCrackolaMachines()
{
	local CrackolaTrigger Cola;
	local CrackolaUseTrigger Use;
	local string U;

	foreach AllActors(class'CrackolaTrigger', Cola)
	{
		if (Cola != None && Cola.bTriggered)
		{
			U = ColaUnique(Cola);
			if (U != "")
				SendCheck(U);
		}
	}
	foreach AllActors(class'CrackolaUseTrigger', Use)
	{
		if (Use != None && Use.QuantityAvailable < Use.default.QuantityAvailable)
			SendCheck(ColaUniqueNear(Use.Location));
	}
}

function PollWorldChecks()
{
	local P2Pawn Dude;
	local Inventory Inv;
	local APGameState GS;

	if (IsIntroMap())
		return;
	GS = APState();
	if (bNeedStripCollected)
	{
		bNeedStripCollected = false;
		RepairRecBlobs();
		bCheckedSyncReady = true;
		NextGlowUpdate = 0;
		RemoveCollectedWorldPickups();
		ApplyGatedErrands(true);
		if (GetPlayer() != None && P2Pawn(GetPlayer().Pawn) != None)
			ReapplyUnlocks(P2Pawn(GetPlayer().Pawn));
		RestoreErrandPickupsOnMap();
	}

	if (GetPlayer() != None)
		Dude = P2Pawn(GetPlayer().Pawn);
	if (Dude != None && UrethraWeapon(Dude.Weapon) != None)
		EnsureClinicGonorrhea();
	MaybeDispenseClinicPills();
	if (Dude != None)
	{
		for (Inv = Dude.Inventory; Inv != None; Inv = Inv.Inventory)
		{
			if (Inv.IsA('GimpClothesInv'))
				SendCheck("BreweryGimp");
		}
	}

	ApplyWarpLockGimp();
	TickKeepGimp();
	UpdateCheckGlows();
	MaybePlaceMilk();
	InjectVendorAPItems();
	PollVendorMenus();
	PollCrackolaMachines();
	PollATMMachines();
	SyncMachineGlows();
	ApplyAreaLocks();
	MaybeNudgeDayGate();
	ReportMapEntry();
	AnnounceMapPickups();
	TickCatRainTrap();
	TickPissTrap();
}

function TickCatRainTrap()
{
	local P2Player p2p;
	local CatRocket catr;
	local vector dir, StartLoc;
	local float tempf;

	if (Level.TimeSeconds > APCatRainUntil)
		return;
	if (Level.Pauser != None)
		return;
	if (Level.TimeSeconds < APNextCat)
		return;

	p2p = GetPlayer();
	if (p2p == None || p2p.MyPawn == None)
		return;

	APNextCat = Level.TimeSeconds + 1.0 + FRand() * 2.0;
	StartLoc = vector(p2p.MyPawn.Rotation);
	StartLoc.z = 0;
	StartLoc = (FRand() * 4000 + 200) * StartLoc;
	tempf = 750;
	StartLoc.x = StartLoc.x + (FRand() * 1500 - tempf);
	StartLoc.y = StartLoc.y + (FRand() * 1500 - tempf);
	StartLoc.z += 3000;
	StartLoc = StartLoc + p2p.MyPawn.Location;
	dir = VRand();
	dir.z = -1;
	catr = spawn(class'CatRocket',,, StartLoc, Rotator(dir));
	if (catr != None)
	{
		catr.AmbientGlow = 255;
		dir = vector(catr.Rotation);
		catr.Velocity = 100 * dir;
		catr.Acceleration.z = -1200;
	}
}

function NeededForThisDay(Actor CheckA, out byte Needed, out byte SpecifiedDay)
{
	local int i, dayI;
	local string GroupString;
	local bool bExcluded;

	Needed = 0;
	SpecifiedDay = 0;
	if (CheckA == None || TheGameState == None)
	{
		Needed = 1;
		return;
	}
	if (ClinicVendShouldStay(CheckA))
	{
		Needed = 1;
		return;
	}
	GroupString = Caps(CheckA.Group);

	if (Days.Length > 0)
	{
		dayI = 0;
		while (dayI < Days[TheGameState.CurrentDay].ExcludeDays.Length)
		{
			i = InStr(GroupString, Days[TheGameState.CurrentDay].ExcludeDays[dayI]);
			if (i >= 0)
				bExcluded = true;
			dayI++;
		}
	}

	dayI = 0;
	while (dayI < Days.Length)
	{
		i = InStr(GroupString, Days[dayI].UniqueName);
		if (i >= 0)
		{
			SpecifiedDay = 1;
			if (TheGameState.CurrentDay == dayI)
				Needed = 1;
		}
		dayI++;
	}

	if (SpecifiedDay == 0 && !bExcluded)
		Needed = 1;
}

function PollATMMachines()
{
	local ATMTrigger ATM;
	local string U;

	foreach AllActors(class'ATMTrigger', ATM)
	{
		if (ATM == None || CrackolaTrigger(ATM) != None)
			continue;
		if (!ATM.bTriggered && !ATM.IsInState('Disabled'))
			continue;
		U = ATMUnique(ATM);
		if (U != "")
			SendCheck(U);
	}
}

function GiveAPItem(string ClassName, optional int Amount)
{
	if (ClassName == "")
		return;
	if (!TryGiveAPItem(ClassName, Amount, false))
		QueuePendingItem(ClassName);
}

function bool TryGiveAPItem(string ClassName, int Amount, bool bQuiet)
{
	local class<Inventory> InvClass;
	local P2Player P;
	local P2Pawn Dude;
	local Inventory Inv;
	local P2Weapon Weap;
	local string NiceName;
	local bool bAlreadyHad;

	if (ClassName == "")
		return true;
	if (Left(ClassName, 4) ~= "DAY:" || Left(ClassName, 5) ~= "AREA:"
		|| Left(ClassName, 7) ~= "ERRAND:" || Left(ClassName, 5) ~= "WARP:"
		|| Left(ClassName, 5) ~= "TRAP:")
		return true;

	P = GetPlayer();
	if (P == None)
	{
		if (!bQuiet)
			Warn("Archipelago: no player to give "$ClassName);
		return false;
	}

	Dude = P2Pawn(P.Pawn);
	if (Dude == None)
	{
		if (!bQuiet)
			Warn("Archipelago: no pawn to give "$ClassName);
		return false;
	}

	if (InStr(Caps(ClassName), "PISTOLWEAPON") != -1)
		InvClass = class'PistolWeapon';
	else
		InvClass = class<Inventory>(DynamicLoadObject(ClassName, class'class'));

	if (InvClass == None)
	{
		ShowAPMessage("Unknown item class: "$ClassName);
		return true;
	}

	if (ShouldKeepGimp()
		&& ClassIsChildOf(InvClass, class'ClothesInv')
		&& !ClassIsChildOf(InvClass, class'GimpClothesInv'))
		return true;

	Inv = Dude.FindInventoryType(InvClass);
	bAlreadyHad = (Inv != None);
	if (Inv == None)
		Inv = Dude.CreateInventoryByClass(InvClass);

	if (Inv == None)
	{
		if (!bQuiet)
			ShowAPMessage("Failed to give "$ClassName);
		return false;
	}

	if (Amount > 0)
	{
		if (P2PowerupInv(Inv) != None)
			P2PowerupInv(Inv).AddAmount(Amount);
		else if (P2Weapon(Inv) != None)
			P2Weapon(Inv).GiveAmmoFromPickup(Dude, Amount);
	}

	if (bAlreadyHad && bQuiet && Amount <= 0)
		return true;

	Weap = P2Weapon(Inv);
	if (Weap != None)
	{
		NiceName = Weap.ItemName;
		if (!bQuiet)
			P.ClientSetWeapon(Weap.Class);
	}
	else if (P2PowerupInv(Inv) != None)
		NiceName = P2PowerupInv(Inv).PowerupName;
	else
		NiceName = Inv.ItemName;

	if (NiceName == "" || NiceName ~= "InvItem")
		NiceName = WeaponNiceName(ClassName);
	if (NiceName == "" || NiceName ~= "InvItem")
		NiceName = InventoryNiceName(ClassName);
	if (NiceName == "")
		NiceName = ClassName;

	if (!bQuiet)
	{
		if (ClassName ~= "Inventory.MoneyInv" && Amount > 0)
			ShowAPMessage("Received $"$string(Amount));
		else if (Weap != None)
			ShowAPMessage("You learned how to use the "$NiceName$"!");
		else
			ShowAPMessage("Received "$NiceName);
	}
	SendGranted(ClassName);
	return true;
}

defaultproperties
{
	GameName="Archipelago"
	GameNameshort="Archipelago"
	GameDescription="Archipelago randomizer designed for the original Monday-Friday campaign. Requires Archipelago 0.6.6+ and the postal2.apworld, which includes the Postal 2 Client. Remember to have your Postal 2 Client open!"
	MenuTitleTex="Archipelago.APMenuLogo"
	CompanionHost="127.0.0.1"
	CompanionPort=23981
	APServer=""
	APSlot="Dude"
	APPassword=""
	GameStateClass=Class'Archipelago.APGameState'
	MapScreenClassName="Archipelago.APMapScreen"
	StatsScreenClassName="Archipelago.APStatsScreen"
	PlayerControllerClassName="Archipelago.APDudePlayer"
	HUDType="Archipelago.APHUD"
}
