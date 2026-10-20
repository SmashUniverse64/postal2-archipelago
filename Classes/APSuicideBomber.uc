///////////////////////////////////////////////////////////////////////////////
// Trap suicide bomber. Same NPC as the Home marching-band attacker, but the
// blast is grenade-strength. Charges the Dude until shot or they get close.
///////////////////////////////////////////////////////////////////////////////
class APSuicideBomber extends SuicideBomber;

var P2Pawn Prey;
var float ChaseWait;
var bool bBlew;
var bool bStripped;
var bool bDidScream;

const EXPLODE_DIST = 160.0;
const CHASE_GAP = 0.30;

function PostBeginPlay()
{
	Super.PostBeginPlay();
	BaseEquipment.Length = 0;
	StripGuns();
}

function PlayChargeScream()
{
	if (bDidScream)
		return;
	if (myDialog == None)
		return;
	Say(myDialog.lBattleCry, true);
	bDidScream = true;
}

function AddDefaultInventory()
{
	BaseEquipment.Length = 0;
	Super.AddDefaultInventory();
	StripGuns();
}

function Tick(float DeltaTime)
{
	Super.Tick(DeltaTime);
	if (bDeleteMe || Health <= 0 || bBlew)
		return;
	if (Weapon != None || !bStripped)
		StripGuns();
	ChaseWait = ChaseWait + DeltaTime;
	CheckExplode();
	if (ChaseWait >= CHASE_GAP)
	{
		ChaseWait = 0;
		KeepChasing();
	}
}

function StripGuns()
{
	local Inventory Inv, Next;
	local int n;

	Inv = Inventory;
	n = 0;
	while (Inv != None && n < 40)
	{
		Next = Inv.Inventory;
		if (Weapon(Inv) != None)
		{
			DeleteInventory(Inv);
			Inv.Destroy();
		}
		Inv = Next;
		n++;
	}
	Weapon = None;
	PendingWeapon = None;
	bHasViolentWeapon = false;
	bStripped = true;
}

function CheckExplode()
{
	local P2Pawn Dude;

	Dude = Prey;
	if (Dude == None || Dude.bDeleteMe || Dude.Health <= 0)
		Dude = FindDude();
	if (Dude == None)
		return;
	Prey = Dude;
	if (VSize(Dude.Location - Location) <= EXPLODE_DIST + Dude.CollisionRadius)
		BlowUp();
}

function KeepChasing()
{
	local P2Pawn Dude;
	local PersonController PC;
	local vector To;
	local rotator R;

	Dude = Prey;
	if (Dude == None || Dude.bDeleteMe || Dude.Health <= 0)
		Dude = FindDude();
	if (Dude == None)
		return;
	Prey = Dude;
	PC = PersonController(Controller);
	if (PC != None)
	{
		PC.SetAttacker(Dude);
		PC.InterestPawn = Dude;
		PC.SetEndGoal(Dude, 50);
		PC.SetNextState('AssessAttacker');
		if (!PC.IsInState('RunToAttacker') && !PC.IsInState('LegMotionToTarget'))
			PC.GotoStateSave('RunToAttacker');
	}
	if (VSize(Velocity) < 40)
	{
		To = Dude.Location - Location;
		To.Z = 0;
		if (VSize(To) > 1)
		{
			R = rotator(To);
			R.Pitch = 0;
			R.Roll = 0;
			SetRotation(R);
			Acceleration = Normal(To) * AccelRate;
		}
	}
}

function P2Pawn FindDude()
{
	local P2Player P;

	if (P2GameInfoSingle(Level.Game) != None)
		P = P2GameInfoSingle(Level.Game).GetPlayer();
	if (P != None)
		return P2Pawn(P.Pawn);
	return None;
}

function BlowUp()
{
	if (bBlew || Health <= 0)
		return;
	bBlew = true;
	bSuicided = true;
	Spawn(class'GrenadeExplosion', Self,, Location, Rotation);
	Died(None, class'ExplodedDamage', Location);
}

function Died(Controller Killer, class<DamageType> damageType, vector HitLocation)
{
	Super(Fanatics).Died(Killer, damageType, HitLocation);
}

defaultproperties
{
	ControllerClass=class'Archipelago.APSuicideBomberController'
	HealthMax=70
	bPlayerIsEnemy=true
	bCanPickupInventory=false
	bStasis=false
	TalkBeforeFighting=1.0
	TalkWhileFighting=1.0
	BaseEquipment[0]=(weaponclass=None)
}
