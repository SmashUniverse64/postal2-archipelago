///////////////////////////////////////////////////////////////////////////////
// APLink
// Localhost TCP client that talks to the Postal 2 Client (apworld).
//
// Outgoing lines are queued until Opened() — map travel tears the socket
// down, and grabbing milk in Paradise often happens before the new
// connection is up. Dropping those lines was the PoC flake.
///////////////////////////////////////////////////////////////////////////////
class APLink extends TcpLink;

var APGameInfo APGame;
var string CompanionHost;
var int CompanionPort;
var string InputBuffer;
var bool bConnecting;
var bool bQuietReconnect;
var array<string> Outbox;
var bool bFlushing;
var bool bDumpSent;
var float ConnectAttemptAt;
var float NextConnectAt;
var bool bIgnoreClosed;
var bool bNeedReplace;
var int FailStreak;

const ReconnectDelay = 2.0;
const ConnectTimeout = 3.0;
const MaxOutbox = 800;
const MaxFailStreak = 8;

///////////////////////////////////////////////////////////////////////////////
function InitBridge(APGameInfo Game)
{
	APGame = Game;
	if (APGame != None)
	{
		CompanionHost = APGame.CompanionHost;
		CompanionPort = APGame.CompanionPort;
	}
	SetTimer(1.0, true);
	ConnectToCompanion();
}

function KickConnect()
{
	if (IsConnected())
		return;
	if (bNeedReplace)
		return;
	if (bConnecting)
	{
		if (ConnectAttemptAt > 0 && Level.TimeSeconds > ConnectAttemptAt + ConnectTimeout)
		{
			log("Archipelago: connect timed out, retrying", 'Archipelago');
			bIgnoreClosed = true;
			Close();
			bConnecting = false;
			ConnectAttemptAt = 0;
			NextConnectAt = Level.TimeSeconds + ReconnectDelay;
			NoteConnectFail();
			return;
		}
		return;
	}
	if (NextConnectAt > 0 && Level.TimeSeconds < NextConnectAt)
		return;
	ConnectToCompanion();
}

///////////////////////////////////////////////////////////////////////////////
function ConnectToCompanion()
{
	local IpAddr Addr;

	if (IsConnected() || bConnecting || bNeedReplace)
		return;
	if (NextConnectAt > 0 && Level.TimeSeconds < NextConnectAt)
		return;

	if (CompanionHost == "")
		CompanionHost = "127.0.0.1";
	if (CompanionPort <= 0)
		CompanionPort = 23981;

	log("Archipelago: connecting to "$CompanionHost$":"$CompanionPort, 'Archipelago');
	bConnecting = true;
	ConnectAttemptAt = Level.TimeSeconds;
	if (ConnectAttemptAt <= 0)
		ConnectAttemptAt = 0.01;
	NextConnectAt = ConnectAttemptAt + ReconnectDelay;

	if (StringToIpAddr(CompanionHost, Addr))
	{
		Addr.Port = CompanionPort;
		OpenBound(Addr);
	}
	else
	{
		Resolve(CompanionHost);
	}
}

function OpenBound(IpAddr Addr)
{
	if (BindPort() == 0)
	{
		bIgnoreClosed = true;
		Close();
		if (BindPort() == 0)
		{
			Warn("Archipelago: BindPort failed");
			bConnecting = false;
			ConnectAttemptAt = 0;
			NextConnectAt = Level.TimeSeconds + ReconnectDelay;
			SetTimer(ReconnectDelay, true);
			NoteConnectFail();
			return;
		}
	}

	Addr.Port = CompanionPort;
	if (!Open(Addr))
	{
		Warn("Archipelago: Open failed");
		bIgnoreClosed = true;
		Close();
		bConnecting = false;
		ConnectAttemptAt = 0;
		NextConnectAt = Level.TimeSeconds + ReconnectDelay;
		SetTimer(ReconnectDelay, true);
		NoteConnectFail();
	}
}

function NoteConnectFail()
{
	FailStreak++;
	if (FailStreak >= MaxFailStreak)
		bNeedReplace = true;
}

