///////////////////////////////////////////////////////////////////////////////
// APGameState
// Traveling save data for Archipelago unlocks. GameState is an Inventory
// that travels with the player and is written into .usa saves.
///////////////////////////////////////////////////////////////////////////////
class APGameState extends AWGameState;

var travel array<string> Unlocks;
// Do not travel. Dynamic array export overflowed into RecBlobs=( and
// sent CHECK VBUY_GREENBRecBlobs=( on map change.
var array<string> RecordedChecks;
var string RecordedBlob;
// Static slots so travel writes RecBlobs[0]=, RecBlobs[1]= each under
// 1024 chars. A dynamic RecBlobs=(...) dump overflowed ExportText.
var travel string RecBlobs[96];
var travel string APSeed;
var travel bool bAPCaughtUp;
var travel array<int> FillerApplied;
var travel array<int> TrapApplied;
var travel int ShopCrackCount;
var travel int ShopFoodCount;
var travel bool bATMSanity;
var travel bool bVendingSanity;
var travel int VBuyGB;
var travel int VBuyRWS;
var travel int VBuyEM;
var travel int VBuySE;
var travel bool bCrackolaSanity;
var travel bool bGotOptions;
var travel bool bErrandSanity;
var travel bool bClinicAlways;
var travel bool bShuffleWeapons;
var travel bool bTokenGlow;
var travel bool bTokenBeep;
var travel array<string> ATMSent;
var travel int WestMallCatnip;
var travel array<string> MapSecrets;
var travel array<string> VisitedMaps;
var travel array<string> AreaTokenVO;
var travel string FeaturedErrand[5];
var travel bool bShowMapAfterWarp;
var travel array<string> ScroungeLock;
var travel array<string> TokenMapK;
var travel array<int> TokenMapD;
var travel bool bWarpLibrary;
var travel bool bWarpBrewery;
var travel bool bWarpNapalm;
var travel bool bWarpParcel;
var travel bool bMeleeDurability;
var travel bool bPissRealism;
var travel bool bPissRealismPrimed;
var travel int PissRegen;
var travel bool bLootSanity;
// Travels so a death before the client reconnects still counts.
var travel bool bDeathLink;
var travel array<string> MeleeDurKey;
var travel array<int> MeleeDurVal;
var travel bool bGimpTrap;
var travel class<Inventory> GimpTrapPrevClothes;
var travel bool bGimpTrapHadCop;
var travel bool bKeepGimp;
var travel bool bClientGateDone;
var travel int APStartDay;
var travel bool bGotStartDay;
var travel bool bStartDayApplied;
var travel bool bNeedBreweryResync;
// Grey list is session-only on APGameInfo. These used to travel and
// Lootsanity GREY dumps made ExportText of GreyBlobs GPF on map change.
var string GreyBlob;
var array<string> GreyBlobs;

function bool HasVisitedMap(string Key)
{
	local int i;
	if (Key == "")
		return false;
	for (i = 0; i < VisitedMaps.Length && i < 64; i++)
		if (VisitedMaps[i] ~= Key)
			return true;
	return false;
}

function RecordVisitedMap(string Key)
{
	if (Key == "" || HasVisitedMap(Key))
		return;
	if (VisitedMaps.Length >= 64)
		return;
	VisitedMaps[VisitedMaps.Length] = Key;
}

function bool HasAreaTokenVO(string Key)
{
	local int i;
	if (Key == "")
		return false;
	for (i = 0; i < AreaTokenVO.Length && i < 64; i++)
		if (AreaTokenVO[i] ~= Key)
			return true;
	return false;
}

function RecordAreaTokenVO(string Key)
{
	if (Key == "" || HasAreaTokenVO(Key))
		return;
	if (AreaTokenVO.Length >= 64)
		return;
	AreaTokenVO[AreaTokenVO.Length] = Key;
}

function CompactUnlocks()
{
	local int i, j, n, w;

	if (Unlocks.Length > 128)
		Unlocks.Length = 128;
	n = Unlocks.Length;
	w = 0;
	for (i = 0; i < n; i++)
	{
		if (Unlocks[i] == "")
			continue;
		j = 0;
		while (j < w)
		{
			if (Unlocks[j] ~= Unlocks[i])
				break;
			j++;
		}
		if (j < w)
			continue;
		if (w != i)
			Unlocks[w] = Unlocks[i];
		w++;
	}
	if (w < Unlocks.Length)
		Unlocks.Length = w;
}

function bool HasUnlock(string Key)
{
	local int i;

	if (Key == "")
		return false;
	i = 0;
	while (i < 128)
	{
		if (i >= Unlocks.Length)
			return false;
		if (Unlocks[i] ~= Key)
			return true;
		i++;
	}
	return false;
}

function AddUnlock(string Key)
{
	if (Key == "")
		return;
	if (Unlocks.Length > 128)
		Unlocks.Length = 128;
	if (HasUnlock(Key))
		return;
	if (Unlocks.Length >= 128)
		return;
	Unlocks[Unlocks.Length] = Key;
}

function bool HasFiller(int Index)
{
	local int i;
	for (i = 0; i < FillerApplied.Length && i < 4000; i++)
		if (FillerApplied[i] == Index)
			return true;
	return false;
}

function RecordFiller(int Index)
{
	if (HasFiller(Index))
		return;
	if (FillerApplied.Length >= 4000)
		return;
	FillerApplied[FillerApplied.Length] = Index;
}

function bool HasTrap(int Index)
{
	local int i;
	for (i = 0; i < TrapApplied.Length && i < 200; i++)
		if (TrapApplied[i] == Index)
			return true;
	return false;
}

function RecordTrap(int Index)
{
	if (HasTrap(Index))
		return;
	if (TrapApplied.Length >= 200)
		return;
	TrapApplied[TrapApplied.Length] = Index;
}

function bool HasATM(string Key)
{
	local int i;
	for (i = 0; i < ATMSent.Length && i < 80; i++)
		if (ATMSent[i] ~= Key)
			return true;
	return false;
}

function RecordATM(string Key)
{
	if (Key == "" || HasATM(Key))
		return;
	if (ATMSent.Length >= 80)
		return;
	ATMSent[ATMSent.Length] = Key;
}

function RecordPickup(name Pname)
{
	local int i;
	local string Lname;

	if (Pname == '')
		return;
	if (GottenPickups.Length > 500)
		return;
	if (P2GameInfo(Level.Game) != None)
		Lname = P2GameInfo(Level.Game).ParseLevelName(Level.GetLocalURL());
	if (Right(Lname, 4) ~= ".fuk")
		Lname = Left(Lname, Len(Lname) - 4);
	for (i = 0; i < GottenPickups.Length && i < 400; i++)
		if (GottenPickups[i].PickupName == Pname && GottenPickups[i].LevelName ~= Lname)
			return;
	Super.RecordPickup(Pname);
}

defaultproperties
{
	bShuffleWeapons=true
	bClinicAlways=true
	VBuyGB=3
	VBuyRWS=3
	VBuyEM=3
	VBuySE=3
	bTokenGlow=true
	bTokenBeep=true
}
