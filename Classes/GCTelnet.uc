/*******************************************************************************
	GCTelnet																	<br />
	Telnet client, spawned from GITelnetd										<br />
	Note: the MS windows telnet client should use ANSI not VT100				<br />
	RFC: 318, 513, 764, 854, 855, 857, 858, 859, 884, 930, 1073, 1091, 1116,
	1572																		<br />
																				<br />
	Authors:	Michiel 'El Muerte' Hendriks &lt;elmuerte@drunksnipers.com&gt;	<br />
																				<br />
	Copyright 2003, 2004 Michiel "El Muerte" Hendriks							<br />
	Released under the Open Unreal Mod License									<br />
	http://wiki.beyondunreal.com/wiki/OpenUnrealModLicense						<br />
	<!-- $Id: GCTelnet.uc,v 1.13 2004/04/06 20:51:01 elmuerte Exp $	-->
*******************************************************************************/
class GCTelnet extends UnGatewayClient;

/** Telnet command: "Interpret as Command" */
const T_IAC			= 255;
/**
	Telnet command:
	Indicates the desire to begin performing, or confirmation that
	you are now performing, the indicated option
*/
const T_WILL		= 251;
/**
	Telnet command:
	Indicates the refusal to perform, or continue performing, the indicated option.
*/
const T_WONT		= 252;
/**
	Telnet command:
	Indicates the request that the other party perform, or
	confirmation that you are expecting the other party to perform, the
	indicated option.
*/
const T_DO			= 253;
/**
	Telnet command:
	Indicates the demand that the other party stop performing,
	or confirmation that you are no longer expecting the other party
	to perform, the indicated option.
*/
const T_DONT		= 254;
/**
	Telnet command:
	Indicates that what follows is subnegotiation of the indicated option
*/
const T_SB			= 250;
/** Telnet command: End of subnegotiation parameters */
const T_SE			= 240;
/** Telnet command: No operation. */
const T_NOP			= 241;

/**
	Telnet option:
	When the echoing option is in effect, the party at the end performing
	the echoing is expected to transmit (echo) data characters it
	receives back to the sender of the data characters.
*/
const O_ECHO		= 1;
/**
	Telnet option:
 	When the SUPPRESS-GO-AHEAD option is in effect on the connection
	between a sender of data and the receiver of the data, the sender
	need not transmit GAs.
*/
const O_SGOAHEAD	= 3;
/**
	Telnet option:
 	this option allows a telnet server to determine the type of terminal
	connected to a user telnet program.
*/
const O_TERMINAL	= 24;
/**
 	Telnet option:
 	Negotiate About Window Size
*/
const O_NAWS		= 31;

/** ASCII code: backspace */
const C_BS			= 8;
/** ASCII code: horizontal tab */
const C_TAB			= 9;
/** ASCII code: newline */
const C_NL			= 10;
/** ASCII code: carriage return */
const C_CR			= 13;
/** ASCII code: escape */
const C_ESC			= 27;
/** ASCII code: delete */
const C_DEL			= 127;

/** true -> echo input */
var bool bEcho;
/** command promp */
var string CommandPrompt;
/** maximum number of login tries before the connection will be closed */
var(Config) config int iMaxLogin;
/** initial delay before printing login request */
var(Config) config float fDelayInitial;
/** delay after an incorrect login */
var(Config) config float fDelayWrongPassword;
/**
	disable authentication, anonymous access allowed
	NEVER USE THIS, change the gateway's authentication class instead
*/
var(Config) config bool bDisableAuth;
/**
	when set to true the internal pager will be used if there's more output
	than there are lines available on the screen
*/
var(Config) config bool bEnablePager;

/** cursor position: x,y, init-x */
var protected int cursorpos[3];
/**
	busy processing special sequences, this is not completely supported
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
/** window size: x,y */
var protected int WindowSize[2];
/** terminal type string send */
var protected string TerminalType;
/** buffer used by the internal pager */
var protected array<string> PagerBuffer;
/** current line count for the pager */
var protected int PagerLineCount;
/** current offset in the pagers */
var protected int PagerOffset;

// localization
var localized string msgUsername, msgPassword, msgLoginFailed, msgTooManuLogins,
						msgUnknownCommand, msgPagerMore;

