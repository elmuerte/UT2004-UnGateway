/**
	GatewayDaemon
	Central Server
	$Id: GatewayDaemon.uc,v 1.3 2003/12/30 12:24:47 elmuerte Exp $
*/
class GatewayDaemon extends Info config;

/** log levels */
var const byte LOG_ERR, LOG_WARN, LOG_INFO, LOG_EVENT, LOG_DEBUG;

/** current log level */
var const config byte Verbose;

/** Authentication class */
var config string AuthClass;
var UnGatewayAuth Auth;

/** Interfaces to launch on startup */
var config array<string> InterfaceClasses;
var array<UnGatewayInterface> Interfaces;

/** Applications */
var config array<string> ApplicationClasses;
var array<UnGatewayApplication> Applications;

struct CommandReference
{
	var UnGatewayApplication App;
	var string Command;
	var bool bHasHelp;
};
/** lookup table to find the app that has the command */
var array<CommandReference> CmdLookupTable;


/** system identifier */
var const string Ident;
/** CVS Id string */
var const string CVSversion;
/** time this daemon was started */
var string CreationTime;
/** host information */
var string hostname, hostaddress, computername;

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
	execute a command
	if bNoConsole is true don't try to execute the command on the console.
*/
function bool ExecCommand(UnGatewayClient client, array<string> cmd, optional bool bNoConsole)
{
	local int i;
	if (cmd.length == 0) return false;
	for (i = 0; i < CmdLookupTable.length; i++)
	{
		if (CmdLookupTable[i].Command ~= cmd[0]) // case insensitive
		{
			return CmdLookupTable[i].App.ExecCmd(client, cmd);
		}
	}
	if (!bNoConsole)
	{
		// do console
	}
	return false;
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

defaultproperties
{
	Verbose=0
	LOG_ERR=1
	LOG_WARN=2
	LOG_INFO=4
	LOG_EVENT=8
	LOG_DEBUG=128

	AuthClass="UnGateway.GAuthSystem"
	Ident="UnGateway/100"
	CVSversion="$Id: GatewayDaemon.uc,v 1.3 2003/12/30 12:24:47 elmuerte Exp $"
}
