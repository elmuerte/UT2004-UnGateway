/*******************************************************************************
	GAppDebug																	<br />
	Debug commands, should not be used in										<br />
																				<br />
	Authors:	Michiel 'El Muerte' Hendriks &lt;elmuerte@drunksnipers.com&gt;	<br />
																				<br />
	Copyright 2003, 2004 Michiel "El Muerte" Hendriks							<br />
	Released under the Open Unreal Mod License									<br />
	http://wiki.beyondunreal.com/wiki/OpenUnrealModLicense						<br />

	<!-- $Id: GAppDebug.uc,v 1.20 2004/04/21 15:38:06 elmuerte Exp $ -->
*******************************************************************************/
class GAppDebug extends UnGatewayApplication;

var localized string CommandHelp[4];

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
		case Commands[3].Name: execDump(client, cmd); return true;
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

function execDump(UnGatewayClient client, array<string> cmd)
{
	local int i,j;
	local FileLog f;
	local array<string> hlp;
	local array<GatewayDaemon.CommandReference> cmdtable;

	// create sorted list
	for (i = 0; i < CmdLookupTable.length; i++)
	{
		for (j = 0; j < cmdtable.length; j++)
		{
			if (Caps(cmdtable[j].Command) > Caps(CmdLookupTable[i].Command)) break;
		}
		cmdtable.insert(j, 1);
		cmdtable[j] = CmdLookupTable[i];
	}

	f = Spawn(class'FileLog');
	f.OpenLog("UnGateway-help", "html", true);
	for (i = 0; i < cmdtable.Length; i++)
	{
		f.Logf("<h1 class=\"ugh_cmd\">"$cmdtable[i].Command$"</h1>");
		f.Logf("<div class=\"ugh_app\">Application:"@cmdtable[i].App.Class$"</div>");
		split(cmdtable[i].App.GetHelpFor(cmdtable[i].Command), class'GAppDefault'.default.HelpNewline, hlp);
		f.Logf("<div class=\"ugh_help\">");
		for (j = 0; j < hlp.length; j++)
		{
			f.Logf(repl(repl(hlp[j], "<", "&lt;"), ">", "&gt;")$"<br />");
		}
		f.Logf("</div>");
	}
	f.Destroy();
	client.output("Command information dumped to UnGateway-help.html");
}

defaultproperties
{
	innerCVSversion="$Id: GAppDebug.uc,v 1.20 2004/04/21 15:38:06 elmuerte Exp $"
	Commands[0]=(Name="echo")
	Commands[1]=(Name="test",Level=255)
	Commands[2]=(Name="console",Permission="Xc")
	Commands[3]=(Name="dump",Level=255)

	CommandHelp[0]="A simple echo command.ÿIt will echo each argument on a single lineÿUsage: echo \"some text\""
	CommandHelp[1]="Various tests for debugging."
	CommandHelp[2]="Execute a console command.ÿThe console command will be executed as the system, not as the logged in user."
	CommandHelp[3]="Dump all available commands and help to the file UnGateway-help.html"
}
