/*******************************************************************************
	IRC Channel actor															<br />
	Part of the IRC interface for UnGateway										<br />
																				<br />
	Authors:	Michiel 'El Muerte' Hendriks &lt;elmuerte@drunksnipers.com&gt;	<br />
																				<br />
	Copyright 2003, 2004 Michiel "El Muerte" Hendriks							<br />
	Released under the Open Unreal Mod License									<br />
	http://wiki.beyondunreal.com/wiki/OpenUnrealModLicense						<br />
	<!-- $Id: UGIRCChannel.uc,v 1.4 2004/05/21 20:56:34 elmuerte Exp $ -->
*******************************************************************************/
class UGIRCChannel extends Object;

/** pointer to our server daemon */
var GIIRCd IRCd;

/** name of the channel */
var string ChannelName;
/** channel creation time */
var int TimeStamp;

/** channel topic */
var string Topic;
/** timestamp when this topic was set */
var int Topictime;

/** local only, only exists on this server */
var bool bLocal;
/** is admin channel */
var bool bAdmin;
/** is a special server channel, this means local admins get op */
var bool bSpecial;

/** channel mode */
var string Mode;
/** the key required to join this channel */
var string Key;
/** the user limit for this channel */
var int Limit;

/** bans set in this channel */
var array<string> Bans;

/** information about a user in a channel */
struct ChannelUserRecord
{
	/** ID in the IRCUsers table */
	var int uid;
	var bool bOp;
	var bool bVoice;
	var bool bHalfOp;
};
/** information about the users in this channel */
var array<ChannelUserRecord> Users;

/** return if a userhost is banned from a channel */
function bool IsBanned(string UserHost)
{
	local int i;
	for (i = 0; i < Bans.length; i++)
	{
		if (class'wString'.static.MaskedCompare(UserHost, Bans[i])) return true;
	}
	return false;
}

/**
	send this text to all clients except self
*/
function BroadcastMessage(coerce string message, optional GCIRC origin)
{
	local int i;
	local GCIRC remoteclient;

	IRCd.gateway.Logf("[BroadcastMessage] "$message, Name, IRCd.gateway.LOG_DEBUG);
	for (i = 0; i < Users.length; i++)
	{
		remoteclient = IRCd.IRCUsers[Users[i].uid].client;
		if (remoteclient != none && remoteclient != origin)
		{
			IRCd.gateway.Logf("[BroadcastMessage] Receiver:"@remoteclient, Name, IRCd.gateway.LOG_DEBUG);
			remoteclient.SendText(message);
		}
	}
}

/** set a user mode in a channel, not optimized */
function SetChannelModeUser(int uid, optional string add, optional string revoke)
{
	local int i;
	if (uid == -1) return;
	for (i = 0; i < Users.length; i++)
	{
		if (Users[i].uid == uid) break;
	}
	if (i == Users.length) return;
	// grant
	if (InStr(add, "o") > -1)
	{
		Users[i].bOp = true;
  		BroadcastMessage(":"$IRCd.gateway.hostname@"MODE"@ChannelName@"+o"@IRCd.IRCUsers[uid].Nick);
	}
	if (InStr(add, "v") > -1)
	{
		Users[i].bOp = true;
  		BroadcastMessage(":"$IRCd.gateway.hostname@"MODE"@ChannelName@"+v"@IRCd.IRCUsers[uid].Nick);
	}
	if (InStr(add, "h") > -1)
	{
		Users[i].bOp = true;
  		BroadcastMessage(":"$IRCd.gateway.hostname@"MODE"@ChannelName@"+h"@IRCd.IRCUsers[uid].Nick);
	}
	// revoke
	if (InStr(revoke, "o") > -1)
	{
		Users[i].bOp = false;
  		BroadcastMessage(":"$IRCd.gateway.hostname@"MODE"@ChannelName@"-o"@IRCd.IRCUsers[uid].Nick);
	}
	if (InStr(revoke, "v") > -1)
	{
		Users[i].bOp = false;
  		BroadcastMessage(":"$IRCd.gateway.hostname@"MODE"@ChannelName@"-v"@IRCd.IRCUsers[uid].Nick);
	}
	if (InStr(revoke, "h") > -1)
	{
		Users[i].bOp = false;
  		BroadcastMessage(":"$IRCd.gateway.hostname@"MODE"@ChannelName@"-h"@IRCd.IRCUsers[uid].Nick);
	}
}

/** */
function PartUser(int userid, optional bool bDontAnnounce)
{
	local int j;
	for (j = 0; j < users.length; j++)
	{
		if (users[j].uid == userid)
		{
			users.remove(j, 1);
			if (bDontAnnounce) return;
			BroadcastMessage(":"$IRCd.GetIRCUserHost(userid)@"PART"@ChannelName);
			return;
		}
	}
}

/** add a user to this channel */
function JoinUser(int userid, optional bool bDontAnnounce)
{
	local int j;
	for (j = 0; j < users.length; j++)
	{
		if (users[j].uid == userid) return;
	}
	users.length = j+1;
	users[j].uid = userid;
	BroadcastMessage(":"$IRCd.GetIRCUserHost(userid)@"JOIN"@ChannelName);
}

/** check if a channel name is valid */
static function bool checkValidChanName(string channel)
{
	if ((Left(channel, 1) != "#" && Left(channel, 1) != "&") || (InStr(channel, ",") > -1) || (InStr(channel, Chr(7)) > -1))
	{
		return false;
	}
	return true;
}

/** add a new ban */
function bool AddBan(string mask)
{
	return false;
}

/** revoke a ban */
function bool RevokeBan(string mask)
{
	return false;
}