event Resolved(IpAddr Addr)
{
	OpenBound(Addr);
}

event ResolveFailed()
{
	Warn("Archipelago: could not resolve "$CompanionHost);
	bConnecting = false;
	NextConnectAt = Level.TimeSeconds + ReconnectDelay;
	SetTimer(ReconnectDelay, true);
	NoteConnectFail();
}

event Opened()
{
	bConnecting = false;
	bIgnoreClosed = false;
	ConnectAttemptAt = 0;
	FailStreak = 0;
	bNeedReplace = false;
	bDumpSent = false;
	bFlushing = false;
	InputBuffer = "";
	log("Archipelago: connected to Postal 2 Client", 'Archipelago');
	if (APGame != None && !bQuietReconnect)
		APGame.SendConnectToBridge();
	bQuietReconnect = true;
	QueueLine("HELLO");
	SetTimer(1.0, true);
}

event Closed()
{
	if (bIgnoreClosed)
	{
		bIgnoreClosed = false;
		return;
	}
	if (bConnecting)
		return;
	bConnecting = false;
	ConnectAttemptAt = 0;
	bDumpSent = false;
	bFlushing = false;
	log("Archipelago: Postal 2 Client connection closed", 'Archipelago');
	NextConnectAt = Level.TimeSeconds + ReconnectDelay;
	SetTimer(ReconnectDelay, true);
}

event Tick(float DeltaTime)
{
	Super.Tick(DeltaTime);
	if (InStr(InputBuffer, Chr(10)) != -1)
		DrainInput(64);
	if (IsConnected() && Outbox.Length > 0)
		FlushOutbox();
}

event Timer()
{
	if (IsConnected())
	{
		if (!bDumpSent && APGame != None)
		{
			bDumpSent = true;
			APGame.ReplayRecordedChecks(self);
			APGame.SendSavedErrands();
		}
		FlushOutbox();
		if (APGame != None)
		{
			APGame.FlushPendingItems();
			APGame.PollWorldChecks();
		}
	}
	else
		KickConnect();
}

event ReceivedText(string Text)
{
	InputBuffer = InputBuffer $ Text;
	InputBuffer = ReplaceCRWithLF(InputBuffer);
	DrainInput(64);
}

function DrainInput(int MaxLines)
{
	local int i, N;
	local string Line;

	if (MaxLines < 1)
		MaxLines = 64;
	while (N < MaxLines)
	{
		i = InStr(InputBuffer, Chr(10));
		if (i == -1)
			break;
		Line = Left(InputBuffer, i);
		InputBuffer = Mid(InputBuffer, i + 1);
		HandleLine(Line);
		N++;
	}
	if (InStr(InputBuffer, Chr(10)) == -1 && Len(InputBuffer) > 16384)
		InputBuffer = "";
}

function string ReplaceCRWithLF(string S)
{
	local int i;

	i = InStr(S, Chr(13));
	while (i != -1)
	{
		if (Mid(S, i + 1, 1) == Chr(10))
			S = Left(S, i) $ Mid(S, i + 1);
		else
			S = Left(S, i) $ Chr(10) $ Mid(S, i + 1);
		i = InStr(S, Chr(13));
	}
	return S;
}

event Destroyed()
{
	if (IsConnected())
		Close();
	Super.Destroyed();
}

///////////////////////////////////////////////////////////////////////////////
function QueueLine(string Line)
{
	local int i, n;

	if (Line == "")
		return;

	// Keep CHECK/GOAL/HELLO unique in the outbox so retries don't pile up.
	if (Left(Line, 5) ~= "CHECK" || Left(Line, 4) ~= "GOAL" || Line ~= "HELLO")
	{
		n = Outbox.Length;
		if (n > MaxOutbox)
			n = MaxOutbox;
		for (i = 0; i < n; i++)
			if (Outbox[i] ~= Line)
				return;
	}

	if (Outbox.Length >= MaxOutbox)
	{
		if (Outbox.Length > MaxOutbox)
			Outbox.Length = MaxOutbox;
		Outbox.Remove(0, 1);
	}

	Outbox[Outbox.Length] = Line;
	if (!bFlushing)
		FlushOutbox();
}