/** cursor key movements */
enum ECursorKey
{
	ECK_Up,
	ECK_Down,
	ECK_Left,
	ECK_Right,
	ECK_PageUp,
	ECK_PageDown,
	ECK_End,
	ECK_Home,
	ECK_Insert,
	ECK_Delete,
};

/** ANSI color codes, EC_Default is is the default color used for background or foreground */
enum EColor
{
	EC_None,
	EC_Black,
	EC_Red,
	EC_Green,
	EC_Brown,
	EC_Blue,
	EC_Magenta,
	EC_Cyan,
	EC_White,
	EC_Default,
};

/** tristate boolean value */
enum TriState
{
	TS_Unset,
	TS_False,
	TS_True,
};

/** structure containing formatting rules to be used with the Format function */
struct ConsoleFont
{
	var EColor Font;
	var EColor Background;
	/** 0 = unset, 1 = normal; 2 = half bright; 3 = bold */
	var byte Intensity;
	var TriState Blink;
	var TriState Underline;
	var TriState Reverse;
	/** don't reset the formatting at the end of the line */
	var bool NoReset;
	/** plain reset */
	var bool Reset;
};

/** called from defReceiveInput to handle escape codes */
delegate int OnEscapeCode(int pos, int Count, byte B[255])
{
	return 0;
}

/** called from defProcEscape when a cursor key is used */
delegate OnCursorKey(ECursorKey Key);

/** called from defProcEscape when a meta key is used: Alt+key or Esc+key */
delegate OnMetaKey(string key);

event Accepted()
{
	Super.Accepted();
	bEcho = true;

	// don't echo - server: WILL ECHO
	SendText(Chr(T_IAC)$Chr(T_WILL)$Chr(O_ECHO));
	// will supress go ahead
	SendText(Chr(T_IAC)$Chr(T_WILL)$Chr(O_SGOAHEAD));
	// send window size and changes
	SendText(Chr(T_IAC)$Chr(T_DO)$Chr(O_NAWS));
	// send terminal type
	SendText(Chr(T_IAC)$Chr(T_DO)$Chr(O_TERMINAL));
	// request terminal type
	SendText(Chr(T_IAC)$Chr(T_SB)$Chr(O_TERMINAL)$Chr(1)$Chr(T_IAC)$Chr(T_SE));

	WindowSize[0] = 80;
	WindowSize[1] = 25;

	if (bDisableAuth)
	{
		sUsername = "anonymous";
		IssueMessage();
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
	Default input handler.
	Will catch telnet control sequences and buffer the input
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
			defCursorKey(ECK_Home);
		}
		else if (B[i] == 5) // ^E, end of line
		{
			defCursorKey(ECK_End);
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
						OnCursorKey(ECK_Up);
						break;
			case 66:	length++; // B=Down
						OnCursorKey(ECK_Down);
						break;
			case 67:	length++; // C=Right
						if (v1 == 0) v1++;
						while (v1 > 0)
						{
							OnCursorKey(ECK_Right);
							v1--;
						}
						break;
			case 68:	length++; // D=Left
						if (v1 == 0) v1++;
						while (v1 > 0)
						{
							OnCursorKey(ECK_Left);
							v1--;
						}
						break;
			case 126:	length++;
						switch (v1)
						{
							case 1: OnCursorKey(ECK_Home); break;
							case 2: OnCursorKey(ECK_Insert); break;
							case 3: OnCursorKey(ECK_Delete); break;
							case 4: OnCursorKey(ECK_End); break;
							case 5: OnCursorKey(ECK_PageUp); break;
							case 6: OnCursorKey(ECK_PageDown); break;
							default: interface.gateway.Logf("[defProcEscape] unknown function key:"@v1@v2, Name, interface.gateway.LOG_DEBUG);
						}
						break;
			default:	interface.gateway.Logf("[defProcEscape] Unhandled escape code:"@B[pos], Name, interface.gateway.LOG_DEBUG);
		}
	}
	else if (B[pos] > 31 && B[pos] < 127)
	{
		length++;
		OnMetaKey(Chr(B[pos]));
		interface.gateway.Logf("[defProcEscape] 'Alt+"$Chr(B[pos])$"'", Name, interface.gateway.LOG_DEBUG);
	}
	bProcEsc = false;
	return length;
}

