/*******************************************************************************
	UnGatewayInterface															<br />
	Interface for TCP based services linked in the Gateway system				<br />
																				<br />
	Authors:	Michiel 'El Muerte' Hendriks &lt;elmuerte@drunksnipers.com&gt;	<br />
																				<br />
	Copyright 2003, 2004 Michiel "El Muerte" Hendriks							<br />
	Released under the Open Unreal Mod License									<br />
	http://wiki.beyondunreal.com/wiki/OpenUnrealModLicense						<br />
	<!-- $Id: UnGatewayInterface.uc,v 1.5 2004/04/06 19:12:00 elmuerte Exp $ -->
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

/**
	identifier of the interface
	format: name/version
*/
var const string Ident;
/** CVS Id string */
var const string CVSversion;

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
	CVSversion="$Id: UnGatewayInterface.uc,v 1.5 2004/04/06 19:12:00 elmuerte Exp $"
}
