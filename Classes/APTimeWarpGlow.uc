///////////////////////////////////////////////////////////////////////////////
// World light on a thrown Time Warp. The visible column is APTimeWarpShaft;
// this actor lights the ground and adds a modest corona at the token.
///////////////////////////////////////////////////////////////////////////////
class APTimeWarpGlow extends Light;

var Actor Target;
var float HueWait;

function AttachToPickup(Actor A)
{
	local rotator R;

	Target = A;
	SetOwner(A);
	SetBase(A);
	if (A != None)
		SetLocation(A.Location + vect(0,0,20));
	R = Rotation;
	R.Pitch = 16384;
	R.Yaw = 0;
	R.Roll = 0;
	SetRotation(R);
	LightType = LT_Steady;
	LightEffect = LE_Spotlight;
	bDynamicLight = true;
	bCorona = true;
	LightBrightness = 255;
	LightRadius = 64;
	LightCone = 36;
	LightSaturation = 60;
	LightHue = 0;
}

function Tick(float DeltaTime)
{
	if (Target == None || Target.bDeleteMe)
	{
		Destroy();
		return;
	}
	SetLocation(Target.Location + vect(0,0,20));
	HueWait += DeltaTime;
	if (HueWait < 0.35)
		return;
	HueWait = 0;
	if (LightHue < 20)
		LightHue = 40;
	else if (LightHue < 60)
		LightHue = 80;
	else
		LightHue = 0;
}

defaultproperties
{
	bStatic=false
	bNoDelete=false
	bHidden=true
	bMovable=true
	bAlwaysTick=true
	bStasis=false
	bCollideActors=false
	bCollideWorld=false
	bBlockActors=false
	bProjTarget=false
	bAcceptsProjectors=false
	RemoteRole=ROLE_None
	bDynamicLight=true
	LightType=LT_Steady
	LightEffect=LE_Spotlight
	LightBrightness=255
	LightHue=0
	LightSaturation=60
	LightRadius=64
	LightCone=36
	LightPeriod=32
	bCorona=true
	MinCoronaSize=40
	MaxCoronaSize=600
	CollisionRadius=1
	CollisionHeight=1
}