/** default cursor handling handling routine */
function defCursorKey(ECursorKey key)
{
	switch (key)
	{
		case ECK_Up:		DisplayCommandHistory(1);
							break;
		case ECK_Down:		DisplayCommandHistory(-1);
							break;
		case ECK_Left:		if (cursorpos[0] > cursorpos[2])
							{
								cursorpos[0] -= 1;
								SendText(Chr(C_ESC)$"[1D");
							}
							break;
		case ECK_Right:		if (cursorpos[0] < Len(inbuffer)+cursorpos[2])
							{
								cursorpos[0] += 1;
								SendText(Chr(C_ESC)$"[1C");
							}
							break;
		case ECK_End:		if (cursorpos[0] < Len(inbuffer)+cursorpos[2])
							{
								if (bEcho) SendText(Chr(C_ESC)$"["$string(Len(inbuffer)-(cursorpos[0]-cursorpos[2]))$"C");
								cursorpos[0] = Len(inbuffer)+cursorpos[2];
							}
							break;
		case ECK_Home:		if (cursorpos[0] > cursorpos[2])
							{
								if (bEcho) SendText(Chr(C_ESC)$"["$string(cursorpos[0]-cursorpos[2])$"D");
								cursorpos[0] = cursorpos[2];
							}
							break;
		case ECK_Delete:	if (!cmdLineBackspace()) Bell();
							break;
	}
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
		}
		else {
			Interface.gateway.Logf("Tab completion for"@cmd[0]@":"@cmd.length@"items", Name, Interface.gateway.LOG_DEBUG);
		}

		if (completion.length == 0)
		{
			Bell();
		}
		else if (completion.Length == 1)
		{
			tmp = Mid(completion[0], sz)$" ";
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
}

/** set the cursor to possition x,y */
function SetCursor(int x, int y)
{
	SendText(Chr(C_ESC)$"["$string(y)$";"$string(x)$"H");
}

/** sendtext and append newline */
function SendLine(optional coerce string line)
{
	SendText(line$Chr(C_CR)$chr(C_NL));
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
		case T_WILL:	Interface.gateway.Logf("WILL"@B[pos+1], Name, Interface.gateway.LOG_DEBUG);
						length += 2;
						break;
		case T_WONT:	Interface.gateway.Logf("WONT"@B[pos+1], Name, Interface.gateway.LOG_DEBUG);
						length += 2;
						break;
		case T_DO:		Interface.gateway.Logf("DO"@B[pos+1], Name, Interface.gateway.LOG_DEBUG);
						length += 2;
						break;
		case T_DONT:	Interface.gateway.Logf("DONT"@B[pos+1], Name, Interface.gateway.LOG_DEBUG);
						length += 2;
						break;
		case T_SB:		Interface.gateway.Logf("SB", Name, Interface.gateway.LOG_DEBUG);
						length++;
						pos++;
						length += ProcTelnetSubNegotiation(pos, count, b);
						break;
		case T_NOP:		length++;
						break;
	}
	bProcTelnet = false;
	return length;
}

