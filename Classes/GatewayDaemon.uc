/*******************************************************************************
	GatewayDaemon																<br />
	Central Server																<br />
																				<br />
	Authors:	Michiel 'El Muerte' Hendriks &lt;elmuerte@drunksnipers.com&gt;	<br />
																				<br />
	Copyright 2003, 2004 Michiel "El Muerte" Hendriks							<br />
	Released under the Open Unreal Mod License									<br />
	http://wiki.beyondunreal.com/wiki/OpenUnrealModLicense						<br />
	<!-- $Id: GatewayDaemon.uc,v 1.12 2004/05/08 17:43:39 elmuerte Exp $ -->
*******************************************************************************/
class GatewayDaemon extends Info config;

/** log levels */
var const byte LOG_ERR, LOG_WARN, LOG_INFO, LOG_EVENT, LOG_DEBUG;

/** current log level */
var(Config) const globalconfig byte Verbose;

/** Authentication class used */
var(Config) globalconfig string AuthClass;
/** the authentication class instance */
var UnGatewayAuth Auth;

/** Interfaces to launch on startup */
var(Config) config array<string> InterfaceClasses;
var array<UnGatewayInterface> Interfaces;

/** Applications classes to be loaded on startup */
var(Config) config array<string> ApplicationClasses;
/** the application instances */
var array<UnGatewayApplication> Applications;

/** command lookup table entry */
struct CommandReference
{
	/** the application instance that accepts the command */
	var UnGatewayApplication App;
	/** the command */
	var string Command;
	/** true if it has a help string/manual page */
	var bool bHasHelp;
	/** security level required for this command */
	var byte Level;
	/** permission required for this command */
	var string Permission;
};
/** lookup table to find the app that has the command */
var array<CommandReference> CmdLookupTable;

/** a command alias */
struct CommandAlias
{
	/** the Alias */
	var string alias;
	/** the actual command to execute, replacements can be use %1, %2, %3,..., %@ (for all) for arguments passed to it */
	var string command;
};
/** configured command aliases */
var(Config) config array<CommandAlias> CmdAliases;

/** system identifier */
var const string Ident;
/** CVS Id string */
var const string CVSversion;
/** time this daemon was started */
var string CreationTime;
/** host information */
var string hostname, hostaddress, computername;

var localized string msgUnauthorized;

var localized string PICat;
var localized string PILabel[5];
var localized string PIDescription[5];

/** Spawn all classes*/
event PreBeginPlay()
{
	local int i;
	local class<UnGatewayAuth> UGAuth;
	local class<UnGatewayInterface> UGI;
	local class<UnGatewayApplication> UGA;

	ComputerName = Locs(Level.ComputerName);
	hostname = ComputerName$".unknown";
	//hostaddress = filled in by the first Interface loaded
	Logf("[PreBeginPlay] Starting:"@Ident, Name, LOG_INFO);
	if (CVSversion != "") Logf("[PreBeginPlay] "@CVSversion, Name, LOG_INFO);
	CreationTime = Level.Year$"-"$Right("0"$Level.Month, 2)$"-"$Right("0"$Level.Day, 2)@Right("0"$Level.Hour, 2)$":"$Right("0"$Level.Minute,2)$":"$Right("0"$Level.Second,2)$"."$Right("00"$Level.Millisecond, 3);

	Logf("[PreBeginPlay] Creating AuthClass", Name, LOG_EVENT);
	UGAuth = class<UnGatewayAuth>(DynamicLoadObject(AuthClass, class'Class'));
	if (UGAuth != none)
	{
		Auth = spawn(UGAuth, Self);
		Auth.Create(self);
	}
	else {
		Logf("[PreBeginPlay] Unable to create Authentication class:"@InterfaceClasses[i], Name, LOG_ERR);
	}

	Logf("[PreBeginPlay] Creating"@InterfaceClasses.length@"Interface(s)", Name, LOG_EVENT);
	for (i = 0; i < InterfaceClasses.length; i++)
	{
		UGI = class<UnGatewayInterface>(DynamicLoadObject(InterfaceClasses[i], class'Class', true));
		if (UGI != none)
		{
			Interfaces.length = Interfaces.length+1;
			Interfaces[Interfaces.length-1] = spawn(UGI, Self);
			Interfaces[Interfaces.length-1].Create(Self);
		}
		else {
			Logf("[PreBeginPlay] Unable to create Interface:"@InterfaceClasses[i], Name, LOG_ERR);
		}
	}

	Logf("[PreBeginPlay] Creating"@ApplicationClasses.length@"Application(s)", Name, LOG_EVENT);
	for (i = 0; i < ApplicationClasses.length; i++)
	{
		UGA = class<UnGatewayApplication>(DynamicLoadObject(ApplicationClasses[i], class'Class', true));
		if (UGA != none)
		{
			Applications.length = Applications.length+1;
			Applications[Applications.length-1] = new(Self) UGA;
			Applications[Applications.length-1].Create();
		}
		else {
			Logf("[PreBeginPlay] Unable to create Application:"@ApplicationClasses[i], Name, LOG_ERR);
		}
	}
	Logf("[PreBeginPlay] I am:"@computername$"@"$hostname$"("$hostaddress$")", Name, LOG_INFO);
}

/** Log in an user */
function bool Login(UnGatewayClient client, string username, string password, optional string extra)
{
	if (Auth != none) return Auth.Login(client, username, password, extra);
	Logf("[Login] Auth == none", Name, LOG_ERR);
	return false;
}

