/*******************************************************************************
    GAuthSystem                                                                 <br />
    Authentication Client that uses the system default, the accesscontrol       <br />
                                                                                <br />
    Authors:    Michiel 'El Muerte' Hendriks &lt;elmuerte@drunksnipers.com&gt;  <br />
                                                                                <br />
    Copyright 2003, 2004 Michiel "El Muerte" Hendriks                           <br />
    Released under the Open Unreal Mod License                                  <br />
    http://wiki.beyondunreal.com/wiki/OpenUnrealModLicense
    <!-- $Id: GAuthSystem.uc,v 1.9 2004/10/20 14:08:46 elmuerte Exp $ -->
*******************************************************************************/
class GAuthSystem extends UnGatewayAuth;

/** Log in an user */
function bool Login(UnGatewayClient client, string username, string password, optional string extra)
{
    gateway.Logf("[Login] USER:"@username@"PASS: ******** EXTRA: ignored", Name, gateway.LOG_INFO);
    if (Level.Game.AccessControl.AdminLogin(client.PlayerController, username, Password))
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

/** return true when the user has the required permission */
function bool HasPermission(UnGatewayClient client, optional int seclevel, optional string perm)
{
    local xAdminUser xau;
    if ((seclevel == 0) && (perm == "")) return true;
    xau = Level.Game.AccessControl.GetLoggedAdmin(client.PlayerController);
    return Level.Game.AccessControl.CanPerform(client.PlayerController, perm) && (xau.MaxSecLevel() >= seclevel);
}

defaultproperties
{
    CVSversion="$Id: GAuthSystem.uc,v 1.9 2004/10/20 14:08:46 elmuerte Exp $"
}
