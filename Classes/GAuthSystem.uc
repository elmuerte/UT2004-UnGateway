/**
	GAuthSystem
	Authentication Client that uses the system default
	$Id: GAuthSystem.uc,v 1.1 2003/09/04 08:11:46 elmuerte Exp $
*/
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
	if (!Level.Game.AccessControl.AdminLogout(client.PlayerController))
	{
		gateway.Logf("[Logout] failed", Name, gateway.LOG_INFO);
		return false;
	}
	return true;
}