/** Log out an user */
function bool Logout(UnGatewayClient client)
{
	if (Auth != none) return Auth.Logout(client);
	Logf("[Logout] Auth == none", Name, LOG_ERR);
	return false;
}

/** log output */
function Logf(coerce string Msg, name LogName, byte Level)
{
	if ((Verbose & Level) != 0) Log(LogName$":"@Msg, LogName);
}

/**
	Execute a command.
	if bTryConsole is false (recommended) don't try to execute the command on the console.
*/
function bool ExecCommand(UnGatewayClient client, array<string> cmd, optional bool bTryConsole)
{
	local int i;
	if (cmd.length == 0) return false;
	LookupAlias(client, cmd);
	for (i = 0; i < CmdLookupTable.length; i++)
	{
		if (CmdLookupTable[i].Command ~= cmd[0]) // case insensitive
		{
			if (!Auth.HasPermission(client, CmdLookupTable[i].Level, CmdLookupTable[i].Permission))
			{
				client.outputError(msgUnauthorized);
			}
			return CmdLookupTable[i].App.ExecCmd(client, cmd);
		}
	}
	if (bTryConsole) ConsoleCommand(class'wArray'.static.Join(cmd));
	return false;
}

/** lookup an alias and translate it, this function asumes cmd has at least the length 1 */
function LookupAlias(UnGatewayClient client, out array<string> cmd)
{
	local int i,j;
	local string tmp1, tmp2;
	local array<string> newcmd;
	for (i = 0; i < CmdAliases.length; i++)
	{
		if (CmdAliases[i].alias ~= cmd[0]) break;
	}
	if (i == CmdAliases.length) return;
	tmp1 = CmdAliases[i].command;
	if (InStr(tmp1, "%@") > -1)
	{
		for (j = 1; j < cmd.length; j++)
		{
			if (tmp2 != "") tmp2 $= " ";
			tmp2 $= "\""$cmd[j]$"\"";
		}
		tmp1 = repl(tmp1, "%@", tmp2);
	}
	if (Client.AdvSplit(tmp1, " ", newcmd, "\"") == 0) return;
	for (i = 0; (i < cmd.length) && (i < 10); i++)
	{
		for (j = 0; j < newcmd.length; j++)
		{
			newcmd[j] = repl(newcmd[j], "%"$i, cmd[i]);
		}
	}
	for (i = i; (i < 10); i++)
	{
		for (j = 0; j < newcmd.length; j++)
		{
			newcmd[j] = repl(newcmd[j], "%"$i, "");
		}
	}
	cmd = newcmd;
}

/** return false when a client can't close */
function bool CanClose(UnGatewayClient client)
{
	local int i;
	for (i = 0; i < Applications.length; i++)
	{
		if (!Applications[i].CanClose(client)) return false;
	}
	return true;
}

static function FillPlayInfo(PlayInfo PlayInfo)
{
	super.FillPlayInfo(PlayInfo);
	PlayInfo.AddSetting(default.PICat, "Verbose", default.PILabel[0], 255, 255, "Text", "3;0:255",,,true);
	PlayInfo.AddSetting(default.PICat, "AuthClass", default.PILabel[1], 255, 1, "Text",,,,true);
	PlayInfo.AddSetting(default.PICat, "InterfaceClasses", default.PILabel[2], 255, 1, "Text",,,,true);
	PlayInfo.AddSetting(default.PICat, "ApplicationClasses", default.PILabel[3], 255, 1, "Text",,,,true);
	PlayInfo.AddSetting(default.PICat, "CmdAliases", default.PILabel[4], 255, 1, "Text",,,,true);
}

static event string GetDescriptionText(string PropName)
{
	switch (PropName)
	{
		case "Verbose":				return default.PIDescription[0];
		case "AuthClass":			return default.PIDescription[1];
		case "InterfaceClasses":	return default.PIDescription[2];
		case "ApplicationClasses":	return default.PIDescription[3];
		case "CmdAliases":			return default.PIDescription[4];
	}
	return "";
}

defaultproperties
{
	Verbose=0
	LOG_ERR=1
	LOG_WARN=2
	LOG_INFO=4
	LOG_EVENT=8
	LOG_DEBUG=128

	Ident="UnGateway/102"
	CVSversion="$Id: GatewayDaemon.uc,v 1.12 2004/05/08 17:43:39 elmuerte Exp $"
	AuthClass="UnGateway.GAuthSystem"
	msgUnauthorized="You are not authorized to use this command"

	PICat="UnGateway"
	PILabel[0]="Log verbosity"
	PIDescription[0]="Controls the log verbosity, the bits define which log messages are logged. Error = 1; Warning = 2; Information = 4; event = 8; Debug = 128. Unless you are developing addons for UnGateway you should not use anything except Error and Warning."
	PILabel[1]="Authorization class"
	PIDescription[1]="The class to use for authentication and authorization."
	PILabel[2]="Interfaces"
	PIDescription[2]="The interfaces classes to load on start up."
	PILabel[3]="Applications"
	PIDescription[3]="The application classes to load on start up."
	PILabel[4]="Command alias"
	PIDescription[4]="Aliases for commands. The following replacements can be used: %1, %2, %3,..., %@ (for all) for arguments passed to it"
}
