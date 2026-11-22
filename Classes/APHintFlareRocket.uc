///////////////////////////////////////////////////////////////////////////////
// Noclip flare rocket. Moves by SetLocation so it can pass through BSP
// (houses, interiors) then cluster-bursts in the sky.
///////////////////////////////////////////////////////////////////////////////
class APHintFlareRocket extends Actor;

var float Age;
var float NextBurst;
var int BurstN;
var bool bCluster;

const FLY_TIME = 2.2;
const BURST_COUNT = 5;
const BURST_GAP = 0.09;
const FLY_SPEED = 2400.0;

function PostBeginPlay()
{
	local rotator R;

	Super.PostBeginPlay();
	SetCollision(false, false, false);
	bCollideWorld = false;
	R.Pitch = 16384;
	R.Yaw = 0;
	R.Roll = 0;
	SetRotation(R);
	Spawn(class'APHintFlareSfx',,, Location);
}

function Tick(float DeltaTime)
{
	local vector Off, Next;

	Super.Tick(DeltaTime);
	if (bCluster)
	{
		NextBurst = NextBurst - DeltaTime;
		if (NextBurst <= 0)
		{
			Off = vect(0,0,0);
			if (BurstN < BURST_COUNT)
			{
				Off.X = (FRand() * 2 - 1) * 110;
				Off.Y = (FRand() * 2 - 1) * 110;
				Off.Z = (FRand() * 2 - 1) * 70;
			}
			Spawn(class'APHintFlareBurst',,, Location + Off);
			BurstN++;
			NextBurst = BURST_GAP;
			if (BurstN >= BURST_COUNT)
				Destroy();
		}
		return;
	}

	Next = Location;
	Next.Z = Next.Z + FLY_SPEED * DeltaTime;
	SetLocation(Next);
	Age = Age + DeltaTime;
	if (Age >= FLY_TIME)
	{
		bHidden = true;
		bCluster = true;
		BurstN = 0;
		NextBurst = 0;
		Spawn(class'APHintFlareBoom',,, Location);
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
	bCollideWhenPlacing=false
	bAcceptsProjectors=false
	bShadowCast=false
	bUnlit=true
	bBlockZeroExtentTraces=false
	bBlockNonZeroExtentTraces=false
	RemoteRole=ROLE_None
	DrawType=DT_StaticMesh
	StaticMesh=StaticMesh'stuff.stuff1.launcherrocket'
	// Larger than a fired launcher rocket (scale 1) so the trail reads across a map.
	DrawScale=2.0
	AmbientGlow=255
	CullDistance=0
	CollisionRadius=1
	CollisionHeight=1
	Physics=PHYS_None
	LifeSpan=4.0
}
