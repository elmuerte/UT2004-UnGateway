/*******************************************************************************
    GCTelnet                                                                    <br />
    Telnet client, spawned from GITelnetd                                       <br />
    Note: the MS windows telnet client should use ANSI not VT100                <br />
    RFC: 318, 513, 764, 854, 855, 857, 858, 859, 884, 930, 1073, 1091, 1116,
    1572                                                                        <br />
                                                                                <br />
    Authors:    Michiel 'El Muerte' Hendriks &lt;elmuerte@drunksnipers.com&gt;  <br />
                                                                                <br />
    Copyright 2003, 2004 Michiel "El Muerte" Hendriks                           <br />
    Released under the Open Unreal Mod License                                  <br />
    http://wiki.beyondunreal.com/wiki/OpenUnrealModLicense
    <!-- $Id: GCTelnet.uc,v 1.32 2004/10/20 14:08:47 elmuerte Exp $ -->
*******************************************************************************/
/*
    TODO:
    - handle line overflow, redraw partial line
*/
class GCTelnet extends UnGatewayClient config;

/** Telnet command: "Interpret as Command" */
const T_IAC         = 255;
/**
    Telnet command:
    Indicates the desire to begin performing, or confirmation that
    you are now performing, the indicated option
*/
const T_WILL        = 251;
/**
    Telnet command:
    Indicates the refusal to perform, or continue performing, the indicated option.
*/
const T_WONT        = 252;
/**
    Telnet command:
    Indicates the request that the other party perform, or
    confirmation that you are expecting the other party to perform, the
    indicated option.
*/
const T_DO          = 253;
/**
    Telnet command:
    Indicates the demand that the other party stop performing,
    or confirmation that you are no longer expecting the other party
    to perform, the indicated option.
*/
const T_DONT        = 254;
/**
    Telnet command:
    Indicates that what follows is subnegotiation of the indicated option
*/
const T_SB          = 250;
/** Telnet command: End of subnegotiation parameters */
const T_SE          = 240;
/** Telnet command: No operation. */
const T_NOP         = 241;

/**
    Telnet option:
    When the echoing option is in effect, the party at the end performing
    the echoing is expected to transmit (echo) data characters it
    receives back to the sender of the data characters.
*/
const O_ECHO        = 1;
/**
    Telnet option:
    When the SUPPRESS-GO-AHEAD option is in effect on the connection
    between a sender of data and the receiver of the data, the sender
    need not transmit GAs.
*/
const O_SGOAHEAD    = 3;
/**
    Telnet option:
    this option allows a telnet server to determine the type of terminal
    connected to a user telnet program.
*/
const O_TERMINAL    = 24;
/**
    Telnet option:
    Negotiate About Window Size
*/
const O_NAWS        = 31;

/** ASCII code: backspace */
const C_BS          = 8;
/** ASCII code: horizontal tab */
const C_TAB         = 9;
/** ASCII code: newline */
const C_NL          = 10;
/** ASCII code: carriage return */
const C_CR          = 13;
/** ASCII code: escape */
const C_ESC         = 27;
/** ASCII code: delete */
const C_DEL         = 127;

/** true -> echo input */
var bool bEcho;
/** command promp */
var(Config) config string CommandPrompt;
/** Show the message of the day on login */
var(Config) config bool bShowMotd;
/** Message of the Day */
var(Config) config array<string> MOTD;
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
/**
    If set to true the history of the logged in user will be saved when the
    connection is closed. This feature adds some useless overhead thus is disabled
    by default.
*/
var(Config) config bool bSaveHistory;
/** the command history class to use */
var(Config) config string CommandHistoryClass;

/**
    chat mode, CM_Disabled by default. CM_Full, the messages will be printed in
    the terminal and everything typed will be a message. CM_Partial, top few
    lines are reserved for chatting input is only a messages when prefixed
 */
var(Config) config enum EChatMode
{
    CM_Disabled,
    CM_Full,
    CM_Partial,
} ChatMode;

/** cursor position: x,y, init-x, init-y */
var protected int cursorpos[4];
/**
    busy processing special sequences, this is not completely supported
*/
var bool bProcEsc, bProcTelnet;

/** command history (reversed order) */
var array<string> CommandHistory, tmpCmdHist;
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
/** window size: x,y, top line, window size */
var protected int WindowSize[4];
/** terminal type string send */
var protected string TerminalType;
/** buffer used by the internal pager */
var protected array<string> PagerBuffer;
/** current line count for the pager */
var protected int PagerLineCount;
/** current offset in the pagers */
var protected int PagerOffset;
/** the partial chat history to draw */
var protected array<string> PartialChatHist;

// localization
var localized string msgUsername, msgPassword, msgLoginFailed, msgTooManuLogins,
                        msgUnknownCommand, msgPagerMore, msgFullChatMode;

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

