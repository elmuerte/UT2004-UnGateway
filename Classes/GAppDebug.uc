/*******************************************************************************
	GAppDebug																	<br />
	Debug commands, should not be used in										<br />
																				<br />
	Authors:	Michiel 'El Muerte' Hendriks &lt;elmuerte@drunksnipers.com&gt;	<br />
																				<br />
	Copyright 2003, 2004 Michiel "El Muerte" Hendriks							<br />
	Released under the Open Unreal Mod License									<br />
	http://wiki.beyondunreal.com/wiki/OpenUnrealModLicense						<br />

	<!-- $Id: GAppDebug.uc,v 1.12 2004/04/06 20:51:00 elmuerte Exp $ -->
*******************************************************************************/
class GAppDebug extends UnGatewayApplication;

function bool ExecCmd(UnGatewayClient client, array<string> cmd)
{
	local string command;
	command = cmd[0];
	cmd.remove(0, 1);
	switch (command)
	{
		case Commands[0].Name: execEcho(client, cmd); return true;
		case Commands[1].Name: execTest(client, cmd); return true;
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
	innerCVSversion="$Id: GAppDebug.uc,v 1.12 2004/04/06 20:51:00 elmuerte Exp $"
	Commands[0]=(Name="echo",Help="Returns it's first argument||Usage: echo \"some text\"")
	Commands[1]=(Name="test",Help="Various tests")
}
