/*******************************************************************************
	GAppCron																	<br />
	Cron applications, with cron you can program certain commands to be execute
	at set times. This class only has the cron config modification functions.	<br />
																				<br />
	Authors:	Michiel 'El Muerte' Hendriks &lt;elmuerte@drunksnipers.com&gt;	<br />
																				<br />
	Copyright 2003, 2004 Michiel "El Muerte" Hendriks							<br />
	Released under the Open Unreal Mod License									<br />
	http://wiki.beyondunreal.com/wiki/OpenUnrealModLicense						<br />
	<!-- $Id: GAppCron.uc,v 1.5 2004/05/31 18:55:07 elmuerte Exp $ -->
*******************************************************************************/

class GAppCron extends UnGatewayApplication config;

/**
	the cron daemon, this class is responsible for the creation of the cron
	daemon
*/
var protected Cron Cron;
/** the cron class to spawn */
var() globalconfig string CronClass;

var localized string msgNoDaemon, msgDisabled, msgCronAddUsage, msgValidTypes,
	msgInvalidFormat, msgCronAdded, msgAddedBy, msgCronDelUsage, msgInvalidIndex,
	msgCronRemoved, msgCronDisableUsage, msgEntryDisabled, msgCronEnableUsage,
	msgCronEnabled;

var localized string CommandHelp[5];

function Create()
{
	super.Create();
	SummonCronDaemon();
}

function Destroy()
{
	if (Cron != none)
	{
		Cron.Destroy();
		Cron = none;
	}
}

/** create the Cron daemon */
function SummonCronDaemon()
{
	local class<Cron> cc;
	cc = class<Cron>(DynamicLoadObject(CronClass, class'Class', false));
	if (cc == none)
	{
		return;
	}
	Cron = spawn(cc);
	Cron.Initialize(Outer);
}

