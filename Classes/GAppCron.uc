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
	<!-- $Id: GAppCron.uc,v 1.2 2004/04/12 13:38:15 elmuerte Exp $ -->
*******************************************************************************/

class GAppCron extends UnGatewayApplication config;

/**
	the cron daemon, this class is responsible for the creation of the cron
	daemon
*/
var protected Cron Cron;
/** the cron class to spawn */
var() globalconfig string CronClass;

function Create()
{
	super.Create();
	SummonCronDaemon();
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

function execList(UnGatewayClient client, array<string> cmd)
{
	local int i;
	local string dis;
	if (Cron == none)
	{
		client.outputError("No cron daemon found");
		return;
	}
	for (i = 0; i < cron.Crontab.length; i++)
	{
		if (cron.Crontab[i].bDisabled) dis = " "$"disabled";
		else dis = "";
		client.output(PadRight(i, 3)@quotefix(cron.Crontab[i].command, true));
		client.output("   "@cron.TypeToString(cron.Crontab[i].type)@cron.Crontab[i].time$dis);
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
		client.outputError("No cron daemon found");
		return;
	}
	if (cmd.length < 3)
	{
		client.outputError("Usage: cronadd <type> <time config> <command ...>");
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
		client.outputError("Invalid type, allowed values are:"@tmp);
		return;
	}
	if (!cron.validTimeFormat(ct, cmd[1]))
	{
		client.outputError(cmd[1]@"is not a valid time format for this type.");
	}
	tmp = cmd[1];
	cmd.remove(i, 2); // remove the first two entries
	cron.Crontab.length = cron.Crontab.length+1;
	cron.Crontab[cron.Crontab.length-1].command = quotefix(Join(cmd, " ", "\""));
	cron.Crontab[cron.Crontab.length-1].time = tmp;
	cron.Crontab[cron.Crontab.length-1].type = ct;
	cron.Crontab[cron.Crontab.length-1].desc = quotefix("added by"@client.sUsername);
	cron.Crontab[cron.Crontab.length-1].bDisabled = false;
	cron.CronTimeConfig.Length = cron.CronTimeConfig.Length+1;
	cron.CreateTimeEntry(cron.CronTimeConfig.Length-1);
	client.output("Crontab entry #"$(cron.Crontab.length-1)@"added");
	cron.SaveConfig();
}

function execDel(UnGatewayClient client, array<string> cmd)
{
	local int i;
	if (Cron == none)
	{
		client.outputError("No cron daemon found");
		return;
	}
	if ((cmd.length < 1) || !intval(cmd[0], i))
	{
		client.outputError("Usage: crondel <index>");
		return;
	}
	if ((i >= cron.Crontab.length) || (i < 0))
	{
		client.outputError("Invalid index"@i);
		return;
	}
	cron.Crontab.Remove(i, 1);
	cron.CronTimeConfig.Remove(i, 1);
	client.output("Crontab entry #"$i@"removed");
	cron.SaveConfig();
}

function execDisable(UnGatewayClient client, array<string> cmd)
{
	local int i, n;
	if (Cron == none)
	{
		client.outputError("No cron daemon found");
		return;
	}
	if (cmd.length < 1)
	{
		client.outputError("Usage: crondisable <index>");
		return;
	}
	for (i = 0; i < cmd.length; i++)
	{
		if (!intval(cmd[i], n) || (n >= cron.Crontab.length) || (n < 0))
		{
			client.outputError("Invalid index"@n);
			continue;
		}
		cron.Crontab[i].bDisabled = true;
		client.output("Crontab entry #"$n@"disabled");
	}
	cron.SaveConfig();
}

function execEnable(UnGatewayClient client, array<string> cmd)
{
	local int i, n;
	if (Cron == none)
	{
		client.outputError("No cron daemon found");
		return;
	}
	if (cmd.length < 1)
	{
		client.outputError("Usage: crondisable <index>");
		return;
	}
	for (i = 0; i < cmd.length; i++)
	{
		if (!intval(cmd[i], n) || (n >= cron.Crontab.length) || (n < 0))
		{
			client.outputError("Invalid index"@n);
			continue;
		}
		cron.Crontab[i].bDisabled = false;
		client.output("Crontab entry #"$n@"enabled");
	}
	cron.SaveConfig();
}

defaultproperties
{
	CronClass="UnGateway.Cron"
	Commands[0]=(Name="cronlist",Help="List the cron table")
	Commands[1]=(Name="cronadd",Help="Add a new item to the cron tableÿUsage: cronadd <type> <time config> <command ...>")
	Commands[2]=(Name="crondel",Help="Delete a entry in the cron tableÿUsage: crondel <index>")
	Commands[3]=(Name="crondisable",Help="Disable a cron table entryÿUsage: crondisable <index> ...")
	Commands[4]=(Name="cronenable",Help="Enable a cron table entryÿUsage: cronenable <index> ...")
}
