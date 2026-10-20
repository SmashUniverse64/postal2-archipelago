///////////////////////////////////////////////////////////////////////////////
// Keeps the trap bomber running at the Dude instead of opening fire.
///////////////////////////////////////////////////////////////////////////////
class APSuicideBomberController extends FanaticController;

function StartChase(P2Pawn Dude)
{
	if (Dude == None)
		return;
	SetAttacker(Dude);
	InterestPawn = Dude;
	SetEndGoal(Dude, 50);
	SetNextState('AssessAttacker');
	if (APSuicideBomber(MyPawn) != None)
		APSuicideBomber(MyPawn).PlayChargeScream();
	else if (MyPawn != None && MyPawn.myDialog != None)
		Say(MyPawn.myDialog.lBattleCry, true);
	GotoStateSave('RunToAttacker');
}

state AssessAttacker
{
	function YellBeforeAttack()
	{
		if (APSuicideBomber(MyPawn) != None)
			APSuicideBomber(MyPawn).PlayChargeScream();
		else if (MyPawn != None && MyPawn.myDialog != None)
			Say(MyPawn.myDialog.lBattleCry, true);
		SayTime = 0;
	}
}

defaultproperties
{
}
