/*******************************************************************************
	CronClient																	<br />
	Dummy client for the cron daemon											<br />
																				<br />
	Authors:	Michiel 'El Muerte' Hendriks &lt;elmuerte@drunksnipers.com&gt;	<br />
																				<br />
	Copyright 2003, 2004 Michiel "El Muerte" Hendriks							<br />
	Released under the Open Unreal Mod License									<br />
	http://wiki.beyondunreal.com/wiki/OpenUnrealModLicense						<br />
	<!-- $Id: CronClient.uc,v 1.1 2004/04/11 21:43:34 elmuerte Exp $ -->
*******************************************************************************/
class CronClient extends UnGatewayClient config;

var() config bool bSilent;
var() config bool bExternalLog;
var() config string LogFilename;

function output(coerce string data)
{
	if (!bSilent) log(data, 'cron output');
}

function outputError(string errormsg)
{
	log(errormsg, 'cron error');
}

defaultProperties
{
	CVSversion="$Id: CronClient.uc,v 1.1 2004/04/11 21:43:34 elmuerte Exp $"
	sUsername="Cron Daemon"
}
