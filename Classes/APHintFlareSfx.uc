///////////////////////////////////////////////////////////////////////////////
// Stationary world speaker for the Hint Flare launch. Stays at the token so
// the whoosh spatializes instead of riding the player or the rising rocket.
///////////////////////////////////////////////////////////////////////////////
class APHintFlareSfx extends Actor;

function PostBeginPlay()
{
	Super.PostBeginPlay();
	PlaySound(Sound'Archipelago.FlareDetonatorLaunch', SLOT_Misc, 0.45, false, 3200, 1.0, true);
}

defaultproperties
{
	bStatic=false
	bNoDelete=false
	bHidden=true
	bMovable=false
	bCollideActors=false
	bCollideWorld=false
	bBlockActors=false
	bBlockPlayers=false
	bProjTarget=false
	bCollideWhenPlacing=false
	bBlockZeroExtentTraces=false
	bBlockNonZeroExtentTraces=false
	RemoteRole=ROLE_None
	DrawType=DT_None
	Physics=PHYS_None
	LifeSpan=4.0
	TransientSoundRadius=3200
}
