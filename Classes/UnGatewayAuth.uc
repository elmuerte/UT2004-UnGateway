/**
	UnGatewayAuth
	Base authentication class, this is used for user authentication
	$Id: UnGatewayAuth.uc,v 1.2 2004/01/02 09:19:24 elmuerte Exp $
*/
class UnGatewayAuth extends Info abstract;

/** CVS Id string */
var const string CVSversion;

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

defaultproperties
{
	CVSversion="$Id: UnGatewayAuth.uc,v 1.2 2004/01/02 09:19:24 elmuerte Exp $"
}
