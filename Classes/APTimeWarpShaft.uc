///////////////////////////////////////////////////////////////////////////////
// Forest Christmas-tree godshaft. Grows from the thrown Time Warp token the
// same way Mover1 does on Get Tree (DrawScale 100) and plays the angel cue.
///////////////////////////////////////////////////////////////////////////////
class APTimeWarpShaft extends Actor;

var Actor Target;
var float GrowElapsed;
var bool bPlayedSound;

const GROW_TIME = 1.0;
const START_SCALE = 0.5;
const END_SCALE = 100.0;

function AttachToPickup(Actor A)
{
	Target = A;
	SetOwner(A);
	SetBase(A);
	GrowElapsed = 0;
	bPlayedSound = false;
	SetDrawScale(START_SCALE);
	if (A != None)
		SetLocation(A.Location);
	PlayAngelSound();
}

function PlayAngelSound()
{
	local Sound S;

	if (bPlayedSound)
		return;
	bPlayedSound = true;
	S = Sound(DynamicLoadObject("LevelSoundsToo.Forest.forestChristmasTree_Angel", class'Sound', true));
	if (S != None)
		PlaySound(S, SLOT_None, 1.0, true, 2500.0, 1.0);
}

function Tick(float DeltaTime)
{
	local float Alpha;

	Super.Tick(DeltaTime);
	if (Target == None || Target.bDeleteMe)
	{
		Destroy();
		return;
	}
	SetLocation(Target.Location);

	if (GrowElapsed < GROW_TIME)
	{
		GrowElapsed += DeltaTime;
		if (GrowElapsed > GROW_TIME)
			GrowElapsed = GROW_TIME;
		Alpha = GrowElapsed / GROW_TIME;
		Alpha = Alpha * (2.0 - Alpha);
		SetDrawScale(START_SCALE + (END_SCALE - START_SCALE) * Alpha);
	}
}

defaultproperties
{
	bStatic=false
	bNoDelete=false
	bHidden=false
	bMovable=true
	bAlwaysTick=true
	bStasis=false
	bCollideActors=false
	bCollideWorld=false
	bBlockActors=false
	bBlockPlayers=false
	bProjTarget=false
	bAcceptsProjectors=false
	bShadowCast=false
	bUnlit=true
	RemoteRole=ROLE_None
	DrawType=DT_StaticMesh
	StaticMesh=StaticMesh'stv-protocrap.godshaft'
	DrawScale=0.5
	CollisionRadius=1
	CollisionHeight=1
	Physics=PHYS_None
	TransientSoundRadius=2500
}
