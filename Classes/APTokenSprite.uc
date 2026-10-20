///////////////////////////////////////////////////////////////////////////////
// World-space Archipelago logo. Kept on its own actor so pickup Style,
// Skins, DrawScale3D, and fogged STY_Alpha quads cannot turn it into a
// black box. STY_Masked uses the TGA alpha as a punch-through mask.
///////////////////////////////////////////////////////////////////////////////
class APTokenSprite extends Actor;

var Pickup Target;
var sound PingSound;
var float PingInterval;
var float PingWait;

function AttachToPickup(Pickup Item)
{
	Target = Item;
	SetOwner(Item);
	if (Item != None)
		SetLocation(Item.Location + vect(0,0,12));
	SetBase(Item);
}

function Tick(float DeltaTime)
{
	local APGameInfo G;
	local P2Player P;
	local Pawn Dude;
	local float Dist, Prox, Vol, Intv, R, Best;

	if (Target == None || Target.bDeleteMe)
	{
		Destroy();
		return;
	}
	if (Base != Target)
		AttachToPickup(Target);

	if (Level.Pauser != None)
		return;

	G = APGameInfo(Level.Game);
	if (G != None && !G.TokenBeepEnabled())
		return;
	if (PingSound == None)
		return;

	if (P2GameInfoSingle(Level.Game) != None)
		P = P2GameInfoSingle(Level.Game).GetPlayer();
	if (P != None)
		Dude = P.Pawn;
	if (Dude == None)
		return;

	R = TransientSoundRadius;
	if (R < 1)
		R = 3000;
	Dist = VSize(Location - Dude.Location);
	if (Dist >= R)
		return;
	if (G != None)
	{
		Best = G.NearestTokenBeepDist(Dude);
		if (Dist > Best + 16)
			return;
	}

	Prox = 1.0 - Dist / R;
	if (Prox < 0)
		Prox = 0;
	if (Prox > 1)
		Prox = 1;
	Vol = 0.18 + 0.37 * Prox;
	Intv = PingInterval - (PingInterval - 0.45) * Prox;
	if (Intv < 0.45)
		Intv = 0.45;

	PingWait += DeltaTime;
	if (PingWait >= Intv)
	{
		PingWait = 0;
		PlaySound(PingSound, SLOT_Misc, Vol, false, R);
	}
}

defaultproperties
{
	bStatic=false
	bNoDelete=false
	bHidden=false
	bCollideActors=false
	bCollideWorld=false
	bBlockActors=false
	bProjTarget=false
	bAcceptsProjectors=false
	bShadowCast=false
	bUnlit=true
	bUseLightingFromBase=false
	bMovable=true
	bAlwaysTick=true
	RemoteRole=ROLE_None
	DrawType=DT_Sprite
	Texture=Texture'Archipelago.APLogo'
	Style=STY_Masked
	AmbientGlow=255
	DrawScale=0.20
	CollisionRadius=1
	CollisionHeight=1
	SoundRadius=90
	SoundVolume=300
	SoundPitch=64
	TransientSoundRadius=3000
	PingSound=Sound'MpSounds.MenuBeat'
	PingInterval=4.0
}
