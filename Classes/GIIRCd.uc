/**
	GIIRCd
	IRC server
	$Id: GIIRCd.uc,v 1.6 2003/09/11 10:00:41 elmuerte Exp $
*/
class GIIRCd extends UnGatewayInterface;

/** we need to keep a record of clients here */
var array<GCIRC> Clients;

struct IRCUserRecord
{
	var string Nick;
	var string Userhost;
	var string RealName;
	var PlayerController PC;
	var GCIRC client;
};
var array<IRCUserRecord> IRCUsers;

struct LocalChannelRecord
{
	var string Name;		// channel name
	var string Topic;		// channel topic
	var int Topictime;
	var bool bLocal;		// local only
	var bool bAdmin;		// is admin channel
	var string Mode;
	var string Key;
	var int Limit;
	var int Count;
	var int TimeStamp;
	var array<string> Bans;
};
var array<LocalChannelRecord> Channels;

function Create(GatewayDaemon gwd)
{
	Super.Create(gwd);
	CreateChannel("&admin",, true, true);
	CreateChannel("#"$gateway.hostaddress$"_"$Level.Game.GetServerPort());
}

function GainedClient(UnGatewayClient client)
{
	local int i;
	for (i = 0; i < Clients.length; i++)
	{
		if (Clients[i] == GCIRC(client)) return;
	}
	Clients.length = Clients.length+1;
	Clients[Clients.length-1] = GCIRC(client);
}

function LostClient(UnGatewayClient client)
{
	local int i;
	for (i = 0; i < Clients.length; i++)
	{
		if (Clients[i] == GCIRC(client))
		{
			GCIRC(client).ircExecQuit(, false); // just to broadcast
			Clients.Remove(i, 1);
			return;
		}
	}
}

/** fixed a name to conform to the IRC standard */
function string FixName(string username)
{
	// TODO:
	return username;
}

/** check a nick name to be valid */
function bool CheckNickName(GCIRC client, string RequestedName)
{
	local int i;
	if (RequestedName != FixName(RequestedName))
	{
		Client.SendIRC(RequestedName@":ERR_ERRONEUSNICKNAME", "432");
		return false;
	}
	for (i = 0; i < IRCUsers.length; i++)
	{
		if (RequestedName != IRCUsers[i].Nick)
		{
			Client.SendIRC(RequestedName@":ERR_NICKNAMEINUSE", "433");
			return false;
		}
	}	
	client.sUsername = RequestedName;
}

/** find the IRC user record for a client */
function int GetIRCUser(GCIRC client, optional bool bDontAdd)
{
	local int i;
	for (i = 0; i < IRCUsers.length; i++)
	{
		if (IRCUsers[i].Client == client) return i;
	}
	if (bDontAdd) return -1;
	IRCUsers.length = IRCUsers.length+1;
	IRCUsers[IRCUsers.length-1].Nick = client.sUsername;
	IRCUsers[IRCUsers.length-1].Userhost = client.sUserhost;
	IRCUsers[IRCUsers.length-1].PC = client.PlayerController;
	return IRCUsers.length-1;
}

/** return if a userhost is banned from a channel */
function bool IsBanned(int ChannelId, string UserHost)
{
	return false;
}

function CreateChannel(string ChannelName, optional string Topic, optional bool bLocal, optional bool bAdmin)
{
}

defaultproperties
{
	Ident="IRC/100"
	AcceptClass=class'UnGateway.GCIRC'
}