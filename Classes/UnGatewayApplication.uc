/**
	UnGatewayApplication
	Applications
	$Id: UnGatewayApplication.uc,v 1.2 2003/12/28 21:40:55 elmuerte Exp $
*/
class UnGatewayApplication extends Object within GatewayDaemon abstract;

struct CommandInfo
{
	var string Name;
	var string Help;
};
/** commands and help */
var localized array<CommandInfo> Commands;

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
	execute this command, called from the gateway 
	should be overwritten by subclasses
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
