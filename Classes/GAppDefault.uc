/*******************************************************************************
	GAppDefault																	<br />
	Default applications														<br />
																				<br />
	Authors:	Michiel 'El Muerte' Hendriks &lt;elmuerte@drunksnipers.com&gt;	<br />
																				<br />
	Copyright 2003, 2004 Michiel "El Muerte" Hendriks							<br />
	Released under the Open Unreal Mod License									<br />
	http://wiki.beyondunreal.com/wiki/OpenUnrealModLicense						<br />
	<!-- $Id: GAppDefault.uc,v 1.5 2004/04/15 07:56:54 elmuerte Exp $ -->
*******************************************************************************/
class GAppDefault extends UnGatewayApplication;

/** the substring to convert to a newline */
var localized string HelpNewline;

var localized string msgHelpUsage, msgIsAlias, msgNoHelp, msgNoSuchCommand,
	msgListUsage, msgLCommands, msgLPort, msgLClients, msgLUsername, msgLAddress;

var localized string CommandHelp[3];

function bool ExecCmd(UnGatewayClient client, array<string> cmd)
{
	local string command;
	command = cmd[0];
	cmd.remove(0, 1);
	switch (command)
	{
		case Commands[0].Name: execHelp(client, cmd); return true;
		case Commands[1].Name: execList(client, cmd); return true;
		case Commands[2].Name: client.OnLogout(); return true;
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

function execHelp(UnGatewayClient client, array<string> cmd)
{
	local int i, j;
	local array<string> HelpInfo;

	if (cmd.length == 0)
	{
		client.outputError(msgHelpUsage);
		return;
	}
	for (i = 0; i < CmdAliases.length; i++)
	{
		if (CmdAliases[i].Alias ~= cmd[0])
		{
			client.output(repl(repl(msgIsAlias, "%alias", cmd[0]), "%cmd", CmdAliases[i].command));
			return;
		}
	}
	for (i = 0; i < CmdLookupTable.length; i++)
	{
		if (CmdLookupTable[i].Command ~= cmd[0])
		{
			if (CmdLookupTable[i].bHasHelp)
			{
				split(CmdLookupTable[i].App.GetHelpFor(CmdLookupTable[i].Command), HelpNewline, HelpInfo);
				for (j = 0; j < HelpInfo.length; j++)
				{
					client.output(HelpInfo[j]);
				}
			}
			else {
				client.outputError(repl(msgNoHelp, "%s", cmd[0]));
			}
			return;
		}
	}
	client.outputError(repl(msgNoSuchCommand, "%s", cmd[0]));
}

function execList(UnGatewayClient client, array<string> cmd)
{
	local int i;
	local UnGatewayClient uc;
	local array<string> tmp;

	if (cmd.length != 1)
	{
		client.outputError(msgListUsage);
		return;
	}

	if (cmd[0] ~= "cmd")
	{
		for (i = 0; i < CmdLookupTable.length; i++)
		{
			tmp[tmp.length] = CmdLookupTable[i].Command;
		}
		for (i = 0; i < CmdAliases.length; i++)
		{
			tmp[tmp.length] = CmdAliases[i].Alias;
		}
		class'wArray'.static.SortS(tmp);
		for (i = 0; i < tmp.length; i++)
		{
			client.output(tmp[i]);
		}
	}
	else if (cmd[0] ~= "app")
	{
		for (i = 0; i < Applications.length; i++)
		{
			if (i > 0) client.output("");
			client.output(Applications[i].Name);
			client.output(Applications[i].innerCVSversion, "    ");
			client.output(msgLCommands$":"@Applications[i].Commands.length, "    ");
		}
	}
	else if (cmd[0] ~= "if")
	{
		for (i = 0; i < Interfaces.length; i++)
		{
			if (i > 0) client.output("");
			client.output(Interfaces[i].Ident@Interfaces[i].Name);
			client.output(Interfaces[i].CVSversion, "    ");
			client.output(msgLPort$":"@Interfaces[i].iListenPort, "    ");
			client.output(msgLClients$":"@Interfaces[i].clientCount, "    ");
		}
	}
	else if (cmd[0] ~= "client")
	{
		foreach DynamicActors(class'UnGatewayClient', uc)
		{
			if (i > 0) client.output("");
			client.output(uc.Name);
			client.output(uc.CVSversion, "    ");
			client.output(msgLUsername$":"@uc.sUsername, "    ");
			client.output(msgLAddress$":"@uc.ClientAddress, "    ");
		}
	}
	else client.outputError(msgListUsage);
}

defaultproperties
{
	innerCVSversion="$Id: GAppDefault.uc,v 1.5 2004/04/15 07:56:54 elmuerte Exp $"
	HelpNewline="ÿ"
	Commands[0]=(Name="help")
	Commands[1]=(Name="list")
	Commands[2]=(Name="quit")

	CommandHelp[0]="Show help about commandsÿUsage: help <command>"
	CommandHelp[1]="Show various lists.\ncmd	show registered commandsÿapp	show loaded applicationsÿif	show loaded interfacesÿclient	show connected clients"
	CommandHelp[2]="Logout"

	msgHelpUsage="Usage: help <command>"
	msgIsAlias="%alias is an alias for: %cmd"
	msgNoHelp="No help available for %s"
	msgNoSuchCommand="No such command %s"
	msgListUsage="Usage: list <cmd|app|if|client>"
	msgLCommands="Commands"
	msgLPort="Port"
	msgLClients="Clients"
	msgLUsername="Username"
	msgLAddress="Address"
}
