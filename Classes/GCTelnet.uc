/**
	GCTelnet
	Telnet client, spawned from GITelnetd
	Note: windows telnet client should use ANSI not VT100
	RFC: 318, 513, 764, 854, 855, 857, 858, 859, 884, 930, 1073, 1091, 1116, 1572
	$Id: GCTelnet.uc,v 1.4 2003/12/30 12:24:47 elmuerte Exp $
*/
class GCTelnet extends UnGatewayClient;

// telnet protocol
const T_IAC       = 255;
const T_WILL      = 251;
const T_WONT      = 252;
const T_DO        = 253;
const T_DONT      = 254;
const T_SB        = 250;
const T_SE        = 240;
// options
const O_ECHO      = 1;
const O_SGOAHEAD  = 3;
const O_TERMINAL  = 24;
const O_WSIZE     = 31;
// control codes
const C_BS				= 8;
const C_TAB				= 9;
const C_NL				= 10;
const C_CR				= 13;
const C_ESC				= 27;
const C_DEL				= 127;

/** true -> echo input */
var bool bEcho;
/** command promp */
var string CommandPrompt;
/** maximum number of login tries before the connection will be closed */
var config int iMaxLogin;
/** initial delay before printing login request */
var config float fDelayInitial;
/** delay after an incorrect login */
var config float fDelayWrongPassword;
/**
	disable authentication, anonymous access allowed
	NEVER USE THIS, change the gateway's authentication class instead
*/
var config bool bDisableAuth;

/** cursor position: x,y, init-x */
var protected int cursorpos[3];
/**
	busy processing special sequences
	current unsupported and broken
*/
var bool bProcEsc, bProcTelnet;

/** command history (reversed order) */
var array<string> CommandHistory;
/** max items in the history */
const MAX_HISTORY = 25;
/** current index in the history */
var protected int CurHisIndex;
/** command entered before entering history */
var protected string LastHistoryInput;
/** Temp storage of data cut away with ^K and pasted with ^Y */
var protected string ClipBoard;
/** used to detect double tabs for tab completion, second tab will display a list */
var protected bool bTabComplRepeat;

// localization
var localized string msgUsername, msgPassword, msgLoginFailed, msgTooManuLogins, msgUnknownCommand;

/** called from defReceiveInput to handle escape codes */
delegate int OnEscapeCode(int pos, int Count, byte B[255])
{
	return 0;
}

event Accepted()
{
	Super.Accepted();
	bEcho = true;

	// don't echo - server: WILL ECHO
  SendText(Chr(T_IAC)$Chr(T_WILL)$Chr(O_ECHO));
  // will supress go ahead
  SendText(Chr(T_IAC)$Chr(T_WILL)$Chr(O_SGOAHEAD));

	if (bDisableAuth)
	{
		sUsername = "anonymous";
		GotoState('logged_in');
	}
	else {
		sUsername = "";
		sPassword = "";
		if (fDelayWrongPassword == 0) fDelayWrongPassword = 0.1;
		if (fDelayInitial == 0) GotoState('login');
		else SetTimer(fDelayInitial, false);
	}
}

