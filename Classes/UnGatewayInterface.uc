/*******************************************************************************
    UnGatewayInterface                                                          <br />
    Interface for TCP based services linked in the Gateway system               <br />
                                                                                <br />
    Authors:    Michiel 'El Muerte' Hendriks &lt;elmuerte@drunksnipers.com&gt;  <br />
                                                                                <br />
    Copyright 2003, 2004 Michiel "El Muerte" Hendriks                           <br />
    Released under the Open Unreal Mod License                                  <br />
    http://wiki.beyondunreal.com/wiki/OpenUnrealModLicense
    <!-- $Id: UnGatewayInterface.uc,v 1.11 2004/10/20 14:08:47 elmuerte Exp $ -->
*******************************************************************************/
class UnGatewayInterface extends TcpLink abstract config;

/** the owning daemon */
var GatewayDaemon gateway;

/** the port to listen on */
var(Config) config int iListenPort;
var(Config) config bool bUseNextAvailable;

/** requested receive mode to set */
var EReceiveMode RequestedReceiveMode;
/** requested link mode mode to set */
var ELinkMode RequestedLinkMode;

/** current number of client connections open */
var int clientCount;
/** maximum number of client connections that may be open */
var(Config) config int iMaxClients;

/** access policy, allow or deny*/
enum EAPolicy
{
    AP_Allow,
    AP_Deny,
};
/** per hostmask access policy, both * and ? wildcards in the IP address are supported */
struct APEntry
{
    var string hostmask;
    var EAPolicy policy;
};
/** controlls from where clients may connect, order is important */
var(AccessPolicy) config array<APEntry> AccessPolicy;

/**
    identifier of the interface
    format: name/version
*/
var const string Ident;
/** CVS Id string */
var const string CVSversion;

var localized string PICat, PILabel[4], PIDescription[4];

/** Called after the object has been created */
function Create(GatewayDaemon gwd)
{
    local IpAddr tmp;
    gateway = gwd;
    gateway.Logf("[Create] Starting:"@Ident, Name, gateway.LOG_INFO);
    ReceiveMode = RequestedReceiveMode;
    LinkMode = RequestedLinkMode;
    if (iListenPort <= 0)
    {
        Error("UnGatewayInterface.iListenPort <= 0");
        return;
    }
    if (BindPort(iListenPort, bUseNextAvailable) != iListenPort && bUseNextAvailable)
    {
        gateway.Logf("[Create] Not used prefered port", Name, gateway.LOG_WARN);
    }
    if (LinkState != STATE_Ready)
    {
        Error("UnGatewayInterface.LinkState != STATE_Ready");
        return;
    }
    if (gateway.hostaddress == "")
    {
        gateway.hostaddress = "0.0.0.0"; // fail safe
        GetLocalIP(tmp);
        gateway.hostaddress = IpAddrToString(tmp);
        gateway.hostaddress = Left(gateway.hostaddress, InStr(gateway.hostaddress, ":"));
    }
    if (!Listen()) gateway.Logf("[Create] Call to Listed() failed", Name, gateway.LOG_ERR);
    gateway.Logf("[Create] Listening on port"@port, Name, gateway.LOG_INFO);
    gateway.Logf("Created", Name, gateway.LOG_EVENT);
}

/** client connection opened, check for valid client actor and limit connections */
event GainedChild(Actor Other)
{
    gateway.Logf("GainedChild", Name, gateway.LOG_EVENT);
    if (UnGatewayClient(Other) == none)
    {
        gateway.Logf("[GainedChild] Gained unwanted child"@Other, Name, gateway.LOG_ERR);
        Other.Destroyed();
        Other = none;
        return;
    }
    else {
        clientCount++;
        if(iMaxClients > 0 && clientCount > iMaxClients && LinkState == STATE_Listening)
        {
            gateway.Logf("[GainedChild] clientCount > iMaxClients = closing port", Name, gateway.LOG_WARN);
            Close();
        }
        UnGatewayClient(Other).Interface = self;
        GainedClient(UnGatewayClient(Other));
    }
}

/** should be overwritten */
function GainedClient(UnGatewayClient client);

event LostChild(Actor Other)
{
    gateway.Logf("LostChild", Name, gateway.LOG_EVENT);
    if (UnGatewayClient(Other) != none)
    {
        clientCount--;
        if(iMaxClients > 0 && clientCount <= iMaxClients && LinkState != STATE_Listening)
        {
            gateway.Logf("[GainedChild] clientCount <= iMaxClients = opening port", Name, gateway.LOG_WARN);
            Listen();
        }
        LostClient(UnGatewayClient(Other));
    }
}

/** should be overwritten */
function LostClient(UnGatewayClient client);

/**
    will be called when a new client was successfully logged in,
    clients should call the daemon's NotifyClientJoin function when they have
    logged in into the system
*/
function NotifyClientJoin(UnGatewayClient client);

/** Will be called when a new client left. */
function NotifyClientLeave(UnGatewayClient client);

/** check if inaddr conforms to the access policy */
function bool CheckAccessPolicy(IpAddr inaddr)
{
    local string addr;
    local int i;
    local bool res;

    res = true;
    addr = IpAddrToString(inaddr);
    addr = left(addr, InStr(Addr, ":"));
    for (i = 0; i < AccessPolicy.length; i++)
    {
        if (class'wString'.static.MaskedCompare(addr, AccessPolicy[i].hostmask))
        {
            res = AccessPolicy[i].policy == AP_Allow;
        }
    }
    gateway.Logf("CheckAccessPolicy("$addr$") ="@res, Name, gateway.LOG_EVENT);
    return res;
}

static function FillPlayInfo(PlayInfo PlayInfo)
{
    super.FillPlayInfo(PlayInfo);
    PlayInfo.AddSetting(default.PICat, "iListenPort", default.PILabel[0], 255, 1, "Text", "5;1:65535");
    PlayInfo.AddSetting(default.PICat, "bUseNextAvailable", default.PILabel[1], 1, 1, "Check");
    PlayInfo.AddSetting(default.PICat, "iMaxClients", default.PILabel[2], 255, 1, "Text", "3;1:255");
    PlayInfo.AddSetting(default.PICat, "AcceptClass", default.PILabel[3], 255, 1, "Custom");
    default.AcceptClass.static.FillPlayInfo(PlayInfo);
}

static event string GetDescriptionText(string PropName)
{
    switch (PropName)
    {
        case "iListenPort":         return default.PIDescription[0];
        case "bUseNextAvailable":   return default.PIDescription[1];
        case "iMaxClients":         return default.PIDescription[2];
    }
    return "";
}

defaultproperties
{
    iListenPort=0
    AcceptClass=class'UnGateway.UnGatewayClient'
    bUseNextAvailable=false
    RequestedReceiveMode=RMODE_Event
    RequestedLinkMode=MODE_Line
    iMaxClients=10
    CVSversion="$Id: UnGatewayInterface.uc,v 1.11 2004/10/20 14:08:47 elmuerte Exp $"

    AccessPolicy[0]=(hostmask="*",policy=AP_Allow)

    PILabel[0]="Listen port"
    PIDescription[0]="The port this interface will listen on. It should be an unused port."
    PILabel[1]="Use next available"
    PIDescription[1]="If the current listen port is in use, pick the next available port."
    PILabel[2]="Maximum clients"
    PIDescription[2]="The maximum number of clients that may connect to this interface. if the maximum is reached new clients will be rejected."
    PILabel[3]="Access policy"
    PIDescription[3]="Access policy for this interface, this is a per interface setting."
}