/** telnet subnegotiation (SB) */
function int ProcTelnetSubNegotiation( int pos, int Count, byte B[255] )
{
	local int length;

	length = 0;
	switch (B[pos])
	{
		case O_NAWS:		// window size
					windowsize[0] = B[++pos]*256+B[++pos];
					windowsize[1] = B[++pos]*256+B[++pos];
					pos += 2;
					length = 6;  // last is T_IAC
					Interface.gateway.Logf("Window size ="@windowsize[0]@"x"@windowsize[1], Name, Interface.gateway.LOG_DEBUG);
					break;
		case O_TERMINAL:	// terminal type
					pos += 2; // O_.. + 0x00
					length += 2;
					TerminalType = "";
					while (B[pos] != T_IAC)
					{
						TerminalType $= chr(B[pos]);
						pos++;
						length++;
					}
					pos++;
					length++;
					Interface.gateway.Logf("Terminal type ="@TerminalType, Name, Interface.gateway.LOG_DEBUG);
					break;

	}
	while (B[pos] != T_SE)
	{
		Interface.gateway.Logf("SB: "@B[pos], Name, Interface.gateway.LOG_DEBUG);
		length++;
		pos++;
		if (pos > Count) return length;
	}
	length++;
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

/** clear and reset the current (actually last) line */
function ClearResetLine()
{
	//SendText(Chr(C_ESC)$"[1G"$Chr(C_ESC)$"[2K"); // this doesn't work with the Windows Telnet Client
	SendText(Chr(C_ESC)$"[2K"$Chr(C_ESC)$"["$WindowSize[1]$";1H");
}

/**
	add color coding to a string. this is pretty slow, it's better to use hardcoded
	strings when you don't need to set it dynamically.
*/
static function string Format(string line, ConsoleFont font)
{
	local string code;
	if (font.Font != EC_None)
	{
		if (font.Font == EC_Default)
		{
			if (font.Underline == TS_True) code = "38";
			else if (font.Underline == TS_False) code = "39";
		}
		else code = string(font.Font+29);
	}
	if (font.Background != EC_None)
	{
		if (code != "") code $= ";";
		code $= string(font.Background+39);
	}
	if (font.Intensity > 0)
	{
		if (code != "") code $= ";";
		switch (font.Intensity)
		{
			case 1: code $= "22"; break;
			case 2: code $= "2"; break;
			case 3: code $= "1"; break;
		}
	}
	if (font.Underline != TS_Unset)
	{
		if (code != "") code $= ";";
		if (font.Underline == TS_True) code $= "4";
		else code $= "24";
	}
	if (font.Blink != TS_Unset)
	{
		if (code != "") code $= ";";
		if (font.Blink == TS_True) code $= "5";
		else code $= "25";
	}
	if (font.Reverse != TS_Unset)
	{
		if (code != "") code $= ";";
		if (font.Reverse == TS_True) code $= "7";
		else code $= "27";
	}
	if (font.Reset)
	{
		if (code != "") code $= ";";
		code $= "0";
	}
	if (font.NoReset) return Chr(C_ESC)$"["$code$"m"$line;
	else return Chr(C_ESC)$"["$code$"m"$line$Chr(C_ESC)$"[0m";
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
	if (Interface.CVSversion != "") SendLine(Interface.CVSversion);
	if (CVSversion != "") SendLine(CVSversion);
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
				IssueMessage();
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
	OnCursorKey=defCursorKey;
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
	OnCursorKey=none;
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
		if (bEnablePager)
		{
			PagerLineCount = 0;
			PagerBuffer.length = 0;
		}
		if (!Interface.Gateway.ExecCommand(Self, cmd)) outputError(repl(msgUnknownCommand, "%command%", cmd[0]));
		if (!IsInState('paged') && !IsInState('logout')) SendPrompt();
	}

	function TryLogout()
	{
		if (!interface.gateway.CanClose(Self)) return;
		GotoState('logout');
		SendLine();
		SendLine("Goodbye!");
		Close();
	}

begin:
	OnReceiveBinary=defReceiveInput;
	OnReceiveLine=procInput;
	OnEscapeCode=defProcEscape;
	OnCursorKey=defCursorKey;
	OnLogout=TryLogout;
	OnTabComplete=defTabComplete;
	SendPrompt();
}

