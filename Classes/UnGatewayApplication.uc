/*******************************************************************************
	UnGatewayApplication														<br />
	Applications																<br />
																				<br />
	Authors:	Michiel 'El Muerte' Hendriks &lt;elmuerte@drunksnipers.com&gt;	<br />
																				<br />
	Copyright 2003, 2004 Michiel "El Muerte" Hendriks							<br />
	Released under the Open Unreal Mod License									<br />
	http://wiki.beyondunreal.com/wiki/OpenUnrealModLicense						<br />
	<!-- $Id: UnGatewayApplication.uc,v 1.6 2004/04/07 16:37:39 elmuerte Exp $ -->
*******************************************************************************/
class UnGatewayApplication extends Object within GatewayDaemon abstract;

/** CVS Id string */
var const string innerCVSversion;

/** commands this application accepts */
struct CommandInfo
{
	var string Name;
	var localized string Help;
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
		CmdLookupTable[CmdLookupTable.length-1].bHasHelp = (Commands[i].Help != "");
	}
}

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

/** return help string */
function string GetHelpFor(string Command)
{
	local int i;
	for (i = 0; i < Commands.length; i++)
	{
		if (Commands[i].Name ~= Command) return Commands[i].Help;
	}
	return "";
}

defaultproperties
{
	innerCVSversion="$Id: UnGatewayApplication.uc,v 1.6 2004/04/07 16:37:39 elmuerte Exp $"
}
