/*******************************************************************************
	GIIRCd																		<br />
	IRC server																	<br />
																				<br />
	Authors:	Michiel 'El Muerte' Hendriks &lt;elmuerte@drunksnipers.com&gt;	<br />
																				<br />
	Copyright 2003, 2004 Michiel "El Muerte" Hendriks							<br />
	Released under the Open Unreal Mod License									<br />
	http://wiki.beyondunreal.com/wiki/OpenUnrealModLicense						<br />
	<!-- $Id: GIIRCd.uc,v 1.18 2004/05/21 20:56:34 elmuerte Exp $ -->
*******************************************************************************/

class GIIRCd extends UnGatewayInterface;

/** we need to keep a record of clients here */
var array<GCIRC> Clients;

/** IRC user record, every user on the IRC server and in game should have it's own record */
struct IRCUserRecord
{
	/** the nickname used */
	var string Nick;
	/** username@hostname */
	var string ident,host;
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
	/** @ignore */
	var int x;
};
/** list with irc users, connected or dead */
var array<IRCUserRecord> IRCUsers;

/** registered channels */
var array<UGIRCChannel> Channels;
/** IRC Channel class to create */
var class<UGIRCChannel> IRCChannelClass;

/** name of the game channel */
var string GameChannelName;
var UGIRCChannel GameChannel;
/** local channel for administration */
var string AdminChannelName;
var UGIRCChannel AdminChannel;

