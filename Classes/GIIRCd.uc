/**
	GIIRCd
	IRC server
	$Id: GIIRCd.uc,v 1.11 2004/01/02 09:19:24 elmuerte Exp $
*/
class GIIRCd extends UnGatewayInterface;

/** we need to keep a record of clients here */
var array<GCIRC> Clients;

struct IRCUserRecord
{
	var string Nick;
	var string Userhost;
	var string RealName;
	var string Mode;
	var PlayerController PC;
	var GCIRC client;
	var bool bDead; // for disconnected clients (also whowas)
};
var array<IRCUserRecord> IRCUsers;

struct ChannelUserRecord
{
	var int uid;
	var bool bOp;
	var bool bVoice;
	var bool bHalfOp;
};

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
	var int TimeStamp;
	var array<string> Bans;
	var array<ChannelUserRecord> Users; // pointer to the IRCUsers list
	var bool bDead; // for disconnected clients (also whowas)
};
var array<LocalChannelRecord> Channels;

function Create(GatewayDaemon gwd)
{
	Super.Create(gwd);
	CreateChannel("&admin", "Server administation channel", true, true);
	CreateChannel("#"$gateway.hostaddress$"_"$Level.Game.GetServerPort(), Level.Game.GameReplicationInfo.ServerName@"-"@Level.Game.GameName@"-"@Level.Title);
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
			IRCUsers[GCIRC(client).ClientID].bDead = true;
			IRCUsers[GCIRC(client).ClientID].Client = none;
			IRCUsers[GCIRC(client).ClientID].PC = none;
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
		Client.SendIRC(RequestedName@":Erroneus nickname", "432"); // ERR_ERRONEUSNICKNAME
		return false;
	}
	for (i = 0; i < IRCUsers.length; i++)
	{
		if (RequestedName ~= IRCUsers[i].Nick)
		{
			Client.SendIRC(RequestedName@":Nickname is already in use", "433"); // ERR_NICKNAMEINUSE
			return false;
		}
	}
	if (client.ClientID > 0) IRCUsers[client.ClientID].Nick = RequestedName;
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
	gateway.Logf("[GetIRCUser] Creating IRC user:"@client.sUsername$"!"$client.sUserhost, Name, gateway.LOG_EVENT);
	IRCUsers.length = IRCUsers.length+1;
	IRCUsers[IRCUsers.length-1].Nick = client.sUsername;
	IRCUsers[IRCUsers.length-1].Userhost = client.sUserhost;
	IRCUsers[IRCUsers.length-1].PC = client.PlayerController;
	IRCUsers[IRCUsers.length-1].Client = client;
	IRCUsers[IRCUsers.length-1].Mode = "i"; // always invisible
	return IRCUsers.length-1;
}

/** return if a userhost is banned from a channel */
function bool IsBanned(int ChannelId, string UserHost)
{
	local int i;
	if (ChannelId < 0 || ChannelId >= Channels.length) return false;
	for (i = 0; i < Channels[ChannelId].Bans.length; i++)
	{
		if (class'wString'.static.MaskedCompare(UserHost, Channels[ChannelId].Bans[i])) return true;
	}
	return false;
}

/** create a channel */
function int CreateChannel(string ChannelName, optional string Topic, optional bool bLocal, optional bool bAdmin)
{
	local int i;
	for (i = 0; i < Channels.length; i++)
	{
		if (Channels[i].Name ~= ChannelName) return i;
	}
	gateway.Logf("[CreateChannel] Creating channel:"@ChannelName, Name, gateway.LOG_EVENT);
	Channels.length = Channels.length+1;
	Channels[Channels.length-1].Name = ChannelName;
	Channels[Channels.length-1].Topic = Topic;
	Channels[Channels.length-1].bLocal = bLocal;
	Channels[Channels.length-1].bAdmin = bAdmin;
	Channels[Channels.length-1].Limit = 0;
	Channels[Channels.length-1].Mode = "nt"; // TODO: hardcode
	return Channels.length-1;
}

/** find the channel id */
function int GetChannel(string ChannelName)
{
	local int i;
	for (i = 0; i < Channels.length; i++)
	{
		if (Channels[i].Name ~= ChannelName) return i;
	}
	return -1;
}

/**
	send this text to all clients except self
*/
function BroadcastMessage(coerce string message, int id, optional GCIRC origin)
{
	local int i;
	local GCIRC remoteclient;
	gateway.Logf("[BroadcastMessage] "$message, Name, gateway.LOG_DEBUG);
	for (i = 0; i < Channels[id].Users.length; i++)
	{
		remoteclient = IRCUsers[Channels[id].Users[i].uid].client;
		if (remoteclient != none && remoteclient != origin)
		{
			gateway.Logf("[BroadcastMessage] Receiver:"@remoteclient, Name, gateway.LOG_DEBUG);
			remoteclient.SendText(message);
		}
	}
}

defaultproperties
{
	Ident="IRC/100"
	CVSversion="$Id: GIIRCd.uc,v 1.11 2004/01/02 09:19:24 elmuerte Exp $"
	AcceptClass=class'UnGateway.GCIRC'
}
