/**
	UnGatewayInterface
	Interface for TCP based services linked in the Gateway system
	$Id: UnGatewayInterface.uc,v 1.2 2003/09/04 11:26:42 elmuerte Exp $
*/
class UnGatewayInterface extends TcpLink abstract config;

var GatewayDaemon gateway;

var config int iListenPort;
var config bool bUseNextAvailable;

/** requested receive mode to set */
var EReceiveMode RequestedReceiveMode;
/** requested link mode mode to set */
var ELinkMode RequestedLinkMode;

/** current number of client connections open */
var int clientCount;
/** maximum number of client connections that may be open */
var config int iMaxClients;

/** 
	identifier of the interface 
	format: name/version
*/
var const string Ident;

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

/**	client connection opened, check for valid client actor and limit connections */
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

defaultproperties
{
	iListenPort=0
	AcceptClass=class'UnGateway.UnGatewayClient'
	bUseNextAvailable=false
	RequestedReceiveMode=RMODE_Event
	RequestedLinkMode=MODE_Line
	iMaxClients=10
}