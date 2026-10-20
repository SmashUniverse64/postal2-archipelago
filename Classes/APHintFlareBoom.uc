///////////////////////////////////////////////////////////////////////////////
// One world-space rocket boom per Hint Flare. Lives long enough for the
// sound to finish after the rocket actor is destroyed.
///////////////////////////////////////////////////////////////////////////////
class APHintFlareBoom extends Actor;

function PostBeginPlay()
{
	Super.PostBeginPlay();
	PlaySound(Sound'WeaponSounds.rocket_explode', SLOT_None, 0.55, true, 4500, 1.0, true);
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
	LifeSpan=2.5
	TransientSoundRadius=4500
}
