/**
	GAppDebug
	Debug commands, should not be used in
	$Id: GAppDebug.uc,v 1.6 2004/01/02 14:22:40 elmuerte Exp $
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
		case "test": execTest(client, cmd); return true;
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
	if (cmd.length != 1)
	{
		client.outputError("Usage: list <cmd|app|if|client>");
		return;
	}

	if (cmd[0] ~= "cmd")
	{
		for (i = 0; i < CmdLookupTable.length; i++)
		{
			client.output(CmdLookupTable[i].Command);
		}
	}
	else if (cmd[0] ~= "app")
	{
		for (i = 0; i < Applications.length; i++)
		{
			client.output(Applications[i]@"-"@Applications[i].innerCVSversion);
		}
	}
	else if (cmd[0] ~= "if")
	{
		for (i = 0; i < Interfaces.length; i++)
		{
			client.output(Interfaces[i]@"-"@Interfaces[i].CVSversion);
		}
	}
	else if (cmd[0] ~= "client")
	{
		client.outputError("Not implemented");
	}
	else client.outputError("Usage: list <cmd|app|if|client>");
}

function execTest(UnGatewayClient client, array<string> cmd)
{
	local int i;
	if (cmd[0] == "pager")
	{
		for (i = 0; i < int(cmd[1]); i++)
		{
			client.output("Pager test - line #"$i);
		}
	}
}

defaultproperties
{
	innerCVSversion="$Id: GAppDebug.uc,v 1.6 2004/01/02 14:22:40 elmuerte Exp $"
	Commands[0]=(Name="echo",Help="Returns it's first argument||Usage: echo \"some text\"")
	Commands[1]=(Name="help",Help="Show help about commands|This should be a built-in command||Usage: help <command>")
	Commands[2]=(Name="list",Help="Show various lists.|cmd	show registered commands|app	show loaded applications|if	show loaded interfaces|client	show connected clients")
	Commands[3]=(Name="test",Help="Various tests")
}