function SendLine(string Line)
{
	QueueLine(Line);
}

function FlushOutbox()
{
	local int i, n;
	local string Lines[32];

	if (bFlushing || !IsConnected())
		return;
	n = Outbox.Length;
	if (n <= 0)
		return;
	if (n > 32)
		n = 32;
	for (i = 0; i < n; i++)
		Lines[i] = Outbox[i];
	Outbox.Remove(0, n);
	bFlushing = true;
	for (i = 0; i < n; i++)
		SendText(Lines[i] $ Chr(13) $ Chr(10));
	bFlushing = false;
}

function DumpInventory()
{
	local P2Player P;
	local P2Pawn Dude;
	local Inventory Inv;

	if (APGame == None)
		return;
	P = APGame.GetPlayer();
	if (P == None)
		return;
	Dude = P2Pawn(P.Pawn);
	if (Dude == None)
		return;

	QueueLine("INVSTART");
	for (Inv = Dude.Inventory; Inv != None; Inv = Inv.Inventory)
		QueueLine("INV "$string(Inv.Class));
	QueueLine("INVEND");
}

function SendCheck(string UniqueName)
{
	local bool bNew;

	if (UniqueName == "" || InStr(UniqueName, "=") != -1
		|| InStr(UniqueName, "(") != -1 || InStr(UniqueName, " ") != -1)
		return;

	bNew = true;
	if (APGame != None)
	{
		bNew = !APGame.HasRecordedCheck(UniqueName);
		APGame.RecordCheck(UniqueName);
	}

	// Already delivered this level and the socket is up — don't resend every poll.
	if (!bNew && IsConnected())
		return;

	QueueLine("CHECK "$UniqueName);
}

function SendPickup(Pickup Item)
{
	if (Item != None)
		QueueLine("PICKUP "$string(Item.Class)$" tag="$string(Item.Tag));
}

function SendGoal()
{
	QueueLine("GOAL");
}