/**
	internal pager
*/
state paged
{
	/** pager uses only a few keys */
	function PagerReceiveInput(int Count, byte B[255])
	{
		local int i;
		i = 0;
		if (bProcEsc) i += OnEscapeCode(i, count, B);
		for (i = i; i < count; i++)
		{
			switch (B[i])
			{
				case C_ESC:	i += OnEscapeCode(i+1, count, B);
							break;
				case 3:		// ^C q Q
				case 113:
				case 81:	ClearResetLine();
							PagerBuffer.length = 0;
							GotoState('logged_in');
							break;
				case 13:	PagerScroll(1); // one line
							break;
				case 32:	PagerScroll(WindowSize[1]); // one page
							break;
			}
		}
	}

	/** OnCursorKey delegate for the pager mode */
	function PagerCursor(ECursorKey key)
	{
		switch (key)
		{
			case ECK_Up:		PagerScroll(-1);
								break;
			case ECK_Down:		PagerScroll(1);
								break;
			case ECK_PageUp:	PagerScroll(-(WindowSize[1]-1));
								break;
			case ECK_PageDown:	PagerScroll(WindowSize[1]-1);
								break;
			case ECK_Home:		PagerScroll(-PagerBuffer.Length);
								break;
			case ECK_End:		PagerScroll(PagerBuffer.Length);
								break;
		}
	}

	/** scroll the pager a couple of lines */
	function PagerScroll(int lines)
	{
		local int i, OldOffset;
		OldOffset = PagerOffset;
		PagerOffset = clamp(PagerOffset+lines, 0, PagerBuffer.Length-WindowSize[1]+1);
		lines = clamp(PagerOffset-OldOffset, -(WindowSize[1]-1), WindowSize[1]-1);
		if (lines == 0)
		{
			Bell();
			return;
		}
		else if (lines > 0)
		{
			ClearResetLine();
			for (i = WindowSize[1]+PagerOffset-lines-1; i < WindowSize[1]+PagerOffset-1; i++)
			{
				SendLine(PagerBuffer[i]);
			}
			PagerStatus(i-1);
		}
		else if (lines < 0)
		{
			lines = lines*-1;
			SendText(chr(27)$"[1;1H"$chr(27)$"["$string(lines)$"L");
			for (i = PagerOffset; i < PagerOffset+lines; i++)
			{
				SendLine(PagerBuffer[i]);
			}
			SendText(chr(27)$"["$(WindowSize[1])$";1H");
			PagerStatus(PagerOffset+WindowSize[1]-2);
		}
	}

	/** show the pager status line at the current cursor location */
	function PagerStatus(int position)
	{
		local string tmp;
		tmp = repl(msgPagerMore, "%begin%", string(PagerOffset+1));
		tmp = repl(tmp, "%end%", string(position+1));
		tmp = repl(tmp, "%percent%", string((position+1)*100/PagerBuffer.Length));
		SendText(Chr(C_ESC)$"[7m"$tmp$Chr(C_ESC)$"[0m"$Chr(C_ESC)$"[K");
	}

begin:
	OnReceiveBinary=PagerReceiveInput;
	OnReceiveLine=none;
	OnEscapeCode=defProcEscape;
	OnCursorKey=PagerCursor;
	OnLogout=none;
	OnTabComplete=none;
	PagerOffset = 0;
	PagerStatus(WindowSize[1]-2);
}

state logout
{
begin:
	OnReceiveBinary=none;
	OnReceiveLine=none;
	OnEscapeCode=none;
	OnCursorKey=none;
	OnLogout=none;
	OnTabComplete=none;
}

/**
	send data to the client, if the pager is enabled it will automatically page
	the data when there's more data than can fit on the screen
*/
function output(string data)
{
	if (!bEnablePager) SendLine(data);
	else {
		PagerBuffer.length = PagerBuffer.length+1;
		PagerBuffer[PagerBuffer.length-1] = data;
		if (PagerLineCount < (WindowSize[1]-1))
		{
			SendLine(data);
			PagerLineCount++;
		}
		else {
			if (!IsInState('paged')) GotoState('paged');
		}
	}
}

/**
	send an error
*/
function outputError(string errormsg)
{
	SendLine(Chr(C_ESC)$"[1;31m"$errormsg$Chr(C_ESC)$"[0m");
}

defaultproperties
{
	CVSversion="$Id: GCTelnet.uc,v 1.13 2004/04/06 20:51:01 elmuerte Exp $"
	CommandPrompt="%username%@%computername%:~$ "
	iMaxLogin=3
	fDelayInitial=0.0
	fDelayWrongPassword=5.0
	bDisableAuth=false
	bEnablePager=true

	msgUsername="Username: "
	msgPassword="Password: "
	msgLoginFailed="Login failed!"
	msgTooManuLogins="Too many login tries, goodbye!"
	msgUnknownCommand="Unknown command: %command%"
	msgPagerMore="pager: %begin% - %end% (%percent%%)";
}