/**
	default input handler
	will catch telnet control sequences and buffer the input
	count is always > 0
*/
function defReceiveInput(int Count, byte B[255])
{
	local int i;
	local string tmp;
	i = 0;
	if (bProcEsc) i += OnEscapeCode(i, count, B);
	if (bProcTelnet) i += ProcTelnetProtocol(i, count, b);
	for (i = i; i < Count; i++)
	{
		if (B[i] != C_TAB) bTabComplRepeat = false;
		if (B[i] == T_IAC)
		{
			i += ProcTelnetProtocol(i+1, count, b);
		}
		else if (B[i] == C_CR) // new line
		{
			SendLine(); // send a newline
			OnReceiveLine(inbuffer);
			inbuffer = "";
		}
		else if ((B[i] == C_BS) || (B[i] == C_DEL))
		{
			if (!cmdLineBackspace()) Bell();
		}
		else if (B[i] == C_ESC) // escape code
		{
			i += OnEscapeCode(i+1, count, B);
		}
		else if (B[i] == 11) // ^K, cut line
		{
			ClipBoard = Mid(inbuffer, cursorpos[0]-cursorpos[2]);
			inbuffer = Left(inbuffer, cursorpos[0]-cursorpos[2]);
			if (bEcho) SendText(Chr(C_ESC)$"[K");
		}
		else if (B[i] == 25) // ^Y, paste line
		{
			inbuffer $= ClipBoard;
			if (bEcho) SendText(ClipBoard);
			cursorpos[0] += Len(ClipBoard);
		}
		else if (B[i] == 1) // ^A, begin of line
		{
			if (cursorpos[0] > cursorpos[2])
			{
				if (bEcho) SendText(Chr(C_ESC)$"["$string(cursorpos[0]-cursorpos[2])$"D");
				cursorpos[0] = cursorpos[2];
			}
		}
		else if (B[i] == 5) // ^E, end of line
		{
			if (cursorpos[0] < Len(inbuffer)+cursorpos[2])
			{
				if (bEcho) SendText(Chr(C_ESC)$"["$string(Len(inbuffer)-cursorpos[0]+1)$"C");
				cursorpos[0] = Len(inbuffer)+cursorpos[2];
			}
		}
		else if (B[i] == 4) // ^D, logout or delete
		{
			if (inbuffer == "") OnLogout();
			else {
				if (!cmdLineDelete()) Bell();
			}
		}
		else if (B[i] == 0) {}
		else if (B[i] == C_NL) {} // newline, ignore
		else if (B[i] == C_TAB)  // tab
		{
			OnTabComplete();
		}
		else if (B[i] < 32) /* unhandled control code */
		{
			interface.gateway.Logf("[defReceiveInput] Unhandled control code:"@B[i], Name, interface.gateway.LOG_DEBUG);
		}
		else {
			tmp = Mid(inbuffer, cursorpos[0]-cursorpos[2]);
			inbuffer = Left(inbuffer, cursorpos[0]-cursorpos[2])$Chr(B[i])$tmp;
			cursorpos[0]++;
			if (bEcho)
			{
				SendText(Chr(B[i])$tmp);
				if (Len(tmp) > 0) SendText(Chr(C_ESC)$"["$string(Len(tmp))$"D");
			}
		}
	}
}

/** default escape sequence handler */
function int defProcEscape(int pos, int Count, byte B[255])
{
	local int length, v1, v2;
	local string val1, val2;

	bProcEsc = true;
	length = 0;
	if (pos >= Count) return length;
	if (B[pos] == 91) // [
	{
		length++;
		pos++;
		if (pos >= Count) return length;

		val1 = "";
		val2 = "";
		while ((B[pos] >= 48) && (B[pos] < 57)) // get val1
		{
			val1 $= Chr(B[pos]);
			pos++;
			length++;
		}
		if (B[pos] == 59) // ;
		{
			pos++;
			length++;
			while ((B[pos] >= 48) && (B[pos] < 57)) // get val2
			{
				val2 $= Chr(B[pos]);
				pos++;
				length++;
			}
		}
		v1 = int(val1);
		v2 = int(val2);

		switch (B[pos])
		{
			case 65:	length++; // A=Up
								DisplayCommandHistory(1);
								break;
			case 66:	length++; // B=Down
								DisplayCommandHistory(-1);
								break;
			case 67:	if (cursorpos[0] < Len(inbuffer)+cursorpos[2]) // C=Right
								{
									if (v1 == 0) v1++;
									cursorpos[0] += v1;
									SendText(Chr(C_ESC)$"["$val1$"C");
								}
								length++;
								break;
			case 68:	if (cursorpos[0] > cursorpos[2]) // D=Left
								{
									if (v1 == 0) v1++;
									cursorpos[0] -= v1;
									SendText(Chr(C_ESC)$"["$val1$"D");
								}
								length++;
								break;
			default:	interface.gateway.Logf("[defProcEscape] Unhandled escape code:"@B[pos], Name, interface.gateway.LOG_DEBUG);
		}
	}
	bProcEsc = false;
	return length;
}