///////////////////////////////////////////////////////////////////////////////
function HandleLine(string Line)
{
	local string Cmd, Arg, ClassName, AmountStr, IndexStr, Rest;
	local int i, Amt, Idx;

	if (Line == "")
		return;

	i = InStr(Line, " ");
	if (i == -1)
	{
		Cmd = Line;
		Arg = "";
	}
	else
	{
		Cmd = Left(Line, i);
		Arg = Mid(Line, i + 1);
	}

	Cmd = Caps(Cmd);
	if (Cmd != "CHECKED" && Cmd != "SCROUNGE" && Cmd != "OPTION"
		&& Cmd != "VENDORHINT" && Cmd != "MAPDAY" && Cmd != "STARTER"
		&& Cmd != "UNLOCK" && Cmd != "FILLER" && Cmd != "WELCOME"
		&& Cmd != "SEED" && Cmd != "CHECKEDEND" && Cmd != "SCROUNGECLEAR"
		&& Cmd != "TRACKER" && Cmd != "GREY" && Cmd != "GREYCLEAR"
		&& Cmd != "GREYEND")
		log("Archipelago: recv "$Cmd$" "$Arg, 'Archipelago');

	if (Cmd == "WELCOME")
	{
		log("Archipelago: Postal 2 Client ready", 'Archipelago');
	}
	else if (Cmd == "UNLOCK")
	{
		if (APGame != None)
			APGame.UnlockItem(Arg);
	}
	else if (Cmd == "FILLER")
	{
		i = InStr(Arg, " ");
		if (i == -1)
			return;
		ClassName = Left(Arg, i);
		Rest = Mid(Arg, i + 1);
		i = InStr(Rest, " ");
		if (i == -1)
		{
			Amt = int(Rest);
			Idx = 0;
		}
		else
		{
			Amt = int(Left(Rest, i));
			Idx = int(Mid(Rest, i + 1));
		}
		if (APGame != None)
			APGame.GiveFiller(ClassName, Amt, Idx);
	}
	else if (Cmd == "ITEM")
	{
		Amt = 0;
		i = InStr(Arg, " ");
		if (i == -1)
			ClassName = Arg;
		else
		{
			ClassName = Left(Arg, i);
			AmountStr = Mid(Arg, i + 1);
			Amt = int(AmountStr);
		}
		if (APGame != None)
			APGame.GiveAPItem(ClassName, Amt);
	}
	else if (Cmd == "TRAP")
	{
		if (APGame != None)
			APGame.ApplyTrap(Arg);
	}
	else if (Cmd == "MSG")
	{
		if (APGame != None && !APGame.IsQuietStatusMessage(Arg))
			APGame.ShowAPMessage(Arg);
	}
	else if (Cmd == "VENDORHINT")
	{
		// unique flags price name...
		i = InStr(Arg, " ");
		if (i == -1 || APGame == None)
			return;
		ClassName = Left(Arg, i);
		Rest = Mid(Arg, i + 1);
		i = InStr(Rest, " ");
		if (i == -1)
			return;
		Amt = int(Left(Rest, i));
		Rest = Mid(Rest, i + 1);
		i = InStr(Rest, " ");
		if (i == -1)
			return;
		Idx = int(Left(Rest, i));
		Rest = Mid(Rest, i + 1);
		APGame.SetVendorHint(ClassName, Amt, Idx, Rest);
	}
	else if (Cmd == "OPTION")
	{
		i = InStr(Arg, " ");
		if (i != -1 && APGame != None)
			APGame.SetOption(Left(Arg, i), int(Mid(Arg, i + 1)));
	}
	else if (Cmd == "STARTER")
	{
		if (APGame != None)
			APGame.SetStarterErrand(Arg);
	}
	else if (Cmd == "MAPDAY")
	{
		i = InStr(Arg, " ");
		if (i != -1 && APGame != None)
			APGame.SetMapTokenDay(Left(Arg, i), int(Mid(Arg, i + 1)));
	}
	else if (Cmd == "SCROUNGECLEAR")
	{
		if (APGame != None)
			APGame.ClearScroungeCatalog();
	}
	else if (Cmd == "SCROUNGE")
	{
		if (APGame != None)
			APGame.ParseScroungeLine(Arg);
	}
	else if (Cmd == "GREYCLEAR")
	{
		if (APGame != None)
			APGame.ClearGreyTokens();
	}
	else if (Cmd == "GREY")
	{
		if (APGame != None)
			APGame.AddGreyToken(Arg);
	}
	else if (Cmd == "GREYEND")
	{
		if (APGame != None)
			APGame.RefreshTokenLooks();
	}
	else if (Cmd == "TRACKER")
	{
		i = InStr(Arg, " ");
		if (APGame == None)
			return;
		if (i == -1)
			APGame.SetTrackerCounts(int(Arg), 0);
		else
			APGame.SetTrackerCounts(int(Left(Arg, i)), int(Mid(Arg, i + 1)));
	}
	else if (Cmd == "SENT")
	{
		if (APGame != None)
			APGame.NotifyCheckSent(Arg);
	}
	else if (Cmd == "CHECKED")
	{
		if (APGame != None)
			APGame.MarkRemoteCheckLine(Arg);
	}
	else if (Cmd == "CHECKEDEND")
	{
		if (APGame != None)
		{
			APGame.RepairRecBlobs();
			APGame.bNeedStripCollected = true;
			APGame.bCheckedSyncReady = true;
			APGame.InvalidateMapTokCounts();
			APGame.NextGlowUpdate = 0;
		}
	}
	else if (Cmd == "SEEDRESET")
	{
		if (APGame != None)
			APGame.ApplyAPSeed(Arg, true);
	}
	else if (Cmd == "SEED")
	{
		if (APGame != None)
			APGame.ApplyAPSeed(Arg, false);
	}
	else if (Cmd == "DEATHLINK")
	{
		if (APGame != None)
			APGame.KillFromDeathLink(Arg);
	}
}

defaultproperties
{
	LinkMode=MODE_Text
	ReceiveMode=RMODE_Event
	bHidden=True
	bAlwaysTick=True
	CompanionHost="127.0.0.1"
	CompanionPort=23981
}
