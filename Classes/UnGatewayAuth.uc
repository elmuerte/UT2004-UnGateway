/**
	UnGatewayAuth
	Base authentication class, this is used for user authentication
	$Id: UnGatewayAuth.uc,v 1.1 2003/09/04 08:11:46 elmuerte Exp $
*/
class UnGatewayAuth extends Info abstract;

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