/**	perform tab completion */
function defTabComplete()
{
	local array<string> cmd, completion;
	local int i, sz;
	local string tmp;

	if (inbuffer == "") Bell();
	else if (AdvSplit(inbuffer, " ", cmd, "\"") == 0) Bell();
	else {
		// find first matching command
		if (cmd.length == 1)
		{
			sz = Len(cmd[0]);
			for (i = 0; i < Interface.gateway.CmdLookupTable.Length; i++)
			{
				if (Left(Interface.gateway.CmdLookupTable[i].Command, sz) ~= cmd[0])
				{
					completion.length = completion.length + 1;
					completion[completion.Length-1] = Interface.gateway.CmdLookupTable[i].Command;
				}
			}
			if (completion.Length == 1)
			{
				tmp = Mid(completion[0], sz);
				inbuffer $= tmp;
				SendText(tmp);
				cursorpos[0] += Len(tmp);
			}
			else if (!bTabComplRepeat)
			{
				bTabComplRepeat = true;
				Bell();
			}
			else {
				SendLine("");
				for (i = 0; i < completion.Length; i++)
				{
					SendLine(completion[i]);
				}
				SendPrompt();
				SendText(inbuffer);
				cursorpos[0] += Len(inbuffer);
			}
		}
		else {
			Interface.gateway.Logf("Tab completion for"@cmd.length@"items", Name, Interface.gateway.LOG_DEBUG);
		}
	}
}

/** set the cursor to possition x,y */
function SetCursor(int x, int y)
{
	SendText(Chr(C_ESC)$"["$string(y)$";"$string(x)$"H");
}

/** sendtext and append newline */
function SendLine(optional coerce string line)
{
	SendText(line$Chr(13)$chr(10));
}

/**
	process telnet control sequences
*/
function int ProcTelnetProtocol( int pos, int Count, byte B[255] )
{
	local int length;
	length = 0;
	bProcTelnet = true;
	switch (B[pos])
	{
		case T_WILL:	length += 2; break;
		case T_WONT:	length += 2; break;
		case T_DO:		length += 2; break;
		case T_DONT:	length += 2; break;
		case T_SB:		pos++;
									length++;
									while (B[pos] != T_SE)
									{
										length++;
										pos++;
										if (pos > Count) return length;
									}
	}
	bProcTelnet = false;
	return length;
}

/** send the command prompt */
function SendPrompt()
{
	local string line;
	line = repl(CommandPrompt, "%username%", sUsername);
	line = repl(line, "%computername%", Interface.gateway.ComputerName);
	line = repl(line, "%hostname%", Interface.gateway.hostname);
	line = repl(line, "%hostaddress%", Interface.gateway.hostaddress);
	line = repl(line, "%clientaddress%", ClientAddress);
	SendText(line);
	cursorpos[0] = Len(line)-1;
	cursorpos[2] = cursorpos[0]; // set init-x
}

/** send a bell character */
function Bell()
{
	SendText(Chr(7));
}

/** add the last command to the command history */
function AddCommandHistory(coerce string lastcmd)
{
	local int i;
	if (lastcmd == "") return;
	for (i = 0; i < CommandHistory.length; i++)
	{
		if (CommandHistory[i] == lastcmd)
		{
			CommandHistory.Remove(i, 1);
			break;
		}
	}
	CommandHistory.Insert(0, 1);
	CommandHistory[0] = lastcmd;
	if (CommandHistory.length > MAX_HISTORY) CommandHistory.length = MAX_HISTORY;
	CurHisIndex = -1;
	LastHistoryInput = "";
}

/** display an item in the history */
function DisplayCommandHistory(int offset)
{
	if ((CurHisIndex+offset) >= CommandHistory.length) return;
	if ((CurHisIndex+offset) < -1) return;
	if ((LastHistoryInput == "") && (CurHisIndex == -1)) LastHistoryInput = inbuffer;
	CurHisIndex += offset;
	if (CurHisIndex == -1)
	{
		inbuffer = LastHistoryInput;
	}
	else {
		inbuffer = CommandHistory[CurHisIndex];
	}
	if (cursorpos[0]-cursorpos[2] > 0) SendText(Chr(C_ESC)$"["$string(cursorpos[0]-cursorpos[2])$"D");
	SendText(inbuffer$Chr(C_ESC)$"[K");
	cursorpos[0] = cursorpos[2]+Len(inbuffer);
}


/** display the issue message */
function IssueMessage()
{
	SendLine();
	SendLine("UnrealEngine2/"$Level.EngineVersion@Interface.gateway.Ident@Interface.Ident@Interface.gateway.ComputerName@Interface.Gateway.CreationTime);
	if (Interface.gateway.CVSversion != "") SendLine(Interface.gateway.CVSversion);
	SendLine();
}

