/*******************************************************************************
	GIIRCd																		<br />
	IRC server																	<br />
																				<br />
	Authors:	Michiel 'El Muerte' Hendriks &lt;elmuerte@drunksnipers.com&gt;	<br />
																				<br />
	Copyright 2003, 2004 Michiel "El Muerte" Hendriks							<br />
	Released under the Open Unreal Mod License									<br />
	http://wiki.beyondunreal.com/wiki/OpenUnrealModLicense						<br />
	<!-- $Id: GIIRCd.uc,v 1.15 2004/05/08 21:49:32 elmuerte Exp $ -->
*******************************************************************************/
/*
	TODO:
	- manage new imgateway players via linked list
	- detect player parting (NotifyLogout in GameInfo)
*/
class GIIRCd extends UnGatewayInterface;

/** we need to keep a record of clients here */
var array<GCIRC> Clients;

/** IRC user record, every user on the IRC server and in game should have it's own record */
struct IRCUserRecord
{
	/** the nickname used */
	var string Nick;
	/** username@hostname */
	var string Userhost;
	/** real name */
	var string RealName;
	/** irc user mode */
	var string Mode;
	/** the player controller associated with this user */
	var PlayerController PC;
	/** the IRC client connection */
	var GCIRC client;
	/** for disconnected clients (also whowas) */
	var bool bDead;
};
/** list with irc users, connected or dead */
var array<IRCUserRecord> IRCUsers;

/** registered channels */
var array<UGIRCChannel> Channels;
/** IRC Channel class to create */
var class<UGIRCChannel> IRCChannelClass;

/** name of the game channel */
var string GameChannel;
/** local channel for administration */
var string AdminChannel;

/** create the initial channels */
function Create(GatewayDaemon gwd)
{
	Super.Create(gwd);
	AdminChannel = "&admin";
	CreateChannel(AdminChannel, "Server administation channel - prefix message with a '.' to execute commands", true, true, true);
	GameChannel = "#"$gateway.hostaddress$"_"$Level.Game.GetServerPort();
	CreateChannel(GameChannel, Level.Game.GameReplicationInfo.ServerName@"-"@Level.Game.GameName@"-"@Level.Title,,,true);
}

/** register the new client */
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

/** remove this client from our internal list */
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
			if (IRCUsers[i].bDead)
			{
				IRCUsers[i].Nick = ""; // kill nick but keep record
				break;
			}
			else {
				Client.SendIRC(RequestedName@":Nickname is already in use", "433"); // ERR_NICKNAMEINUSE
				return false;
			}
		}
	}
	if (client.ClientID >= 0) IRCUsers[client.ClientID].Nick = RequestedName;
	client.sUsername = RequestedName;
	client.PlayerController.SetName(client.sUsername);
	return true;
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

/** find the IRC user record for a PlayerController */
function int GetSystemIRCUser(PlayerController PC, optional bool bDontAdd, optional bool bDontAnnounce)
{
	local int i;
	if (PC == none) return -1;
	for (i = 0; i < IRCUsers.length; i++)
	{
		if (IRCUsers[i].PC == PC) return i;
	}
	if (bDontAdd) return -1;
	gateway.Logf("[GetSystemIRCUser] Creating IRC user:"@PC.PlayerReplicationInfo.PlayerName, Name, gateway.LOG_EVENT);
	IRCUsers.length = IRCUsers.length+1;
	IRCUsers[IRCUsers.length-1].Nick = PC.PlayerReplicationInfo.PlayerName;
	IRCUsers[IRCUsers.length-1].Userhost = PC.Name$"@"$PC.GetPlayerNetworkAddress();
	IRCUsers[IRCUsers.length-1].PC = PC;
	if (UnGatewayPlayer(PC) != none)
	{
		IRCUsers[IRCUsers.length-1].Userhost = UnGatewayPlayer(PC).client.Name$"@"$UnGatewayPlayer(PC).client.ClientAddress;
	}
	IRCUsers[IRCUsers.length-1].Client = none;
	IRCUsers[IRCUsers.length-1].Mode = "i"; // always invisible
	GetChannel(GameChannel).JoinUser(IRCUsers.length-1);
	if (PC.PlayerReplicationInfo.bAdmin) GetChannel(GameChannel).SetChannelModeUser(IRCUsers.length-1, "o");
	return IRCUsers.length-1;
}

