/**
	GAppDebug
	Debug commands, should not be used in 
	$Id: GAppDebug.uc,v 1.1 2003/09/04 08:11:46 elmuerte Exp $
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
	}
	return false;
}

function execEcho(UnGatewayClient client, array<string> cmd)
{
	if (cmd.length == 0)
	{
		client.outputError("echo: Incorrect usage");
	}
	else {
		client.output(cmd[0]);
	}
}

function exechelp(UnGatewayClient client, array<string> cmd)
{
	client.output("help: Not yet implemented");
}

defaultproperties
{
	Commands[0]=(Name="echo",Help="Returns it's first argument||Usage: echo \"some text\"")
	Commands[1]=(Name="help",Help="Show help about commands|This should be a built-in command||Usage: help <command>")
}