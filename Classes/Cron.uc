/*******************************************************************************
	GAppCron																	<br />
	The cron daemon																<br />
																				<br />
	Authors:	Michiel 'El Muerte' Hendriks &lt;elmuerte@drunksnipers.com&gt;	<br />
																				<br />
	Copyright 2003, 2004 Michiel "El Muerte" Hendriks							<br />
	Released under the Open Unreal Mod License									<br />
	http://wiki.beyondunreal.com/wiki/OpenUnrealModLicense						<br />
	<!-- $Id: Cron.uc,v 1.2 2004/04/12 13:38:15 elmuerte Exp $ -->
*******************************************************************************/

class Cron extends Info config;

/**
	Type of cron entry:
	<ul>
	<li> EC_Delay <br />
	The command will be executed after set number of minutes after the level has
	been loaded. Only the seconds field is used. </li>
	<li> EC_Time <br />
	The command will be executed when the set time has been	reached, fields
	with -1 as value are always accepted. </li>
	<li> EC_None <br />
	Shouldn't be used. </li>
	</ul>
*/
enum ECronType
{
	EC_None,
	EC_Delay,
	EC_Time,
};

/** and entry in the cron tab */
struct CronEntry
{
	/** the command to execute, the command will be executed as the system user */
	var() string command;
	/** the type of the command */
	var() ECronType type;
	/** time configuration, format depends on the type */
	var() string time;
	/** description, keep this short */
	var() string desc;
	var() bool bDisabled;
};
/** the cron configuration */
var() config array<CronEntry> Crontab;

/** time table entry, meaning of the variables depends on the type */
struct CronTimeEntry
{
	var int f1[6]; // minute hour day month day_of_week
	var int f2[6]; // minute hour day month day_of_week
};
/** processed time configuration, the entries match the entries in the crontab */
var array<CronTimeEntry> CronTimeConfig;

/** pointer to the Daemon, this is used to execute the commands */
var protected GatewayDaemon Daemon;

/** the class to spawn for the dummy client */
var() config string DummyClientClass;
/** our dummy client we spawn to handle the command results */
var protected UnGatewayClient DummyClient;

/**
	this function must be called after the cron daemon has been created.
*/
function Initialize(GatewayDaemon myDaemon)
{
	MyDaemon.Logf("Initialize", Name, MyDaemon.LOG_EVENT);
	Daemon = MyDaemon;
	CreateDummyClient();
	LoadCrontab();
	// start the timer to run every minute
	if (DummyClient != none && Daemon != none) SetTimer(60, true);
	Timer(); // call the first time
}

/** create our dummy client */
protected function CreateDummyClient()
{
	local class<UnGatewayClient> cc;
	cc = class<UnGatewayClient>(DynamicLoadObject(DummyClientClass, class'Class', false));
	if (cc == none)
	{
		return;
	}
	DummyClient = spawn(cc);
}

/** processes the crontab and creates the time entries */
protected function LoadCrontab()
{
	local int i;
	CronTimeConfig.Length = Crontab.length;
	for (i = 0; i < Crontab.length; i++)
	{
		CreateTimeEntry(i);
	}
}

/** create the time table entry for cron table entry i */
function CreateTimeEntry(int i)
{
	local array<string> f;
	switch (Crontab[i].type)
	{
		case EC_None: 		break;
		case EC_Delay:		CronTimeConfig[i].f1[0] = int(Crontab[i].time);
							break;
		case EC_Time:		Split(Crontab[i].time, " ", f);
							if (!EC_TimeEntry(f, i))
							{
								Crontab[i].bDisabled = true;
								Daemon.Logf("LoadCrontab: invalid time config: '"$Crontab[i].time$"' for crontab entry:"@i, Name, Daemon.LOG_ERR);
							}
	}
}