/** return if a userhost is banned from a channel */
function bool IsBanned(int ChannelId, string UserHost)
{
	if (ChannelId < 0 || ChannelId >= Channels.length) return false;
	return Channels[ChannelId].IsBanned(UserHost);
	return false;
}

/** create a channel */
function UGIRCChannel CreateChannel(string ChannelName, optional string Topic, optional bool bLocal, optional bool bAdmin, optional bool bSpecial)
{
	local int i;
	for (i = 0; i < Channels.length; i++)
	{
		if (Channels[i].ChannelName ~= ChannelName) return Channels[i];
	}
	gateway.Logf("[CreateChannel] Creating channel:"@ChannelName, Name, gateway.LOG_EVENT);
	Channels.length = Channels.length+1;
	Channels[Channels.length-1] = new IRCChannelClass;
	Channels[Channels.length-1].IRCd = self;
	Channels[Channels.length-1].ChannelName = ChannelName;
	Channels[Channels.length-1].Topic = Topic;
	Channels[Channels.length-1].bLocal = bLocal;
	Channels[Channels.length-1].bAdmin = bAdmin;
	Channels[Channels.length-1].bSpecial = bSpecial;
	Channels[Channels.length-1].Limit = 0;
	Channels[Channels.length-1].Mode = "nt"; // TODO: hardcode
	return Channels[Channels.length-1];
}

/** find the channel id */
function UGIRCChannel GetChannel(string ChannelName)
{
	local int i;
	for (i = 0; i < Channels.length; i++)
	{
		if (Channels[i].ChannelName ~= ChannelName) return Channels[i];
	}
	return none;
}

/** find the user id */
function int GetNick(string Nickname)
{
	local int i;
	for (i = 0; i < IRCUsers.Length; i++)
	{
		if (IRCUsers[i].Nick ~= Nickname) return i;
	}
	return -1;
}

/**
	send this text to all clients except self
*/
function BroadcastMessage(coerce string message, int id, optional GCIRC origin)
{
	Channels[id].BroadcastMessage(message, origin);
}

/** send this text to all clients that share the same channels (amsg) */
function BroadcastMessageList(coerce string message, array<UGIRCChannel> id, optional GCIRC origin)
{
	local int i,j;
	local array<int> remoteclients;
	for (i = 0; i < id.length; i++)
	{
		for (j = 0; j < id[i].Users.length; j++)
		{
			remoteclients[remoteclients.length] = id[i].Users[j].uid;
		}
	}
	if (remoteclients.length == 0) return;
	class'wArray'.static.SortI(remoteclients);
	j = -1;
	for (i = 0; i < remoteclients.length; i++)
	{
		if (remoteclients[i] < 0) continue;
		if (j == remoteclients[i]) continue;
		j = remoteclients[i];
  		if (IRCUsers[remoteclients[i]].client == origin) continue;
  		gateway.Logf("[BroadcastMessageList] Receiver:"@IRCUsers[remoteclients[i]].client, Name, gateway.LOG_DEBUG);
		IRCUsers[remoteclients[i]].client.SendText(message);
	}
}

/** check for new players */
event Tick(float deltatime)
{
	local Controller C;
	super.Tick(deltatime);
	C = Level.ControllerList;
	while (C != none)
	{
		if (PlayerController(C) != none)
		{
			if (UnGatewayPlayer(C) == none)
			{
				GetSystemIRCUser(PlayerController(C));
			}
		}
		C = C.nextController;
	}
}

defaultproperties
{
	Ident="IRC/100"
	CVSversion="$Id: GIIRCd.uc,v 1.15 2004/05/08 21:49:32 elmuerte Exp $"
	AcceptClass=class'UnGateway.GCIRC'
	IRCChannelClass=class'UnGateway.UGIRCChannel'
}
