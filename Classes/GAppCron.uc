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
	<!-- $Id: GAppCron.uc,v 1.1 2004/04/11 21:43:34 elmuerte Exp $ -->
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

defaultProperties
{
	CronClass="UnGateway.Cron"
	Commands[0]=(Name="cronlist",Help="...")
	Commands[1]=(Name="cronadd",Help="...")
	Commands[2]=(Name="crondel",Help="...")
}