/** perform a backspace on the commandline */
function bool cmdLineBackspace()
{
	local string tmp;
	if ((inbuffer != "") && (cursorpos[0] > cursorpos[2]))
	{
		tmp = Mid(inbuffer, cursorpos[0]-cursorpos[2]);
		inbuffer = Left(inbuffer, cursorpos[0]-cursorpos[2]-1)$tmp;
		cursorpos[0]--;
		if (bEcho)
		{
			SendText(Chr(C_ESC)$"[D"$Chr(C_ESC)$"[P");
			//SendText(Chr(C_ESC)$"[D"$tmp$Chr(C_ESC)$"[K");
			//if (Len(tmp) > 0) SendText(Chr(C_ESC)$"["$string(Len(tmp))$"D");
		}
		return true;
	}
	return false;
}

/** perform a delete on the commandline */
function bool cmdLineDelete()
{
	local string tmp;
	if (cursorpos[0]-cursorpos[2] < Len(inbuffer))
	{
		tmp = Mid(inbuffer, cursorpos[0]-cursorpos[2]+1);
		inbuffer = Left(inbuffer, cursorpos[0]-cursorpos[2])$tmp;
		if (bEcho) SendText(Chr(C_ESC)$"[P");
		return true;
	}
	return false;
}

/** initial state */
auto state init
{
	function Timer()
	{
		GotoState('login');
	}
}

/** logging in */
state login
{
	function procLogin(coerce string input)
	{
		if (sUsername == "")
		{
			sUsername = input;
			bEcho = false;
			SendText(msgPassword);
			if (sUsername == "") sUsername = Chr(1);
		}
		else {
			sPassword = input;
			bEcho = true;
			if (Interface.gateway.login(self, sUsername, sPassword, interface.ident))
			{
				GotoState('logged_in');
			}
			else {
				LoginTries++;
				sUsername = "";
				sPassword = "";
				SetTimer(fDelayWrongPassword, false);
				GotoState('login_failed');
			}
		}
	}

begin:
	OnReceiveBinary=defReceiveInput;
	OnReceiveLine=procLogin;
	OnEscapeCode=defProcEscape;
	OnLogout=none;
	OnTabComplete=none;
	SendText(msgUsername);
}

/** log in failed - delay */
state login_failed
{
	function Timer()
	{
		if (LoginTries >= iMaxLogin)
		{
			SendLine(msgTooManuLogins);
			Close();
			return;
		}
		SendLine(msgLoginFailed);
		SendLine();
		GotoState('login');
	}

begin:
	OnReceiveBinary=none;
	OnReceiveLine=none;
	OnEscapeCode=none;
	OnLogout=none;
	OnTabComplete=none;
}

/** logged in state */
state logged_in
{
	function procInput(coerce string input)
	{
		local array<string> cmd;
		if (AdvSplit(input, " ", cmd, "\"") == 0)
		{
			SendPrompt();
			return;
		}
		AddCommandHistory(input);
		if (!Interface.Gateway.ExecCommand(Self, cmd)) outputError(repl(msgUnknownCommand, "%command%", cmd[0]));
		SendPrompt(); // TODO: ommit prompt ?
	}

	function TryLogout()
	{
		if (!interface.gateway.CanClose(Self)) return;
		SendLine();
		Close();
	}

begin:
	OnReceiveBinary=defReceiveInput;
	OnReceiveLine=procInput;
	OnEscapeCode=defProcEscape;
	OnLogout=TryLogout;
	OnTabComplete=defTabComplete;
	IssueMessage();
	SendPrompt();
}

function output(string data)
{
	SendLine(data);
}

function outputError(string errormsg)
{
	SendLine(Chr(C_ESC)$"[1;31m"$errormsg$Chr(C_ESC)$"[0m");
}

defaultproperties
{
	CommandPrompt="%username%@%computername%:~$ "
	iMaxLogin=3
	fDelayInitial=0.0
	fDelayWrongPassword=5.0
	bDisableAuth=false

	msgUsername="Username: "
	msgPassword="Password: "
	msgLoginFailed="Login failed!"
	msgTooManuLogins="Too many login tries, goodbye!"
	msgUnknownCommand="Unknown command: %command%"
}
