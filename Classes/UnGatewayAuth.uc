/*******************************************************************************
	UnGatewayAuth																<br />
	Base authentication class, this is used for user authentication				<br />
																				<br />
	Authors:	Michiel 'El Muerte' Hendriks &lt;elmuerte@drunksnipers.com&gt;	<br />
																				<br />
	Copyright 2003, 2004 Michiel "El Muerte" Hendriks							<br />
	Released under the Open Unreal Mod License									<br />
	http://wiki.beyondunreal.com/wiki/OpenUnrealModLicense						<br />
	<!-- $Id: UnGatewayAuth.uc,v 1.5 2004/04/07 08:39:37 elmuerte Exp $ -->
*******************************************************************************/
class UnGatewayAuth extends Info abstract;

/** CVS Id string */
var const string CVSversion;
/** pointer to main daemon */
var GatewayDaemon gateway;

/** Called after the object has been created */
function Create(GatewayDaemon gwd)
{
	gateway = gwd;
	gateway.Logf("Created", Name, gateway.LOG_EVENT);
}

/** Log in an user */
function bool Login(UnGatewayClient client, string username, string password, optional string extra)
{
	return true;
}

/** Log out an user */
function bool Logout(UnGatewayClient interface)
{
	return true;
}

/** return true when the user has the required permission */
function bool HasPermission(UnGatewayClient client, optional int seclevel, optional string perm)
{
	return true;
}

defaultproperties
{
	CVSversion="$Id: UnGatewayAuth.uc,v 1.5 2004/04/07 08:39:37 elmuerte Exp $"
}