/**
	Creates a EC_Time formatted entry, if idx = -1 it won't be stored. 			<br />
	The format, 5 fields: minute hour day month day_of_week 					<br />
		minute:			0-59	<br />
		hour: 			0-23	<br />
		day:			0-31	<br />
		month:			0-11	<br />
		day_of_week:	0-6		<br />
 	A * can be used as wild card. Optionally each field can have a divider for
	re-occurance: val/div. For example a field has the value: "0/5". This means
	that it will match: time % div == val -> time % 5 == 0. If time is minutes
	then it will match every 5 minutes, 1/5 will also match every 5 minutes,
	except that it's the 2nd minute of every 5 minutes, 5/5 will never match. A
	wildcard in a divider will be changed to 0: * /5 -> 0/5, 0/ * -> 0/0 (never
	matches).
*/
protected function bool EC_TimeEntry(array<string> elm, int idx)
{
	local int i,n,val,div;
	local string tmp;

	if (elm.length != 5) return false;
	for (i = 0; i < 5; i++)
	{
		tmp = elm[i];
		div = MaxInt; // default to 255
		n = InStr(tmp, "/");
		if (n == -1)
		{
			if (tmp == "*") val = -1;
			else val = int(tmp);
		}
		else {
			val = int(Left(tmp, n));
			div = int(Mid(tmp, n+1));
		}
		if (val >= div)
		{
			Daemon.Logf("CreateTimeEntry: failed:"@tmp@val@div, Name, Daemon.LOG_ERR);
			return false;
		}
		if (idx > -1)
		{
			CronTimeConfig[idx].f1[i] = val;
			CronTimeConfig[idx].f2[i] = div;
		}
	}
	return true;
}

/** returns true when time has a valid format for the relevant type */
function bool validTimeFormat(ECronType type, string format)
{
	local array<string> f;
	switch (type)
	{
		case EC_Delay:		return (string(int(format)) == format); // check for an integer
		case EC_Time:		Split(format, " ", f);
							return EC_TimeEntry(f, -1);
	}
	return false;
}

/** check the cron configuration for commands to execute */
function Timer()
{
	local int i;
	log(Level.TimeSeconds@int(Level.TimeSeconds / 60.0));
	for (i = 0; i < Crontab.Length; i++)
	{
		if (Crontab[i].bDisabled) continue;
		switch (Crontab[i].type)
		{
			case EC_None: 		break;
			case EC_Delay:		if (CronTimeConfig[i].f1[0] == int(Level.TimeSeconds / 60.0))
								{
									ExecuteCommand(i);
								}
								break;
			case EC_Time:		if ((CronTimeConfig[i].f1[4] != (Level.DayOfWeek % CronTimeConfig[i].f2[4])) && CronTimeConfig[i].f1[4] != -1) break;
								if ((CronTimeConfig[i].f1[3] != (Level.Month % CronTimeConfig[i].f2[3])) && CronTimeConfig[i].f1[3] != -1) break;
								if ((CronTimeConfig[i].f1[2] != (Level.Day % CronTimeConfig[i].f2[2])) && CronTimeConfig[i].f1[2] != -1) break;
								if ((CronTimeConfig[i].f1[1] != (Level.Hour % CronTimeConfig[i].f2[1])) && CronTimeConfig[i].f1[1] != -1) break;
								if ((CronTimeConfig[i].f1[0] != (Level.Minute % CronTimeConfig[i].f2[0])) && CronTimeConfig[i].f1[0] != -1) break;
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
 	if (DummyClient.AdvSplit(class'UnGatewayApplication'.static.quotefix(Crontab[idx].command, true), " ", cmd, "\"") == 0) return;
 	Daemon.ExecCommand(DummyClient, cmd);
}

/** get the string representation of a enum value */
static function string TypeToString(ECronType type)
{
	switch (type)
	{
		case EC_Delay:		return "delay";
		case EC_Time:		return "time";
	}
	return "none";
}

/** return the enum value of the string representation */
static function ECronType StringToType(string type)
{
	if (type ~= "delay") return EC_Delay;
	if (type ~= "time") return EC_Time;
	return EC_None;
}

/** return the number of entries in the Cron Type enumeration */
static function int CronTypeCount()
{
	return ECronType.EnumCount;
}

/** return the enum value */
static function ECronType getCronType(int i)
{
	return ECronType(i);
}

defaultProperties
{
	DummyClientClass="UnGateway.CronClient"
}
