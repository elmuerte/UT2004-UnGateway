/**
	GIIRCd
	IRC server
	$Id: GIIRCd.uc,v 1.7 2003/09/11 22:06:12 elmuerte Exp $
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
	var bool bDead; // for disconnected clients (also whowas)
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
	var int TimeStamp;
	var array<string> Bans;
	var array<int> Users; // pointer to the IRCUsers list
};
var array<LocalChannelRecord> Channels;

function Create(GatewayDaemon gwd)
{
	Super.Create(gwd);
	CreateChannel("&admin",, true, true);
	CreateChannel("#"$gateway.hostaddress$"_"$Level.Game.GetServerPort(), Level.Game.ServerName@"-"@Level.Game.GameName@"-"@Level.Title);
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
			IRCUsers[client.ClientID].bDead = true;
			IRCUsers[client.ClientID].Client = none;
			IRCUsers[client.ClientID].PC = none;
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
		if (RequestedName != IRCUsers[i].Nick)
		{
			Client.SendIRC(RequestedName@":Nickname is already in use", "433"); // ERR_NICKNAMEINUSE
			return false;
		}
	}	
	IRCUsers[client.ClientID].Nick = RequestedName;
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
	gateway.Logf("[GetIRCUser] Creating IRC used:"@client.sUsername@client, Name, gateway.LOG_EVENT);
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
	return Channels.length-1;
}

function int GetChannel(string ChannelName)
{
	local int i;
	for (i = 0; i < Channels.length; i++)
	{
		if (Channels[i].Name ~= ChannelName) return i;
	}
	return -1;
}

defaultproperties
{
	Ident="IRC/100"
	AcceptClass=class'UnGateway.GCIRC'
}