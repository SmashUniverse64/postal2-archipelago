///////////////////////////////////////////////////////////////////////////////
// Weapon selector used by APDudePlayer.
//
// GameTypes.P2WeaponSelector keeps WeaponGroups on the viewport across maps.
// RefreshSelector is final and RefreshCarouselArray loops WeaponGroups.Length
// with no cap. Those arrays are protected in another package, so we cannot
// shrink them from here. APDudePlayer destroys this Interaction on travel
// and spawns a new one (Length starts at 0). NotifyLevelChanged rebuilds
// from inventory with a capped walk instead of vanilla RefreshSelector.
///////////////////////////////////////////////////////////////////////////////
class APWeaponSelector extends P2WeaponSelector;

var bool bHadNoPawn;
var Weapon DurList[24];
var int DurCount;
var int DurGroup;

function bool IsValidWeapon(Weapon W)
{
	if (HandsWeaponLeft(W) != None)
		return false;
	return Super.IsValidWeapon(W);
}

function SafeRefreshSelector()
{
	local Inventory Inv;
	local Weapon W;
	local class<Weapon> Seen[48];
	local int Count, n, i;
	local bool bDup;

	PlayerOwner = P2Player(ViewportOwner.Actor);
	if (PlayerOwner == None || PlayerOwner.Pawn == None)
	{
		ResetIndexes();
		return;
	}
	Count = 0;
	n = 0;
	for (Inv = PlayerOwner.Pawn.Inventory; Inv != None && Count < 128; Inv = Inv.Inventory)
	{
		Count++;
		W = Weapon(Inv);
		if (W == None)
			continue;
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
			continue;
		if (n < 48)
		{
			Seen[n] = W.Class;
			n++;
		}
		AddWeapon(W);
	}
	ResetIndexes();
	SetupSelector(False);
}

function NotifyLevelChanged(string OldL, string NewL)
{
	SafeRefreshSelector();
}

function Tick(float Delta)
{
	PlayerOwner = P2Player(ViewportOwner.Actor);
	if (PlayerOwner != None && PlayerOwner.Pawn != None && bHadNoPawn)
	{
		bHadNoPawn = false;
		SafeRefreshSelector();
	}
	Super.Tick(Delta);
	if (PlayerOwner == None || PlayerOwner.Pawn == None)
		bHadNoPawn = true;
}

function RebuildDurGroup(int GroupIdx)
{
	local Inventory Inv;
	local Weapon W;
	local int Groups[24], GCount, i, j, Hits, Gid, Tmp;
	local bool bHave;

	DurGroup = GroupIdx;
	DurCount = 0;
	if (PlayerOwner == None || PlayerOwner.Pawn == None)
		return;
	Hits = 0;
	GCount = 0;
	for (Inv = PlayerOwner.Pawn.Inventory; Inv != None && Hits < 128; Inv = Inv.Inventory)
	{
		Hits++;
		W = Weapon(Inv);
		if (!IsValidWeapon(W))
			continue;
		bHave = false;
		i = 0;
		while (i < GCount)
		{
			if (Groups[i] == W.InventoryGroup)
			{
				bHave = true;
				break;
			}
			i++;
		}
		if (!bHave && GCount < 24)
		{
			Groups[GCount] = W.InventoryGroup;
			GCount++;
		}
	}
	for (i = 0; i < GCount; i++)
	{
		for (j = i; j < GCount; j++)
		{
			if (Groups[i] > Groups[j])
			{
				Tmp = Groups[i];
				Groups[i] = Groups[j];
				Groups[j] = Tmp;
			}
		}
	}
	if (GroupIdx < 0 || GroupIdx >= GCount)
		return;
	Gid = Groups[GroupIdx];
	Hits = 0;
	for (Inv = PlayerOwner.Pawn.Inventory; Inv != None && Hits < 128; Inv = Inv.Inventory)
	{
		Hits++;
		W = Weapon(Inv);
		if (!IsValidWeapon(W) || W.InventoryGroup != Gid)
			continue;
		if (DurCount < 24)
		{
			DurList[DurCount] = W;
			DurCount++;
		}
	}
	for (i = 0; i < DurCount; i++)
	{
		for (j = i; j < DurCount; j++)
		{
			if (DurList[i].default.GroupOffset > DurList[j].default.GroupOffset)
			{
				W = DurList[i];
				DurList[i] = DurList[j];
				DurList[j] = W;
			}
		}
	}
}

function DrawWeaponListCell(Canvas C, vector CurPos, int GroupIdx, int ListIdx, float CanvasScale)
{
	local APGameInfo G;
	local Weapon W;
	local P2Weapon PW;
	local float AmmoPct, CellX, CellY, BarH;
	local vector BarPos;
	local int Dur;

	Super.DrawWeaponListCell(C, CurPos, GroupIdx, ListIdx, CanvasScale);
	if (PlayerOwner == None || GroupCellTex == None)
		return;
	G = APGameInfo(PlayerOwner.Level.Game);
	if (G == None || !G.MeleeDurabilityEnabled())
		return;
	if (ListIdx == 0 || DurGroup != GroupIdx)
		RebuildDurGroup(GroupIdx);
	if (ListIdx < 0 || ListIdx >= DurCount)
		return;
	W = DurList[ListIdx];
	PW = P2Weapon(W);
	if (!G.IsDurabilityMelee(PW))
		return;
	Dur = G.GetMeleeDur(PW);
	CellX = GroupCellTex.USize * GroupCellScale.X * CanvasScale;
	CellY = GroupCellTex.VSize * GroupCellScale.Y * CanvasScale;
	if (Dur <= 0 && SelectedGroupCellTex != None)
	{
		GetP2EUtils().SetPos(C, CurPos.X, CurPos.Y);
		C.DrawColor = NoAmmoWeaponColor;
		C.DrawTileClipped(SelectedGroupCellTex, CellX, CellY,
			0, 0, SelectedGroupCellTex.USize, SelectedGroupCellTex.VSize);
	}
	AmmoPct = float(Dur) / 100.0;
	if (AmmoPct < 0)
		AmmoPct = 0;
	if (AmmoPct > 1)
		AmmoPct = 1;
	BarH = CellY * AmmoBarHeightFact;
	BarPos.X = CurPos.X;
	BarPos.Y = CurPos.Y + (CellY - BarH);
	GetP2EUtils().SetPos(C, BarPos.X, BarPos.Y);
	C.DrawColor = AmmoBarBGColor;
	C.DrawTileClipped(Texture'Engine.WhiteSquareTexture', CellX, BarH, 0, 0, 16, 16);
	GetP2EUtils().SetPos(C, BarPos.X, BarPos.Y);
	C.DrawColor = AmmoBarColor;
	C.DrawTileClipped(Texture'Engine.WhiteSquareTexture', CellX * AmmoPct, BarH, 0, 0, 16, 16);
}
