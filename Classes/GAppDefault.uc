/*******************************************************************************
	GAppDefault																	<br />
	Default applications														<br />
																				<br />
	Authors:	Michiel 'El Muerte' Hendriks &lt;elmuerte@drunksnipers.com&gt;	<br />
																				<br />
	Copyright 2003, 2004 Michiel "El Muerte" Hendriks							<br />
	Released under the Open Unreal Mod License									<br />
	http://wiki.beyondunreal.com/wiki/OpenUnrealModLicense						<br />
	<!-- $Id: GAppDefault.uc,v 1.2 2004/04/08 19:43:30 elmuerte Exp $ -->
*******************************************************************************/
class GAppDefault extends UnGatewayApplication;

/** the substring to convert to a newline */
var localized string HelpNewline;

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

function execHelp(UnGatewayClient client, array<string> cmd)
{
	local int i, j;
	local array<string> HelpInfo;

	if (cmd.length != 1)
	{
		client.outputError("Usage: help <command>");
		return;
	}
	for (i = 0; i < CmdAliases.length; i++)
	{
		if (CmdAliases[i].Alias ~= cmd[0])
		{
			client.output(cmd[0]@"is an alias for:"@CmdAliases[i].command);
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
				client.outputError("No help available for"@cmd[0]);
			}
			return;
		}
	}
	client.outputError("No such command:"@cmd[0]);
}

function execList(UnGatewayClient client, array<string> cmd)
{
	local int i;
	local UnGatewayClient uc;
	local array<string> tmp;

	if (cmd.length != 1)
	{
		client.outputError("Usage: list <cmd|app|if|client>");
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
			client.output("    "$Applications[i].innerCVSversion);
			client.output("    Commands:"@Applications[i].Commands.length);
		}
	}
	else if (cmd[0] ~= "if")
	{
		for (i = 0; i < Interfaces.length; i++)
		{
			if (i > 0) client.output("");
			client.output(Interfaces[i].Ident@Interfaces[i].Name);
			client.output("    "$Interfaces[i].CVSversion);
			client.output("    Port:"@Interfaces[i].iListenPort);
			client.output("    Clients:"@Interfaces[i].clientCount);
		}
	}
	else if (cmd[0] ~= "client")
	{
		foreach DynamicActors(class'UnGatewayClient', uc)
		{
			if (i > 0) client.output("");
			client.output(uc.Name);
			client.output("    "$uc.CVSversion);
			client.output("    Username:"@uc.sUsername);
			client.output("    Address:"@uc.ClientAddress);
		}
	}
	else client.outputError("Usage: list <cmd|app|if|client>");
}

defaultproperties
{
	innerCVSversion="$Id: GAppDefault.uc,v 1.2 2004/04/08 19:43:30 elmuerte Exp $"
	HelpNewline="ÿ"
	Commands[0]=(Name="help",Help="Show help about commandsÿUsage: help <command>")
	Commands[1]=(Name="list",Help="Show various lists.\ncmd	show registered commandsÿapp	show loaded applicationsÿif	show loaded interfacesÿclient	show connected clients")
	Commands[2]=(Name="quit",Help="Logout")
}