var localized string PICat, PILabel[11], PIDescription[11], PIData[2];

/** called from defReceiveInput to handle escape codes */
delegate int OnEscapeCode(int pos, int Count, byte B[255])
{
    return 0;
}

/** called from defProcEscape when a cursor key is used */
delegate OnCursorKey(ECursorKey Key);

/** called from defProcEscape when a meta key is used: Alt+key or Esc+key */
delegate OnMetaKey(string key);

/** called when the user presses a newline, return true to echo the newline */
delegate bool OnNewline()
{
    return true;
}

function Initialized()
{
    Super.Initialized();
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
    WindowSize[2] = 1;
    WindowSize[3] = WindowSize[1];

    if (bDisableAuth)
    {
        sUsername = "anonymous";
        IssueMessage();
        Interface.gateway.NotifyClientJoin(self);
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

event Closed()
{
    if (bSaveHistory) SaveHistory();
    super.Closed();
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
            if (OnNewline())
            {
                SendLine(); // send a newline
            }
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
            case 65:    length++; // A=Up
                        OnCursorKey(ECK_Up);
                        break;
            case 66:    length++; // B=Down
                        OnCursorKey(ECK_Down);
                        break;
            case 67:    length++; // C=Right
                        if (v1 == 0) v1++;
                        while (v1 > 0)
                        {
                            OnCursorKey(ECK_Right);
                            v1--;
                        }
                        break;
            case 68:    length++; // D=Left
                        if (v1 == 0) v1++;
                        while (v1 > 0)
                        {
                            OnCursorKey(ECK_Left);
                            v1--;
                        }
                        break;
            case 126:   length++;
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
            default:    interface.gateway.Logf("[defProcEscape] Unhandled escape code:"@B[pos], Name, interface.gateway.LOG_DEBUG);
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
        case ECK_Up:        DisplayCommandHistory(1);
                            break;
        case ECK_Down:      DisplayCommandHistory(-1);
                            break;
        case ECK_Left:      if (cursorpos[0] > cursorpos[2])
                            {
                                cursorpos[0] -= 1;
                                SendText(Chr(C_ESC)$"[1D");
                            }
                            break;
        case ECK_Right:     if (cursorpos[0] < Len(inbuffer)+cursorpos[2])
                            {
                                cursorpos[0] += 1;
                                SendText(Chr(C_ESC)$"[1C");
                            }
                            break;
        case ECK_End:       if (cursorpos[0] < Len(inbuffer)+cursorpos[2])
                            {
                                if (bEcho) SendText(Chr(C_ESC)$"["$string(Len(inbuffer)-(cursorpos[0]-cursorpos[2]))$"C");
                                cursorpos[0] = Len(inbuffer)+cursorpos[2];
                            }
                            break;
        case ECK_Home:      if (cursorpos[0] > cursorpos[2])
                            {
                                if (bEcho) SendText(Chr(C_ESC)$"["$string(cursorpos[0]-cursorpos[2])$"D");
                                cursorpos[0] = cursorpos[2];
                            }
                            break;
        case ECK_Delete:    if (!cmdLineBackspace()) Bell();
                            break;
    }
}

/** perform tab completion */
function defTabComplete()
{
    local array<string> cmd, completion;
    local int i, sz;
    local string tmp;
    local bool midcompl;

    tmp = Left(inbuffer, cursorpos[0]-cursorpos[2]);
    if (tmp == "") Bell();
    else if (AdvSplit(tmp, " ", cmd, "\"") == 0) Bell();
    else {
        // find first matching command
        //log(inbuffer@cursorpos[0]@cursorpos[2]@cmd.length@cmd[0]@InStr(inbuffer, " "));
        midcompl = cursorpos[0]-cursorpos[2] < Len(inbuffer);
        if (cmd.length == 1)
        {
            sz = Len(tmp);
            for (i = 0; i < Interface.gateway.CmdLookupTable.Length; i++)
            {
                if (Left(Interface.gateway.CmdLookupTable[i].Command, sz) ~= tmp)
                {
                    completion.length = completion.length + 1;
                    completion[completion.Length-1] = Interface.gateway.CmdLookupTable[i].Command;
                }
            }
            for (i = 0; i < Interface.gateway.CmdAliases.Length; i++)
            {
                if (Left(Interface.gateway.CmdAliases[i].Alias, sz) ~= tmp)
                {
                    completion.length = completion.length + 1;
                    completion[completion.Length-1] = Interface.gateway.CmdAliases[i].Alias;
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
            tmp = Mid(completion[0], sz);
            if (!midcompl) tmp $= " ";
            else tmp @= Mid(inbuffer, sz);
            inbuffer = Left(inbuffer, sz)$tmp;
            SendText(tmp);
            cursorpos[0] += Len(tmp);
        }
        else {
            tmp = Mid(class'wArray'.static.GetCommonBegin(completion), sz);
            if (tmp != "")
            {
                if (midcompl) tmp @= Mid(inbuffer, sz);
                inbuffer = Left(inbuffer, sz)$tmp;
                SendText(tmp);
                cursorpos[0] += Len(tmp);
                Bell();
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
}

/** set the cursor to possition x,y */
function SetCursor(int x, int y)
{
    SendText(Chr(C_ESC)$"["$string(y)$";"$string(x)$"H");
}

/** sendtext and append newline */
function SendLine(optional coerce string line)
{
    cursorpos[1] = min(WindowSize[1], cursorpos[1]+1);
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
        case T_WILL:    Interface.gateway.Logf("WILL"@B[pos+1], Name, Interface.gateway.LOG_DEBUG);
                        length += 2;
                        break;
        case T_WONT:    Interface.gateway.Logf("WONT"@B[pos+1], Name, Interface.gateway.LOG_DEBUG);
                        length += 2;
                        break;
        case T_DO:      Interface.gateway.Logf("DO"@B[pos+1], Name, Interface.gateway.LOG_DEBUG);
                        length += 2;
                        break;
        case T_DONT:    Interface.gateway.Logf("DONT"@B[pos+1], Name, Interface.gateway.LOG_DEBUG);
                        length += 2;
                        break;
        case T_SB:      Interface.gateway.Logf("SB", Name, Interface.gateway.LOG_DEBUG);
                        length++;
                        pos++;
                        length += ProcTelnetSubNegotiation(pos, count, b);
                        break;
        case T_NOP:     length++;
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
        case O_NAWS:        // window size
                    windowsize[0] = B[++pos]*256+B[++pos];
                    windowsize[1] = B[++pos]*256+B[++pos];
                    WindowSize[3] = WindowSize[1];
                    pos += 2;
                    length = 6;  // last is T_IAC
                    Interface.gateway.Logf("Window size ="@windowsize[0]@"x"@windowsize[1], Name, Interface.gateway.LOG_DEBUG);
                    break;
        case O_TERMINAL:    // terminal type
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
    SetCursor(1, cursorpos[1]);
    SendText(line);
    cursorpos[0] = Len(line)+1;
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

/** set autowrapping on or off */
function Autowrap(optional bool bOn)
{
    if (bOn) SendText(Chr(C_ESC)$"[?7h");
    else SendText(Chr(C_ESC)$"[?7l");
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

/** save the command history of this user */
function SaveHistory()
{
    local class<TelnetCommandHistory> histclass;
    local TelnetCommandHistory hist;
    if (sUsername == "") return;
    histclass = class<TelnetCommandHistory>(DynamicLoadObject(CommandHistoryClass, class'Class'));
    if (histclass == none)
    {
        interface.gateway.Logf("Failed to save command history, invalid history class:"@CommandHistoryClass, Name, interface.gateway.LOG_ERR);
        return;
    }
    hist = new(None,repl(sUsername, " ", Chr(C_ESC))) histclass;
    if (IsInState('FullChatMode')) hist.History = tmpCmdHist;
    else hist.History = CommandHistory;
    hist.SaveConfig();
}

/** load the command history of this user */
function LoadHistory()
{
    local class<TelnetCommandHistory> histclass;
    local TelnetCommandHistory hist;
    if (sUsername == "") return;
    histclass = class<TelnetCommandHistory>(DynamicLoadObject(CommandHistoryClass, class'Class'));
    if (histclass == none)
    {
        interface.gateway.Logf("Failed to load command history, invalid history class:"@CommandHistoryClass, Name, interface.gateway.LOG_ERR);
        return;
    }
    hist = new(None,repl(sUsername, " ", Chr(C_ESC))) histclass;
    CommandHistory = hist.History;
    CurHisIndex = -1;
}

/** display the issue message */
function IssueMessage()
{
    local int i;
    SendLine();
    SendLine("UnrealEngine2/"$Level.EngineVersion@Interface.gateway.Ident@Interface.Ident@Interface.gateway.ComputerName@Interface.Gateway.CreationTime);
    if (Interface.gateway.CVSversion != "") SendLine(Interface.gateway.CVSversion);
    if (Interface.CVSversion != "") SendLine(Interface.CVSversion);
    if (CVSversion != "") SendLine(CVSversion);
    if (bShowMotd)
    {
        for (i = 0; i < MOTD.length; i++)
        {
            SendLine(MOTD[i]);
        }
    }
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
        if (bEcho)
        {
            if (cursorpos[0] < windowsize[0]+1) SendText(Chr(C_ESC)$"[D"$Chr(C_ESC)$"[P");
            if (cursorpos[0] == windowsize[0]+1) SendText(Chr(C_ESC)$"[P");
            //SendText(Chr(C_ESC)$"[D"$tmp$Chr(C_ESC)$"[K");
            //if (Len(tmp) > 0) SendText(Chr(C_ESC)$"["$string(Len(tmp))$"D");
        }
        cursorpos[0]--;
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
            cursorpos[1] = min(WindowSize[1], cursorpos[1]+1);
            sUsername = input;
            bEcho = false;
            SendText(msgPassword);
            if (sUsername == "") sUsername = Chr(1);
        }
        else {
            cursorpos[1] = min(WindowSize[1], cursorpos[1]+1);
            sPassword = input;
            bEcho = true;
            if (Interface.gateway.login(self, sUsername, sPassword, interface.ident))
            {
                IssueMessage();
                PlayerController.SetName(sUsername);
                if (bSaveHistory) LoadHistory();

                Interface.gateway.NotifyClientJoin(self);
                if (ChatMode == CM_Full) GotoState('FullChatMode');
                else GotoState('logged_in');
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
    OnNewline=none;
    OnMetaKey=none;
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
    OnMetaKey=none;
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
        if (!IsInState('paged') && !IsInState('logout') && !IsInState('RequestedInput')) SendPrompt();
    }

    function TryLogout()
    {
        if (!interface.gateway.CanClose(Self))
        {
            SendPrompt();
            return;
        }
        GotoState('logout');
        SendLine();
        SendLine("Goodbye!");
        Close();
    }

    function procMeta(string key)
    {
        local int i;
        if (key == "C") // full chat
        {
            if (inbuffer == "")
            {
                if (ChatMode == CM_Partial)
                {
                    procMeta("c");
                }
                SendLine();
                ChatMode = CM_Full;
                GotoState('FullChatMode');
            }
            else Bell();
        }
        else if (key == "c") //partial chat
        {
            if (ChatMode == CM_Disabled)
            {
                PartialChatHist.length = 0;
                ChatMode = CM_Partial;
                for (i = 1; i < 6; i++)
                {
                    SetCursor(1,i);
                    SendText(Chr(C_ESC)$"[K");
                }
                WindowSize[2] = 5;
                WindowSize[3] = WindowSize[1]-WindowSize[2];
                SendText(Chr(C_ESC)$"[6;"$(WindowSize[1])$"r");
                SetCursor(cursorpos[0], cursorpos[1]);
            }
            else {
                WindowSize[3] = WindowSize[1];
                WindowSize[2] = 1;
                SendText(Chr(C_ESC)$"[1;"$(WindowSize[1])$"r");
                SetCursor(cursorpos[0], cursorpos[1]);
                ChatMode = CM_Disabled;
            }
        }
    }

begin:
    OnReceiveBinary=defReceiveInput;
    OnReceiveLine=procInput;
    OnEscapeCode=defProcEscape;
    OnCursorKey=defCursorKey;
    OnLogout=TryLogout;
    OnTabComplete=defTabComplete;
    OnNewline=none;
    OnMetaKey=procMeta;
    Autowrap(false);
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
                case C_ESC: i += OnEscapeCode(i+1, count, B);
                            break;
                case 3:     // ^C q Q
                case 113:
                case 81:    ClearResetLine();
                            PagerBuffer.length = 0;
                            PagerOffset = 0;
                            PagerLineCount = 0;
                            GotoState('logged_in');
                            break;
                case 13:    PagerScroll(1); // one line
                            break;
                case 32:    PagerScroll(WindowSize[3]-1); // one page
                            break;
            }
        }
    }

    /** OnCursorKey delegate for the pager mode */
    function PagerCursor(ECursorKey key)
    {
        switch (key)
        {
            case ECK_Up:        PagerScroll(-1);
                                break;
            case ECK_Down:      PagerScroll(1);
                                break;
            case ECK_PageUp:    PagerScroll(-(WindowSize[3]-1));
                                break;
            case ECK_PageDown:  PagerScroll(WindowSize[3]-1);
                                break;
            case ECK_Home:      PagerScroll(-PagerBuffer.Length);
                                break;
            case ECK_End:       PagerScroll(PagerBuffer.Length);
                                break;
        }
    }

    /** scroll the pager a couple of lines */
    function PagerScroll(int lines)
    {
        local int i, OldOffset;
        OldOffset = PagerOffset;
        PagerOffset = clamp(PagerOffset+lines, 0, PagerBuffer.Length-WindowSize[3]+1);
        lines = clamp(PagerOffset-OldOffset, -(WindowSize[3]-1), WindowSize[3]-1);
        if (lines == 0)
        {
            Bell();
            return;
        }
        else if (lines > 0)
        {
            ClearResetLine();
            for (i = WindowSize[3]+PagerOffset-lines-1; i < WindowSize[3]+PagerOffset-1; i++)
            {
                SendLine(PagerBuffer[i]);
            }
            PagerStatus(i-1);
        }
        else if (lines < 0)
        {
            lines = lines*-1;
            SendText(chr(27)$"["$(WindowSize[2])$";1H"$chr(27)$"["$string(lines)$"L");
            for (i = PagerOffset; i < PagerOffset+lines; i++)
            {
                SendLine(PagerBuffer[i]);
            }
            SendText(chr(27)$"["$(WindowSize[1])$";1H");
            PagerStatus(PagerOffset+WindowSize[3]-2);
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
    OnMetaKey=none;
    PagerOffset = 0;
    PagerStatus(WindowSize[3]-2);
}

state FullChatMode
{
    function procInput(coerce string input)
    {
        if (input == "") return;
        if (Left(input, 5) ~= "/quit")
        {
            ExitChatMode();
            return;
        }
        AddCommandHistory(input);
        inbuffer = ""; // pre-flush
        Level.Game.Broadcast(PlayerController, input, 'Say');
    }

    function bool procNewline()
    {
        if (cursorpos[0] > cursorpos[2])
        {
            SendText(Chr(C_ESC)$"["$string(cursorpos[0]-cursorpos[2])$"D");
            cursorpos[0] = cursorpos[2];
        }
        SendText(Chr(C_ESC)$"[K");
        return false;
    }

    function ExitChatMode()
    {
        CommandHistory=tmpCmdHist;
        SendLine();
        GotoState('logged_in');
    }

begin:
    OnReceiveBinary=defReceiveInput;
    OnReceiveLine=procInput;
    OnEscapeCode=defProcEscape;
    OnCursorKey=defCursorKey;
    OnLogout=ExitChatMode;
    OnTabComplete=none;
    OnNewline=procNewline;
    OnMetaKey=none;
    SendText(Chr(C_ESC)$"[44;37m");
    output(msgFullChatMode);
    SendText(Chr(C_ESC)$"[0m");
    tmpCmdHist=CommandHistory;
    CommandHistory.length = 0;
    CurHisIndex = -1;
    Autowrap(false);
    SendChatPrompt();
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

state RequestedInput
{
    function procInput(coerce string input)
    {
        OnRequestInputResult(self, input);
    }

begin:
    OnReceiveBinary=defReceiveInput;
    OnReceiveLine=procInput;
    OnEscapeCode=none;
    OnCursorKey=none;
    OnLogout=none;
    OnTabComplete=none;
    OnNewline=none;
    OnMetaKey=none;
}

/**
    send data to the client, if the pager is enabled it will automatically page
    the data when there's more data than can fit on the screen
*/
function output(coerce string data, optional string ident, optional bool bDontWrapFirst)
{
    local array<string> tmp;
    local int i;
    local string tmpdata;

    if (!bDontWrapFirst) tmpdata = ident;
    if (len(tmpdata$data) >= WindowSize[0]) // use smart wrapping with ident
    {
        if (split(data, " ", tmp) == 0)
        {
            // couldn't split
            internalOutput(ident$data);
            return;
        }
        tmpdata = "";
        for (i = 0; i < tmp.length; i++)
        {
            if (len(tmpdata@tmp[i]) >= WindowSize[0])
            {
                internalOutput(tmpdata);
                tmpdata = "";
            }
            if (tmpdata == "")
            {
                if (bDontWrapFirst && i == 0) tmpdata = tmp[i];
                else tmpdata = ident$tmp[i];
            }
            else tmpdata @= tmp[i];
        }
        if (tmpdata != "") internalOutput(tmpdata);
    }
    else internalOutput(tmpdata$data);
}

protected function internalOutput(coerce string data)
{
    if (!bEnablePager) SendLine(data);
    else if (IsInState('FullChatMode')) SendLine(data);
    else {
        PagerBuffer.length = PagerBuffer.length+1;
        PagerBuffer[PagerBuffer.length-1] = data;
        if (PagerLineCount < (WindowSize[3]-1))
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
function outputError(string errormsg, optional string ident, optional bool bDontWrapFirst)
{
    SendLine(Chr(C_ESC)$"[1;31m"$errormsg$Chr(C_ESC)$"[0m");
}

function outputChat(coerce string pname, coerce string message, optional name Type, optional PlayerReplicationInfo PC)
{
    if (ChatMode == CM_Disabled) return;
    if (ChatMode == CM_Full)
    {
        SetCursor(1, cursorpos[1]);
        Output("<"$pname$">"@message, "    ", true);
        SendChatPrompt(); // position is restored by the chat prompt
    }
    else if (ChatMode == CM_Partial)
    {
        drawPartialChat("<"$pname$">"@message);
    }
}

/** draw the partial chat window */
function drawPartialChat(string newline)
{
    //local array<string> tmp;
    local int i;

    PartialChatHist[PartialChatHist.Length] = newline;
    if (PartialChatHist.Length > WindowSize[2]) PartialChatHist.Remove(0, PartialChatHist.Length-WindowSize[2]);

    SendText(Chr(C_ESC)$"[1;34m"$Chr(C_ESC));
    SetCursor(1, WindowSize[2]);
    for (i = 0; i < PartialChatHist.length; i++)
    {
        SetCursor(1, WindowSize[2]-i);
        SendText(PartialChatHist[PartialChatHist.length-i-1]);
        SendText(Chr(C_ESC)$"[K");
    }
    SendText(Chr(C_ESC)$"[0m");
    SetCursor(cursorpos[0], cursorpos[1]);
}

/**
    send the special chat prompt, is bNoBuffer is added the current input buffer
    is not included
*/
function SendChatPrompt(optional bool bNoBuffer)
{
    local string line;
    SetCursor(1, WindowSize[1]);
    cursorpos[1] = WindowSize[1];
    line = "["$sUsername$"]";
    SendText(Chr(C_ESC)$"[44;37m"$line$Chr(C_ESC)$"[0m ");
    cursorpos[0] = Len(line)+1; // the additional space
    cursorpos[3] = WindowSize[1]; // set to last line
    cursorpos[2] = cursorpos[0]; // set init-x
    if (!bNoBuffer)
    {
        SendText(inbuffer);
        cursorpos[2] += Len(inbuffer);
    }
}

function requestInput(UnGatewayApplication app, optional coerce string Prompt, optional bool bNoEcho)
{
    super.requestInput(app, prompt, becho);
    if (prompt != "") SendText(prompt);
    bEcho = !bNoEcho;
    GotoState('RequestedInput');
}

function endRequestInput(UnGatewayApplication app)
{
    bEcho = true;
    OnRequestInputResult = none;
    GotoState('logged_in');
}

static function FillPlayInfo(PlayInfo PlayInfo)
{
    super.FillPlayInfo(PlayInfo);
    PlayInfo.AddSetting(default.PICat, "CommandPrompt",         default.PILabel[0], 128, 1, "Text", "256");
    PlayInfo.AddSetting(default.PICat, "bShowMotd",             default.PILabel[1], 128, 1, "Check");
    // adding MOTD crashes when it contains a lot of data
    //PlayInfo.AddSetting(default.PICat, "MOTD",                default.PILabel[2], 128, 1, "Text");
    PlayInfo.AddSetting(default.PICat, "iMaxLogin",             default.PILabel[3], 196, 1, "Text", "3;1:255");
    PlayInfo.AddSetting(default.PICat, "fDelayInitial",         default.PILabel[4], 196, 1, "Text", "10;0:65535");
    PlayInfo.AddSetting(default.PICat, "fDelayWrongPassword",   default.PILabel[5], 196, 1, "Text", "10;0:65535");
    PlayInfo.AddSetting(default.PICat, "bDisableAuth",          default.PILabel[6], 255, 255, "Check",,,,true);
    PlayInfo.AddSetting(default.PICat, "bEnablePager",          default.PILabel[7], 64, 1, "Check",,,,true);
    PlayInfo.AddSetting(default.PICat, "bSaveHistory",          default.PILabel[8], 64, 1, "Check");
    PlayInfo.AddSetting(default.PICat, "CommandHistoryClass",   default.PILabel[9], 128, 1, "Text", "256",,,true);
    PlayInfo.AddSetting(default.PICat, "ChatMode",              default.PILabel[10], 128, 1, "Select", default.PIData[0]);
}

static event string GetDescriptionText(string PropName)
{
    switch (PropName)
    {
        case "CommandPrompt":       return default.PIDescription[0];
        case "bShowMotd":           return default.PIDescription[1];
        case "MOTD":                return default.PIDescription[2];
        case "iMaxLogin":           return default.PIDescription[3];
        case "fDelayInitial":       return default.PIDescription[4];
        case "fDelayWrongPassword": return default.PIDescription[5];
        case "bDisableAuth":        return default.PIDescription[6];
        case "bEnablePager":        return default.PIDescription[7];
        case "bSaveHistory":        return default.PIDescription[8];
        case "CommandHistoryClass": return default.PIDescription[9];
        case "ChatMode":            return default.PIDescription[10];
    }
    return "";
}

defaultproperties
{
    CVSversion="$Id: GCTelnet.uc,v 1.32 2004/10/20 14:08:47 elmuerte Exp $"
    CommandPrompt="%username%@%computername%:~$ "
    iMaxLogin=3
    fDelayInitial=0.0
    fDelayWrongPassword=5.0
    bDisableAuth=false
    bEnablePager=true
    bSaveHistory=false
    CommandHistoryClass="UnGateway.TelnetCommandHistory"
    ChatMode=CM_Disabled

    msgUsername="Username: "
    msgPassword="Password: "
    msgLoginFailed="Login failed!"
    msgTooManuLogins="Too many login tries, goodbye!"
    msgUnknownCommand="Unknown command: %command%"
    msgPagerMore="pager: %begin% - %end% (%percent%%)"
    msgFullChatMode="-- You are now in chat mode, press Ctrl+D or /quit to leave chat mode --"

    PICat="Telnet"
    PILabel[0]="Command prompt"
    PIDescription[0]="The command prompt format. The following replacements can be used: %username%, %computername%, %hostname%, %hostaddress%, %clientaddress%"
    PILabel[1]="Show MOTD"
    PIDescription[1]="Show the message of the day"
    PILabel[2]="MOTD"
    PIDescription[2]="The Messsage Of The Day"
    PILabel[3]="Maximum login tries"
    PIDescription[3]="The maximum login tries before the connection is closed"
    PILabel[4]="Initial login delay"
    PIDescription[4]="the number of seconds to wait before the user can try to log in"
    PILabel[5]="Invalid login delay"
    PIDescription[5]="Number of seconds to wait before a user can try to log in again. this prevents brute forcing a password."
    PILabel[6]="Disable authentication"
    PIDescription[6]="Disable authentication completely. You should not do this, it will allow everybody to login without a username and password."
    PILabel[7]="Enable pager"
    PIDescription[7]="The pager is the automatic scroll feature that allows users to scroll up or down when a command output is more than could fit on the screen."
    PILabel[8]="Save history"
    PIDescription[8]="Save each user's command history to the UnGateway.ini file. This will add some useless overhead during login and logout."
    PILabel[9]="History class"
    PIDescription[9]="The class to spawn for saving\loading the command history"
    PILabel[10]="Chat mode"
    PIDescription[10]="The intial chat mode. With full chat mode everything the user enters will be a chat command. With partial chat only part of the screen is reserved for messages and only when the user uses the say command it will be considerd as a chat message."
    PIData[0]="CM_Disabled;Disabled;CM_Full;Full chat mode;CM_Partial;Partial chat mode"

    bShowMotd=true
    MOTD[0]=""
    MOTD[1]="[8m                               [0;10m[1m_a[0;10m[1mm_[0;10m[1m_d****[0;10m[1m0[0;10m[1m,[0;10m[1m_[0;10m[1ma_[0;10m[8m    [0;10m[1ms[0;10m[8m                 [0;10m"
    MOTD[2]="[8m                          [0;10m[1m_a[0;10mq[1mD[0;10m[1m5MQ[0;10m[1mx%x]][0;10m[1mMWZ44Gd[0;10m3[1m|![0;10m[1mm[0;10m[1m,[0;10m[8m [0;10m?[1m\[0;10m[1m_[0;10m,[8m             [0;10m"
    MOTD[3]="[8m                       [0;10m[1m__#dH![0;10m[1mq[0;10m[1mx]x[0;10m[1mMm[0;10m[1m%[0;10m[1mQNX[0;10m[1m=[0;10m[1mGXC[0;10m[1mqay*![0;10m[1mS[0;10m4[1mRy[0;10m[8m [0;10m?4[1mn[0;10m[1ms[0;10m[8m           [0;10m"
    MOTD[4]="[8m                    [0;10m_[1mp[0;10m[1m#W##UO[0;10mq[1m%[0;10m[1mMQ4QMMd[0;10m#[1mSQ[0;10m[1mnd##]+[0;10m|[1m=[0;10mU[1m=[0;10m3[1m?n[0;10m[8m  [0;10mN[1mdn[0;10m[8m          [0;10m"
    MOTD[5]="[8m                  [0;10m[1m_Jg#KWWWN&zy[0;10mH[1mH[0;10mXQQQ4[1may#H4WC[0;10m[1m\[0;10mXX44XO3*[1mL[0;10m[8m  [0;10m[1m*Gn[0;10m[1m,[0;10m[8m        [0;10m"
    MOTD[6]="[8m                 [0;10m[1mJm#K#QWWW44WX}[0;10mOX3OOC[1m##Z2%G%[0;10md2nxx%3[1m:[0;10m3[1m?[0;10m[1ml[0;10m[8m [0;10mJ[1mQWn[0;10m[8m        [0;10m"
    MOTD[7]="[8m               [0;10m[1m_4WQ?O[0;10m[8mN[0;10m+[1mm[0;10m[1m*WWWWZ[0;10m[1m1[0;10mO3][1m:[0;10m]%[1m0#KWWm3:[0;10m3X]q][1m=[0;10m[1m:[0;10m]=[1m1[0;10m[8m  [0;10m[1mWWX[0;10m[1m<[0;10m[8m       [0;10m"
    MOTD[8]="[8m           .  [0;10m[1m_G@\[0;10mCq[1myw[0;10m4C[1mWW&ZW3[0;10m[1m1[0;10m[1m:[0;10m3]%[1m==[0;10m[1m#4W8Z8%[0;10mx3[1m:[0;10m[1m==[0;10m|[1m=[0;10m+==[1mr[0;10m[8m  [0;10m[1m#U3[0;10m[1mb[0;10m[8m       [0;10m"
    MOTD[9]="[8m         [0;10m[1m_d[0;10m`[8m [0;10m[1m_GP~[0;10mq[1m|[0;10mN[1mg[0;10m[1m|[0;10mXH[1m#d$Qm2[0;10m[1m1[0;10m%]v[1m:[0;10mox[1m#4%[0;10m[1mB[0;10m[1mju%[0;10mx][1m==[0;10mx|[1m=[0;10m=;q[1ml[0;10m[8m [0;10m[1m_Z[0;10m[1m8[0;10m[1m-~[0;10m[8m       [0;10m"
    MOTD[10]="[8m      [0;10m[1m_[0;10m[8m [0;10m[1mdC[0;10m[1m<[0;10m[8m  [0;10m[1mVZ[0;10m+d[1mQ[0;10m#mXXXc[1m#[0;10m3[1mcu[0;10m[1m&N[0;10m[1m)[0;10m[1m=[0;10m%+%[1m=[0;10m%[1mWGxoGu][0;10m|]+====:;[1md[0;10m[8m  [0;10m[1mJ'[0;10m[1m`[0;10m[8m         [0;10m"
    MOTD[11]="[8m      [0;10m[1m4#9[0;10md[8m  [0;10m[1mj?[0;10mnOXXXO3V3[1m=[0;10m[1mBn[0;10m[1mMm[0;10m[1m]x[0;10m[1m1[0;10mxx[1m=[0;10m][1m=[0;10m;[1mW2W3yu%[0;10m=[1m=[0;10m=[1mv[0;10m:;:;[1mJ[0;10m[1m`[0;10m[8m  [0;10m[1m^[0;10m[8m           [0;10m"
    MOTD[12]="[8m      [0;10m4[1mX[0;10m[1mM[0;10m[1mx[0;10m[8m  [0;10m[1m?[0;10m[1mx[0;10mX3O33O33[1m:[0;10mx[1m&[0;10mH[1m2%]%[0;10m[1m{[0;10mx=+[1m==[0;10m][1mWA%Z23][0;10m==[1m`[0;10m=;:[1myW[0;10m`[8m               [0;10m"
    MOTD[13]="[8m      [0;10mJ[1mWk[0;10m[1mD[0;10m[8m  [0;10m[1mj[0;10m[1me[0;10mxx[1m:[0;10m]3[1m:[0;10m?4[1m::W[0;10m[1mWW[0;10m#[1muu[0;10m[1mi[0;10mo]=[1m=[0;10m=;[1m#Gpx%2%[0;10m;;=[1mqp0[0;10m7`[8m                [0;10m"
    MOTD[14]="[8m       [0;10m[1m?\"x[0;10m[1ms[0;10m[8m N[0;10m[1mL[0;10m:=?x39[1m+[0;10mvGq[1mWudX24x[0;10mq[1myaadH53%3X2x*HVt[0;10md\"[8m                  [0;10m"
    MOTD[15]="[8m        [0;10m[1m`[0;10mJ[1mX[0;10m[1m,[0;10m[8m [0;10mJ[1ms[0;10m;+]vxxJ[1m*9433%33ddG333![0;10m[1m@[0;10m[1m3]%x[0;10m[1mM[0;10m[1m3![0;10m[1mW[0;10mP`[8m                    [0;10m"
    MOTD[16]="[8m         [0;10m[1m [0;10mJ[1mJ,[0;10m[8m [0;10m?[1mn[0;10m[1m;=[0;10m++?|=:9|[1mMN?[0;10m[1mu%m3X[0;10m[1mM;[0;10m[1m~[0;10m=:[1m`W[0;10m4[1m*[0;10mx{[1m`[0;10m[8m                      [0;10m"
    MOTD[17]="[8m           [0;10m?S[1m_[0;10m[8m  [0;10mJ[1m_[0;10m[1ms[0;10m=+[1m==[0;10m===::|;+*[1m~[0;10m[1m~\_y[0;10m[1m_[0;10maq[1mm[0;10m/^[8m                         [0;10m"
    MOTD[18]="[8m              [0;10m[1m~'[0;10m_[8m [0;10m?[1m^[0;10m[1m`my[0;10m;;;;;;;;;;|[1ma[0;10m[1mm[0;10m:[1m?~[0;10m[8mt                            [0;10m"
    MOTD[19]="[8m                       :[0;10m?[1m^\"!!\"\"^[0;10m[8m                                    [0;10m"
}
