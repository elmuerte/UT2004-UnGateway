/**
	GAppDebug
	Debug commands, should not be used in 
	$Id: GAppDebug.uc,v 1.2 2003/12/28 21:40:55 elmuerte Exp $
*/
class GAppDebug extends UnGatewayApplication;

function bool ExecCmd(UnGatewayClient client, array<string> cmd)
{
	local string command;
	command = cmd[0];
	cmd.remove(0, 1);
	switch (command)
	{
		case "echo": execEcho(client, cmd); return true;
		case "help": execHelp(client, cmd); return true;
		case "list": execList(client, cmd); return true;
	}
	return false;
}

function execEcho(UnGatewayClient client, array<string> cmd)
{
	if (cmd.length == 0)
	{
		client.outputError("Usage: echo <string>");
	}
	else {
		client.output(cmd[0]);
	}
}

function execHelp(UnGatewayClient client, array<string> cmd)
{
	local int i, j;
	local array<string> HelpInfo;

	if (cmd.length != 1)
	{
		client.outputError("Usage: help <command>");
		return;
	}

	for (i = 0; i < CmdLookupTable.length; i++)
	{
		if (CmdLookupTable[i].Command ~= cmd[0])
		{
			if (CmdLookupTable[i].bHasHelp)
			{
				split(CmdLookupTable[i].App.GetHelpFor(CmdLookupTable[i].Command), "|", HelpInfo);
				for (j = 0; j < HelpInfo.length; j++)
				{
					client.output(HelpInfo[j]);
				}
			}
			else {
				client.outputError("No help available for"@cmd[0]);
			}				
		}
	}
}

function execList(UnGatewayClient client, array<string> cmd)
{
	local int i;
	for (i = 0; i < CmdLookupTable.length; i++)
	{
		client.output(CmdLookupTable[i].Command);
	}
}

defaultproperties
{
	Commands[0]=(Name="echo",Help="Returns it's first argument||Usage: echo \"some text\"")
	Commands[1]=(Name="help",Help="Show help about commands|This should be a built-in command||Usage: help <command>")
	Commands[2]=(Name="list",Help="List all registered commands")
}