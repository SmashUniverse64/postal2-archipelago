///////////////////////////////////////////////////////////////////////////////
// Thrown Time Warp. Looks like a colored AP token. After a short wait a
// Christmas-tree-style light shaft appears; pick it up to warp. If you wait
// too long the light dies and the warp cancels.
///////////////////////////////////////////////////////////////////////////////
class APTimeWarpPickup extends P2PowerupPickup;

var int WarpDay;
var string WarpURL;
var string WarpLabel;
var bool bShowMap;
var bool bArmed;
var bool bReady;
var float GlowWait;
var APTimeWarpGlow Glow;
var APTimeWarpShaft Shaft;

const GLOW_DELAY = 2.5;
const GLOW_LIFE = 10.0;

function InitDroppedPickupFor(Inventory Inv)
{
	local APTimeWarpInv Warp;
	local Texture Logo;

	Super.InitDroppedPickupFor(Inv);
	Warp = APTimeWarpInv(Inv);
	if (Warp != None)
	{
		WarpDay = Warp.PendingDay;
		WarpURL = Warp.PendingURL;
		WarpLabel = Warp.PendingLabel;
		bShowMap = Warp.bPendingShowMap;
		bArmed = Warp.bArmed;
	}
	bOKToGrab = true;
	bReady = false;
	GlowWait = 0;
	bStasis = false;
	LightType = LT_None;
	bDynamicLight = false;
	bCorona = false;
	SetStaticMesh(None);
	SetDrawType(DT_Sprite);
	Logo = Texture'Archipelago.APLogo';
	if (Logo != None)
	{
		Logo.bAlphaTexture = true;
		Logo.bMasked = true;
	}
	Texture = Logo;
	Style = STY_Masked;
	bUnlit = true;
	AmbientGlow = 255;
	SetDrawScale(0.20);
	Enable('Tick');
}

function KillGlowActors()
{
	if (Glow != None)
	{
		Glow.Destroy();
		Glow = None;
	}
	if (Shaft != None)
	{
		Shaft.Destroy();
		Shaft = None;
	}
}

function StartTreeGlow()
{
	bReady = true;
	GlowWait = 0;
	if (Glow == None || Glow.bDeleteMe)
		Glow = Spawn(class'APTimeWarpGlow', self,, Location + vect(0,0,20));
	if (Glow != None)
		Glow.AttachToPickup(self);
	if (Shaft == None || Shaft.bDeleteMe)
		Shaft = Spawn(class'APTimeWarpShaft', self,, Location);
	if (Shaft != None)
		Shaft.AttachToPickup(self);
	if (P2GameInfoSingle(Level.Game) != None
		&& P2GameInfoSingle(Level.Game).GetPlayer() != None)
		P2GameInfoSingle(Level.Game).GetPlayer().ClientMessage(
			"Time Warp is ready. Pick it up to warp.");
}

function EndWarpGlow()
{
	bReady = false;
	bArmed = false;
	KillGlowActors();
	if (P2GameInfoSingle(Level.Game) != None
		&& P2GameInfoSingle(Level.Game).GetPlayer() != None)
		P2GameInfoSingle(Level.Game).GetPlayer().ClientMessage(
			"Time Warp faded. Pick it up.");
}

event Tick(float DeltaTime)
{
	Super.Tick(DeltaTime);
	if (!bArmed)
		return;
	if (!bReady)
	{
		GlowWait += DeltaTime;
		if (GlowWait >= GLOW_DELAY)
			StartTreeGlow();
		return;
	}
	GlowWait += DeltaTime;
	if (GlowWait >= GLOW_LIFE)
		EndWarpGlow();
}

simulated function Destroyed()
{
	KillGlowActors();
	Super.Destroyed();
}

state Pickup
{
Begin:
	SetTimer(0.1, false);
	Enable('Tick');
}

defaultproperties
{
	InventoryType=class'Archipelago.APTimeWarpInv'
	PickupMessage="You picked up Time Warp."
	DrawType=DT_Sprite
	Texture=Texture'Archipelago.APLogo'
	Style=STY_Masked
	DrawScale=0.20
	CollisionRadius=40
	CollisionHeight=36
	bAllowMovement=true
	bRecordAfterPickup=false
	bOKToGrab=true
	bAlwaysTick=true
	bStasis=false
	bUnlit=true
	AmbientGlow=255
}