/** create the initial channels */
function Create(GatewayDaemon gwd)
{
	Super.Create(gwd);
	AdminChannelName = "&admin";
	AdminChannel = CreateChannel(AdminChannelName, "Server administation channel - prefix message with a '.' to execute commands", true, true, true);
	GameChannelName = "#"$gateway.hostaddress$"_"$Level.Game.GetServerPort();
	GameChannel = CreateChannel(GameChannelName, Level.Game.GameReplicationInfo.ServerName@"-"@Level.Game.GameName@"-"@Level.Title,,,true);
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
			if (GCIRC(client).ClientID > -1)
			{
				IRCUsers[GCIRC(client).ClientID].bDead = true;
				IRCUsers[GCIRC(client).ClientID].Client = none;
				IRCUsers[GCIRC(client).ClientID].PC = none;
			}
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

/** get a unique name */
function string GetUniqueName(string base)
{
	local int i,j;
	local string newname;

	newname = base;
	j = 1;
loop:
	for (i = 0; i < IRCUsers.Length; i++)
	{
		if ((IRCUsers[i].Nick ~= newname) && (!IRCUsers[i].bDead))
		{
			newname = base$(j++);
			goto loop;
		}
	}
	return newname;
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
	IRCUsers[IRCUsers.length-1].host = Left(client.sUserhost, InStr(client.sUserhost, "@"));
	IRCUsers[IRCUsers.length-1].ident = Mid(client.sUserhost, InStr(client.sUserhost, "@")+1);
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
	IRCUsers[IRCUsers.length-1].Nick = GetUniqueName(fixname(PC.PlayerReplicationInfo.PlayerName));
	IRCUsers[IRCUsers.length-1].RealName = PC.PlayerReplicationInfo.PlayerName;
	IRCUsers[IRCUsers.length-1].host = PC.GetPlayerNetworkAddress();
	// strip port
	IRCUsers[IRCUsers.length-1].host = Left(IRCUsers[IRCUsers.length-1].host, InStr(IRCUsers[IRCUsers.length-1].host, ":"));
	if (IRCUsers[IRCUsers.length-1].host == "") IRCUsers[IRCUsers.length-1].host = gateway.hostname;
	IRCUsers[IRCUsers.length-1].ident = PC.GetPlayerIDHash();
	IRCUsers[IRCUsers.length-1].PC = PC;
	if (UnGatewayPlayer(PC) != none)
	{
		IRCUsers[IRCUsers.length-1].host = UnGatewayPlayer(PC).client.ClientAddress;
		IRCUsers[IRCUsers.length-1].ident = string(UnGatewayPlayer(PC).client.Name);
	}
	IRCUsers[IRCUsers.length-1].Client = none;
	IRCUsers[IRCUsers.length-1].Mode = "i"; // always invisible
	GameChannel.JoinUser(IRCUsers.length-1);
	if (PC.PlayerReplicationInfo.bAdmin) GameChannel.SetChannelModeUser(IRCUsers.length-1, "o");
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
function int GetNick(optional string Nickname, optional PlayerReplicationInfo PRI)
{
	local int i;
	if (PRI != none)
	{
		for (i = 0; i < IRCUsers.Length; i++)
		{
			if (IRCUsers[i].PC.PlayerReplicationInfo == PRI) return i;
		}
	}
	else if (Nickname != "")
	{
		for (i = 0; i < IRCUsers.Length; i++)
		{
			if (IRCUsers[i].Nick ~= Nickname) return i;
		}
	}
	return -1;
}

/** return the user!ident@host mask */
function string GetIRCUserHost(int idx, optional bool bAdmin, optional bool bNoNick)
{
	local string tmp;
	if (idx < 0 || idx >= IRCUsers.Length) return "";
	if (!bNoNick) tmp = IRCUsers[idx].Nick$"!";
	if (bAdmin) tmp $= IRCUsers[idx].ident$"@"$IRCUsers[idx].host;
	else {
		tmp $= "~"$right(IRCUsers[idx].ident, 16)$"@";
		tmp $= left(IRCUsers[idx].host, 0.75*len(IRCUsers[idx].host))$".vhost";
	}
	return tmp;
}

/** grant/revoke usermode settings */
function bool IRCUserMode(int idx, string mode, bool grant)
{
	if (idx < 0 || idx >= IRCUsers.Length) return false;
	if (Len(mode) > 1) return false;
	if (grant)
	{
		if (InStr(IRCUsers[idx].Mode, mode) > -1) return false;
		IRCUsers[idx].Mode $= mode;
	}
	else {
		if (InStr(IRCUsers[idx].Mode, mode) == -1) return false;
		IRCUsers[idx].Mode = repl(IRCUsers[idx].Mode, mode, "");
	}
	return true;
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
	local int i, x;
	local string tmp;

	super.Tick(deltatime);
	x = rand(maxint);
	for (C = Level.ControllerList; C != none; C = C.nextController)
	{
		if (PlayerController(C) != none && UnGatewayPlayer(C) == none)
		{
			i = GetSystemIRCUser(PlayerController(C));
			if (i > -1)
			{
				if (IRCUsers[i].RealName != C.PlayerReplicationInfo.PlayerName)
				{
					tmp = GetUniqueName(FixName(C.PlayerReplicationInfo.PlayerName));
					GameChannel.BroadcastMessage(":"$GetIRCUserHost(i)@"NICK"@tmp);
					IRCUsers[i].Nick = tmp;
					IRCUsers[i].RealName = C.PlayerReplicationInfo.PlayerName;
				}
				IRCUsers[i].x = x;
			}
		}
	}
	for (i = 0; i < IRCUsers.length; i++)
	{
		if (IRCUsers[i].bDead) continue;
		if (UnGatewayPlayer(IRCUsers[i].PC) != none) continue;
		if (IRCUsers[i].x == x) continue;

		GameChannel.BroadcastMessage(":"$GetIRCUserHost(i)@"QUIT :Logout");
		IRCUsers[i].bDead = true;
		IRCUsers[i].PC = none;
		IRCUsers[i].client = none;
	}
}

function NotifyClientJoin(UnGatewayClient client)
{
	if (!Client.IsA(AcceptClass.default.Name)) // our clients will automatically log in
	{
		GetSystemIRCUser(client.PlayerController);
	}
}

function NotifyClientLeave(UnGatewayClient client)
{
	local int idx;
	if (!Client.IsA(AcceptClass.default.Name)) // our clients will automatically log out
	{
		idx = GetSystemIRCUser(client.PlayerController, true);
		if (idx > -1)
		{
			GameChannel.BroadcastMessage(":"$GetIRCUserHost(idx)@"QUIT :Logout");
			IRCUsers[idx].bDead = true;
			IRCUsers[idx].PC = none;
			IRCUsers[idx].client = none;
		}
	}
}

defaultproperties
{
	Ident="IRC/101"
	CVSversion="$Id: GIIRCd.uc,v 1.18 2004/05/21 20:56:34 elmuerte Exp $"
	AcceptClass=class'UnGateway.GCIRC'
	IRCChannelClass=class'UnGateway.UGIRCChannel'
}
