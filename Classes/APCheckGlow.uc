///////////////////////////////////////////////////////////////////////////////
// Light on AP-token pickups and on ATM / Crackola / vending machines that
// still have checks. Progression/useful tokens and machines rainbow-cycle
// hue. Filler/trap tokens pulse grey instead.
//
// Ghetto (SUBURBS-2) is a huge open BSP. Twelve dynamic lights at once overflow
// D3D in FBspProjectorDrawList. Other maps keep every glow as a world light.
// On Ghetto, lights in the camera cone (with hysteresis) project onto BSP.
///////////////////////////////////////////////////////////////////////////////
class APCheckGlow extends Light;

var Actor Target;
var float Hue;
var float HueWait;
var float ProjectWait;
var bool bMachine;
var bool bGrey;
var float PulseT;
var sound PingSound;
var float PingInterval;
var float PingWait;

function AttachToPickup(Pickup Item)
{
	bMachine = false;
	Target = Item;
	if (Target != None)
	{
		SetLocation(Target.Location + vect(0,0,24));
		Target.bUnlit = true;
		Target.bDynamicLight = false;
		Target.LightType = LT_None;
		Target.AmbientGlow = 255;
		Target.bAcceptsProjectors = false;
	}
	SetBase(Item);
	ApplyLightMode();
}

function vector MachineGlowLocation(Actor A)
{
	local vector L, Away;
	local P2EVendingMachineTrigger V;
	local float Best, Dist;

	L = A.Location;
	if (A.IsA('P2EVendingMachineTrigger'))
		L.Z += 56;
	else if (A.IsA('CrackolaTrigger'))
		L.Z += 40;
	else if (A.IsA('ATMTrigger'))
	{
		L.Z += 18;
		Best = 80;
		foreach AllActors(class'P2EVendingMachineTrigger', V)
		{
			Dist = VSize(V.Location - A.Location);
			if (Dist < Best && Dist > 1)
			{
				Best = Dist;
				Away = A.Location - V.Location;
			}
		}
		if (Best < 80)
		{
			Away.Z = 0;
			if (VSize(Away) > 1)
				L += Normal(Away) * 28;
		}
	}
	else
		L.Z += 40;
	return L;
}

function AttachToActor(Actor A)
{
	bMachine = true;
	Target = A;
	if (Target != None)
		SetLocation(MachineGlowLocation(Target));
	SetBase(A);
	ApplyLightMode();
}

function SetGreyMode(bool Grey)
{
	bGrey = Grey;
	if (bGrey)
	{
		LightHue = 0;
		LightSaturation = 255;
		if (LightBrightness < 80)
			LightBrightness = 160;
	}
	else
	{
		LightSaturation = 40;
		LightBrightness = 255;
	}
	ApplyLightMode();
}

function bool ActorInCone(Actor A, vector Eye, vector CamDir, float MinDot, float MaxDist)
{
	local vector To;
	local float D;

	if (A == None)
		return false;
	To = A.Location - Eye;
	D = VSize(To);
	if (D > MaxDist)
		return false;
	if (D < 80)
		return true;
	return ((To / D) Dot CamDir) >= MinDot;
}

function bool ShouldProjectLight()
{
	local APGameInfo G;
	local P2Player P;
	local Pawn Dude;
	local APCheckGlow Other;
	local vector Eye, CamDir;
	local float Dist, MinDot, MaxDist;
	local int Closer, MaxOn;

	G = APGameInfo(Level.Game);
	if (G == None || !G.TokenGlowEnabled())
		return false;
	if (!(G.MapKey() ~= "SUBURBS-2"))
		return true;

	if (P2GameInfoSingle(Level.Game) != None)
		P = P2GameInfoSingle(Level.Game).GetPlayer();
	if (P != None)
		Dude = P.Pawn;
	if (P == None || Dude == None)
		return false;

	Eye = Dude.Location;
	Eye.Z += Dude.BaseEyeHeight;
	CamDir = vector(P.GetViewRotation());
	Dist = VSize(Location - Eye);

	if (bDynamicLight)
	{
		MinDot = 0.18;
		MaxDist = 7000;
		MaxOn = 8;
	}
	else
	{
		MinDot = 0.38;
		MaxDist = 5600;
		MaxOn = 6;
	}

	if (!ActorInCone(Self, Eye, CamDir, MinDot, MaxDist))
		return false;

	Closer = 0;
	foreach DynamicActors(class'APCheckGlow', Other)
	{
		if (Other == None || Other == Self)
			continue;
		if (VSize(Other.Location - Eye) + 1 >= Dist)
			continue;
		if (!ActorInCone(Other, Eye, CamDir, MinDot, MaxDist))
			continue;
		Closer++;
		if (Closer >= MaxOn)
			return false;
	}
	return true;
}

