/*******************************************************************************
	CronClient																	<br />
	Dummy client for the cron daemon											<br />
																				<br />
	Authors:	Michiel 'El Muerte' Hendriks &lt;elmuerte@drunksnipers.com&gt;	<br />
																				<br />
	Copyright 2003, 2004 Michiel "El Muerte" Hendriks							<br />
	Released under the Open Unreal Mod License									<br />
	http://wiki.beyondunreal.com/wiki/OpenUnrealModLicense						<br />
	<!-- $Id: CronClient.uc,v 1.4 2004/04/15 14:41:32 elmuerte Exp $ -->
*******************************************************************************/
class CronClient extends UnGatewayClient config;

/** if set to true all normal output is ingored, errors are still logged */
var() config bool bSilent;
/** set to true to use an external log file */
var() config bool bExternalLog;
/** the external log filename */
var() config string LogFilename;

/** external log file */
var protected FileLog flog;

function output(coerce string data, optional string ident, optional bool bDontWrapFirst)
{
	if (!bSilent)
	{
		if (bExternalLog) logf("Cron Output:"@ident$data);
		else log(data, 'cron output');
	}
}

function outputError(string errormsg, optional string ident, optional bool bDontWrapFirst)
{
	if (bExternalLog) logf("Cron Error:"@ident$errormsg);
	else log(errormsg, 'cron error');
}

protected function CreateLog()
{
	flog = spawn(class'FileLog');
	flog.OpenLog(getLogFilename());
}

protected function Logf(coerce string data)
{
	if (flog == none) CreateLog();
	flog.Logf(data);
}

/**
	return the filename to use for the log file. The following formatting rules are accepted:
	%P		server port
	%Y		year
	%M		month
	%D		day
	%H		hour
	%I		minute
	%S		second
	%W		day of the week
*/
function string GetLogFilename()
{
  local string result;
  result = LogFileName;
  ReplaceText(result, "%P", string(Level.Game.GetServerPort()));
  ReplaceText(result, "%N", Level.Game.GameReplicationInfo.ServerName);
  ReplaceText(result, "%Y", Right("0000"$string(Level.Year), 4));
  ReplaceText(result, "%M", Right("00"$string(Level.Month), 2));
  ReplaceText(result, "%D", Right("00"$string(Level.Day), 2));
  ReplaceText(result, "%H", Right("00"$string(Level.Hour), 2));
  ReplaceText(result, "%I", Right("00"$string(Level.Minute), 2));
  ReplaceText(result, "%W", Right("0"$string(Level.DayOfWeek), 1));
  ReplaceText(result, "%S", Right("00"$string(Level.Second), 2));
  return result;
}

defaultProperties
{
	CVSversion="$Id: CronClient.uc,v 1.4 2004/04/15 14:41:32 elmuerte Exp $"
	sUsername="Cron Daemon"
	LogFilename="crondaemon_%P"
}
