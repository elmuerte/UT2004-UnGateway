/*******************************************************************************
	UnGatewayApplication														<br />
	Applications																<br />
																				<br />
	Authors:	Michiel 'El Muerte' Hendriks &lt;elmuerte@drunksnipers.com&gt;	<br />
																				<br />
	Copyright 2003, 2004 Michiel "El Muerte" Hendriks							<br />
	Released under the Open Unreal Mod License									<br />
	http://wiki.beyondunreal.com/wiki/OpenUnrealModLicense						<br />
	<!-- $Id: UnGatewayApplication.uc,v 1.12 2004/05/31 18:55:07 elmuerte Exp $ -->
*******************************************************************************/
class UnGatewayApplication extends Object within GatewayDaemon abstract;

/** CVS Id string */
var const string innerCVSversion;

/** commands this application accepts */
struct CommandInfo
{
	var string Name;
	/** security level required for this command */
	var byte Level;
	/** permission required for this command */
	var string Permission;
};
/** commands and help */
var array<CommandInfo> Commands;

/** Called after the object has been created */
function Create()
{
	local int i;
	Logf("Created", Name, LOG_EVENT);
	for (i = 0; i < Commands.length; i++)
	{
		Logf("[Created] Register command:"@Commands[i].Name, Name, LOG_DEBUG);
		CmdLookupTable.length = CmdLookupTable.length+1;
		CmdLookupTable[CmdLookupTable.length-1].App = Self;
		CmdLookupTable[CmdLookupTable.length-1].Command = Commands[i].Name;
		CmdLookupTable[CmdLookupTable.length-1].bHasHelp = GetHelpFor(Commands[i].Name) != "";
		CmdLookupTable[CmdLookupTable.length-1].Level = Commands[i].Level;
		CmdLookupTable[CmdLookupTable.length-1].Permission = Commands[i].Permission;
	}
}

/** perform clean up if needed */
function Destroy();

/**
	Execute this command, called from the gateway.
	Should be overwritten by subclasses.
*/
function bool ExecCmd(UnGatewayClient client, array<string> cmd)
{
	return false;
}

/** return false when a client can't close */
function bool CanClose(UnGatewayClient client)
{
	return true;
}

/** return help string, should be overwritten by subclasses */
function string GetHelpFor(string Command)
{
	return "";
}

/** pad the string until it's long engouh */
function string PadLeft(coerce string str, int length, optional string delim)
{
	if (delim == "") delim = " ";
	while (Len(str) < length) str $= delim;
	return str;
}

/** pad the string until it's long engouh */
function string PadRight(coerce string str, int length, optional string delim)
{
	if (delim == "") delim = " ";
	while (Len(str) < length) str = delim$str;
	return str;
}

/** pad the string so the content is in the center */
function string PadCenter(coerce string str, int length, optional string delim)
{
	if (delim == "") delim = " ";
	while (Len(str) < length)
	{
		str $= delim;
		if (Len(str) < length) str = delim$str;
	}
	return str;
}

/** evaluates expr and return the correct string */
function string iif(bool expr, coerce string sthen, optional coerce string selse)
{
	if (expr) return sthen;
	return selse;
}

/** sets val to the integer representation of in and returns true if in had a integer */
function bool intval(string in, out int val)
{
	local int nval;
	nval = int(in);
	if (in == string(nval))
	{
		val = nval;
		return true;
	}
	return false;
}

/** join a array of string */
function string Join(array<string> ar, optional string delim, optional string quotechar, optional bool bIgnoreEmpty)
{
	local string result;
	local int i;
	for (i = 0; i < ar.length; i++)
	{
		if (bIgnoreEmpty && ar[i] == "") continue;
		if (result != "") result = result$delim;
		if ((InStr(ar[i], delim) > -1) && (delim != "")) ar[i] = quotechar$ar[i]$quotechar;
		result = result$ar[i];
	}
	return result;
}

/** quote bug fix */
static function string quotefix(string in, optional bool bUnfix)
{
	if (bUnfix) return repl(in, "\\\"", "\"");
	return repl(in, "\"", "\\\"");
}

/** this function will be assigned to the UnGatewayClient delegate when requesting input */
function RequestInputResult(UnGatewayClient client, coerce string result);

defaultproperties
{
	innerCVSversion="$Id: UnGatewayApplication.uc,v 1.12 2004/05/31 18:55:07 elmuerte Exp $"
}
