/*******************************************************************************
	GAppCron																	<br />
	The cron daemon																<br />
																				<br />
	Authors:	Michiel 'El Muerte' Hendriks &lt;elmuerte@drunksnipers.com&gt;	<br />
																				<br />
	Copyright 2003, 2004 Michiel "El Muerte" Hendriks							<br />
	Released under the Open Unreal Mod License									<br />
	http://wiki.beyondunreal.com/wiki/OpenUnrealModLicense						<br />
	<!-- $Id: Cron.uc,v 1.1 2004/04/11 21:43:34 elmuerte Exp $ -->
*******************************************************************************/

class Cron extends Info config;

/**
	Type of cron entry:
	<ul>
	<li> EC_Delay <br />
	The command will be executed after set number of seconds after the level has
	been loaded. Only the seconds field is used. </li>
	<li> EC_Time <br />
	The command will be executed when the set time has been	reached, fields
	with -1 as value are always accepted. </li>
	<li> EC_Disabled <br />
	This cron entry has been disabled. </li>
	</ul>
*/
enum ECronType
{
	EC_Delay,
	EC_Time,
	EC_Disabled,
};

/** and entry in the cron tab */
struct CronEntry
{
	/** the command to execute, the command will be executed as the system user */
	var() string command;
	/** the type of the command */
	var() ECronType type;
	/** time configuration, use -1 as a wildcard */
	var() int Seconds, Minutes, Hour, Day, Month, Year, DayOfWeek;
	/** description, keep this short */
	var() string desc;
};
/** the cron configuration */
var() config array<CronEntry> Crontab;

/** pointer to the Daemon, this is used to execute the commands */
var protected GatewayDaemon Daemon;

/** the class to spawn for the dummy client */
var() config string DummyClientClass;
/** our dummy client we spawn to handle the command results */
var UnGatewayClient DummyClient;

/**
	this function must be called after the cron daemon has been created.
*/
function Initialize(GatewayDaemon myDaemon)
{
	MyDaemon.Logf("Initialize", Name, MyDaemon.LOG_EVENT);
	Daemon = MyDaemon;
	CreateDummyClient();
	// start the timer to run every second
	if (DummyClient != none && Daemon != none) SetTimer(1, true);
}

/** create our dummy client */
function CreateDummyClient()
{
	local class<UnGatewayClient> cc;
	cc = class<UnGatewayClient>(DynamicLoadObject(DummyClientClass, class'Class', false));
	if (cc == none)
	{
		return;
	}
	DummyClient = spawn(cc);
}

/** check the cron configuration for commands to execute */
function Timer()
{
	local int i;
	for (i = 0; i < Crontab.Length; i++)
	{
		switch (Crontab[i].type)
		{
			case EC_Disabled: 	break;
			case EC_Delay:		if (Crontab[i].Seconds == int(Level.TimeSeconds))
								{
									ExecuteCommand(i);
								}
								break;
			case EC_Time:		if (Crontab[i].Year != Level.Year && Crontab[i].Year != -1) break;
								if (Crontab[i].Month != Level.Month && Crontab[i].Month != -1) break;
								if (Crontab[i].Day != Level.Day && Crontab[i].Day != -1) break;
								if (Crontab[i].DayOfWeek != Level.DayOfWeek && Crontab[i].DayOfWeek != -1) break;
								if (Crontab[i].Hour != Level.Hour && Crontab[i].Hour != -1) break;
								if (Crontab[i].Minutes != Level.Minutes && Crontab[i].Minutes != -1) break;
								if (Crontab[i].Seconds != Level.Seconds && Crontab[i].Seconds != -1) break;
								ExecuteCommand(i);
								break;
		}
	}
}

/** execulte a cron job */
protected function ExecuteCommand(int idx)
{
	local array<string> cmd;
	Daemon.Logf("Execute cron job #"$idx, Name, Daemon.LOG_EVENT);
 	if (DummyClient.AdvSplit(Crontab[idx].command, " ", cmd, "\"") == 0) return;
 	Daemon.ExecCommand(DummyClient, cmd);
}

defaultProperties
{
	DummyClientClass="UnGateway.CronClient"
}