function bool ExecCmd(UnGatewayClient client, array<string> cmd)
{
	local string command;
	command = cmd[0];
	cmd.remove(0, 1);
	switch (command)
	{
		case Commands[0].Name: execList(client, cmd); return true;
		case Commands[1].Name: execAdd(client, cmd); return true;
		case Commands[2].Name: execDel(client, cmd); return true;
		case Commands[3].Name: execDisable(client, cmd); return true;
		case Commands[4].Name: execEnable(client, cmd); return true;
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

function execList(UnGatewayClient client, array<string> cmd)
{
	local int i;
	if (Cron == none)
	{
		client.outputError(msgNoDaemon);
		return;
	}
	for (i = 0; i < cron.Crontab.length; i++)
	{
		client.output(PadRight(i, 3)@quotefix(cron.Crontab[i].command, true));
		client.output("   "@cron.TypeToString(cron.Crontab[i].type)@cron.Crontab[i].time$iif(cron.Crontab[i].bDisabled,msgDisabled,""));
		if (cron.Crontab[i].desc != "") client.output("   "@quotefix(cron.Crontab[i].desc, true));
	}
}

function execAdd(UnGatewayClient client, array<string> cmd)
{
	local Cron.ECronType ct;
	local int i;
	local string tmp;
	if (Cron == none)
	{
		client.outputError(msgNoDaemon);
		return;
	}
	if (cmd.length < 3)
	{
		client.outputError(msgCronAddUsage);
		return;
	}
	ct = cron.StringToType(cmd[0]);
	if (ct == EC_None)
	{
		for (i = 0; i < cron.CronTypeCount(); i++)
		{
			ct = cron.getCronType(i);
			if (ct == EC_None) continue;
			if (tmp != "") tmp $= ", ";
			tmp $= cron.TypeToString(ct);
		}
		client.outputError(repl(msgValidTypes, "%s", tmp));
		return;
	}
	if (!cron.validTimeFormat(ct, cmd[1]))
	{
		client.outputError(repl(msgInvalidFormat, "%s", cmd[1]));
	}
	tmp = cmd[1];
	cmd.remove(i, 2); // remove the first two entries
	cron.Crontab.length = cron.Crontab.length+1;
	cron.Crontab[cron.Crontab.length-1].command = quotefix(Join(cmd, " ", "\""));
	cron.Crontab[cron.Crontab.length-1].time = tmp;
	cron.Crontab[cron.Crontab.length-1].type = ct;
	cron.Crontab[cron.Crontab.length-1].desc = quotefix(repl(msgAddedBy, "%s", client.sUsername));
	cron.Crontab[cron.Crontab.length-1].bDisabled = false;
	cron.CronTimeConfig.Length = cron.CronTimeConfig.Length+1;
	cron.CreateTimeEntry(cron.CronTimeConfig.Length-1);
	client.output(repl(msgCronAdded, "%s", (cron.Crontab.length-1)));
	cron.SaveConfig();
}

function execDel(UnGatewayClient client, array<string> cmd)
{
	local int i;
	if (Cron == none)
	{
		client.outputError(msgNoDaemon);
		return;
	}
	if ((cmd.length < 1) || !intval(cmd[0], i))
	{
		client.outputError(msgCronDelUsage);
		return;
	}
	if ((i >= cron.Crontab.length) || (i < 0))
	{
		client.outputError(repl(msgInvalidIndex, "%s", i));
		return;
	}
	cron.Crontab.Remove(i, 1);
	cron.CronTimeConfig.Remove(i, 1);
	client.output(repl(msgCronRemoved, "%s", i));
	cron.SaveConfig();
}

function execDisable(UnGatewayClient client, array<string> cmd)
{
	local int i, n;
	if (Cron == none)
	{
		client.outputError(msgNoDaemon);
		return;
	}
	if (cmd.length < 1)
	{
		client.outputError(msgCronDisableUsage);
		return;
	}
	for (i = 0; i < cmd.length; i++)
	{
		if (!intval(cmd[i], n) || (n >= cron.Crontab.length) || (n < 0))
		{
			client.outputError(repl(msgInvalidIndex, "%s", n));
			continue;
		}
		cron.Crontab[i].bDisabled = true;
		client.output(repl(msgEntryDisabled, "%s", n));
	}
	cron.SaveConfig();
}

function execEnable(UnGatewayClient client, array<string> cmd)
{
	local int i, n;
	if (Cron == none)
	{
		client.outputError(msgNoDaemon);
		return;
	}
	if (cmd.length < 1)
	{
		client.outputError(msgCronEnableUsage);
		return;
	}
	for (i = 0; i < cmd.length; i++)
	{
		if (!intval(cmd[i], n) || (n >= cron.Crontab.length) || (n < 0))
		{
			client.outputError(repl(msgInvalidIndex, "%s", n));
			continue;
		}
		cron.Crontab[i].bDisabled = false;
		client.output(repl(msgCronEnabled, "%s", n));
	}
	cron.SaveConfig();
}

defaultproperties
{
	CronClass="UnGateway.Cron"
	Commands[0]=(Name="cronlist",Level=254)
	Commands[1]=(Name="cronadd",Level=255)
	Commands[2]=(Name="crondel",Level=255)
	Commands[3]=(Name="crondisable",Level=255)
	Commands[4]=(Name="cronenable",Level=255)

	CommandHelp[0]="List the cron table"
	CommandHelp[1]="Add a new item to the cron tableÿUsage: cronadd <type> <time config> <command ...>"
	CommandHelp[2]="Delete a entry in the cron tableÿUsage: crondel <index>"
	CommandHelp[3]="Disable a cron table entryÿUsage: crondisable <index> ..."
	CommandHelp[4]="Enable a cron table entryÿUsage: cronenable <index> ..."

	msgNoDaemon="No cron daemon found"
	msgDisabled="disabled"
	msgCronAddUsage="Usage: cronadd <type> <time config> <command ...>"
	msgValidTypes="Invalid type, allowed values are: %s"
	msgInvalidFormat="%s is not a valid time format for this type."
	msgCronAdded="Crontab entry #%s added"
	msgAddedBy="added by %s"
	msgCronDelUsage="Usage: crondel <index>"
	msgInvalidIndex="Invalid index %s"
	msgCronRemoved="Crontab entry #%s removed"
	msgCronDisableUsage="Usage: crondisable <index>"
	msgEntryDisabled="Crontab entry #%s disabled"
	msgCronEnableUsage="Usage: cronenable <index>"
	msgCronEnabled="Crontab entry #%s enabled"
}