function ApplyLightMode()
{
	local APGameInfo G;

	G = APGameInfo(Level.Game);
	if (G == None || !G.TokenGlowEnabled())
	{
		LightType = LT_None;
		bDynamicLight = false;
		bCorona = false;
		LightRadius = 1;
		return;
	}

	LightType = LT_Steady;
	bCorona = true;
	if (ShouldProjectLight())
	{
		bDynamicLight = true;
		if (bMachine)
		{
			if (Target != None && Target.IsA('ATMTrigger')
				&& !Target.IsA('CrackolaTrigger'))
				LightRadius = 10;
			else
				LightRadius = 16;
		}
		else
			LightRadius = 14;
	}
	else
	{
		bDynamicLight = false;
		LightRadius = 1;
	}
}

function Tick(float DeltaTime)
{
	if (Target == None || Target.bDeleteMe)
	{
		Destroy();
		return;
	}
	if (Base != Target)
	{
		if (bMachine)
			AttachToActor(Target);
		else if (Pickup(Target) != None)
			AttachToPickup(Pickup(Target));
	}

	ProjectWait += DeltaTime;
	if (ProjectWait >= 0.25)
	{
		ProjectWait = 0;
		ApplyLightMode();
	}

	if (bGrey && !bMachine)
	{
		PulseT += DeltaTime * 2.0;
		if (PulseT > 2.0)
			PulseT -= 2.0;
		LightHue = 0;
		LightSaturation = 255;
		if (PulseT <= 1.0)
			LightBrightness = 70 + PulseT * 150;
		else
			LightBrightness = 70 + (2.0 - PulseT) * 150;
	}
	else
	{
		HueWait += DeltaTime;
		if (HueWait >= 0.12)
		{
			HueWait = 0;
			Hue += 20;
			if (Hue >= 255)
				Hue -= 255;
			LightHue = Hue;
			LightSaturation = 40;
			LightBrightness = 255;
		}
	}

	if (bMachine)
		TickMachinePing(DeltaTime);
}

function TickMachinePing(float DeltaTime)
{
	local APGameInfo G;
	local P2Player P;
	local Pawn Dude;
	local float Dist, Prox, Vol, Intv, R;

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

function Destroyed()
{
	local Pickup Item;

	Item = Pickup(Target);
	if (Item != None && !Item.bDeleteMe)
	{
		Item.LightType = LT_None;
		Item.bDynamicLight = false;
	}
	Super.Destroyed();
}

defaultproperties
{
	bStatic=false
	bNoDelete=false
	bHidden=true
	bMovable=true
	bAlwaysTick=true
	RemoteRole=ROLE_None
	bAcceptsProjectors=false
	bDynamicLight=false
	LightType=LT_Steady
	bCorona=true
	LightBrightness=255
	LightHue=0
	LightSaturation=40
	LightRadius=14
	LightEffect=LE_QuadraticNonIncidence
	Hue=0
	HueWait=0
	ProjectWait=0
	bMachine=false
	bGrey=false
	PulseT=0
	SoundRadius=90
	SoundVolume=300
	SoundPitch=64
	TransientSoundRadius=3000
	PingSound=Sound'MpSounds.MenuBeat'
	PingInterval=4.0
}
