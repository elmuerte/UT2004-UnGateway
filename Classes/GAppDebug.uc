/*******************************************************************************
	GAppDebug																	<br />
	Debug commands, should not be used in										<br />
																				<br />
	Authors:	Michiel 'El Muerte' Hendriks &lt;elmuerte@drunksnipers.com&gt;	<br />
																				<br />
	Copyright 2003, 2004 Michiel "El Muerte" Hendriks							<br />
	Released under the Open Unreal Mod License									<br />
	http://wiki.beyondunreal.com/wiki/OpenUnrealModLicense						<br />

	<!-- $Id: GAppDebug.uc,v 1.18 2004/04/15 07:56:54 elmuerte Exp $ -->
*******************************************************************************/
class GAppDebug extends UnGatewayApplication;

var localized string CommandHelp[3];

function bool ExecCmd(UnGatewayClient client, array<string> cmd)
{
	local string command;
	command = cmd[0];
	cmd.remove(0, 1);
	switch (command)
	{
		case Commands[0].Name: execEcho(client, cmd); return true;
		case Commands[1].Name: execTest(client, cmd); return true;
		case Commands[2].Name: execConsole(client, cmd); return true;
	}
	return false;
}

function string GetHelpFor(string Command)
{
	local int i;
	for (i = 0; i < Commands.length; i++)
	{
		if (Commands[i].Name ~= Command) return CommandHelp[i];
	}
	return "";
}

function execEcho(UnGatewayClient client, array<string> cmd)
{
	local int i;
	if (cmd.length == 0)
	{
		client.outputError("Usage: echo <string>");
	}
	else {
		for (i = 0; i < cmd.length; i++)
		{
			client.output(cmd[i]);
		}
	}
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

function execConsole(UnGatewayClient client, array<string> cmd)
{
	local string res;
	res = Level.ConsoleCommand(Join(cmd, " ", "\""));
	if (res != "")
	{
		client.output(res);
	}
}

defaultproperties
{
	innerCVSversion="$Id: GAppDebug.uc,v 1.18 2004/04/15 07:56:54 elmuerte Exp $"
	Commands[0]=(Name="echo")
	Commands[1]=(Name="test")
	Commands[2]=(Name="console",Permission="Xc")

	CommandHelp[0]="Returns it's first argumentÿUsage: echo \"some text\""
	CommandHelp[1]="Various tests"
	CommandHelp[2]="Execute a console command"
}
