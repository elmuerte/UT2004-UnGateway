/*******************************************************************************
	GAuthSystem																	<br />
	Authentication Client that uses the system default, the accesscontrol		<br />
																				<br />
	Authors:	Michiel 'El Muerte' Hendriks &lt;elmuerte@drunksnipers.com&gt;	<br />
																				<br />
	Copyright 2003, 2004 Michiel "El Muerte" Hendriks							<br />
	Released under the Lesser Open Unreal Mod License							<br />
	http://wiki.beyondunreal.com/wiki/LesserOpenUnrealModLicense				<br />
	<!-- $Id: GAuthSystem.uc,v 1.4 2004/04/06 18:58:11 elmuerte Exp $ -->
*******************************************************************************/
class GAuthSystem extends UnGatewayAuth;

/** Log in an user */
function bool Login(UnGatewayClient client, string username, string password, optional string extra)
{
	gateway.Logf("[Login] USER:"@username@"PASS: ******** EXTRA: ignored", Name, gateway.LOG_INFO);
	if (Level.Game.AccessControl.AdminLogin(client.PlayerController, password, Password))
	{
		gateway.Logf("[Login] succesfull", Name, gateway.LOG_INFO);
		return true;
	}
	gateway.Logf("[Login] failed", Name, gateway.LOG_INFO);
	return false;
}

/** Log out an user */
function bool Logout(UnGatewayClient client)
{
	if (!client.PlayerController.PlayerReplicationInfo.bAdmin) return true;
	if (!Level.Game.AccessControl.AdminLogout(client.PlayerController))
	{
		gateway.Logf("[Logout] failed", Name, gateway.LOG_INFO);
		return false;
	}
	return true;
}

defaultproperties
{
	CVSversion="$Id: GAuthSystem.uc,v 1.4 2004/04/06 18:58:11 elmuerte Exp $"
}
