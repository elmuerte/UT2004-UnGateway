/*******************************************************************************
	GCIRC																		<br />
	IRC client, spawned from GIIRCd												<br />
	RFC: 1459																	<br />
																				<br />
	Authors:	Michiel 'El Muerte' Hendriks &lt;elmuerte@drunksnipers.com&gt;	<br />
																				<br />
	Copyright 2003, 2004 Michiel "El Muerte" Hendriks							<br />
	Released under the Open Unreal Mod License									<br />
	http://wiki.beyondunreal.com/wiki/OpenUnrealModLicense						<br />
	<!-- $Id: GCIRC.uc,v 1.23 2004/06/02 15:43:18 elmuerte Exp $ -->
*******************************************************************************/
class GCIRC extends UnGatewayClient config;

/** Show the message of the day on login */
var(Config) config bool bShowMotd;
/** if set the user must login with a valid username and password when they register */
var(Config) config bool bMustLogin;
/** Message of the Day */
var(Config) config array<string> MOTD;
/** Maximum Channels a user can join */
var(Config) config int MaxChannels;
/**
	Allow channel creation
	Turning this on will enable remote channels, it's strongly adviced not to enable this
	Note: remote channels are NOT supported
*/
var(Config) config bool bAllowCreateChannel;

/** listening on the channels this client is in */
var array<UGIRCChannel> Channels;

/** userhost string: username@hostname*/
var string sUserhost;
/** users "realname" as claimed during registration */
var string sRealname;
/** the message to broadcast */
var string QuitMessage;

/** pointer to this clients entry in the IRC user list */
var int ClientID;

//!Localized
var localized string PICat, PILabel[5], PIDesc[5];

/** connection closed, clean up and announce to the server */
event Closed()
{
	local int i;

	if (QuitMessage == "") QuitMessage = "Connection reset by peer";
	for (i = 0; i < Channels.length; i++)
	{
		Channels[i].BroadcastMessage(":"$sUsername$"!"$sUserhost@"QUIT :"$QuitMessage, self);
		Channels[i].PartUser(ClientID, true);
	}
	Super.Closed();
}

/** send RAW irc reply */
function SendIRC(string data, coerce string code)
{
	local string nm;
	if ((code == "") || (data == "")) return;
	if (!IsInState('Login')) nm = sUsername;
	else nm = "*";
	// :<server host> <code> <nickname> <additional data>
	SendText(":"$interface.gateway.hostname@code@nm@data);
	//interface.gateway.Logf("[SendIRC] :"$interface.gateway.hostname@code@nm@data, Name, interface.gateway.LOG_DEBUG);
}

function int SendText(coerce string Str)
{
	interface.gateway.Logf("[SendText]"@str, Name, interface.gateway.LOG_DEBUG);
	return super.SendText(str);
}

/**
	Return true if this user is in the channel.
	Using the channel record pointer is faster
*/
function bool IsIn(UGIRCChannel chan)
{
	local int i;
	if (chan == none) return false;
	for (i = 0; i < Channels.length; i++)
	{
		if (Channels[i] == chan) return true;
	}
	return false;
}

/** return true if the player is an admin */
function bool IsAdmin()
{
	return PlayerController.PlayerReplicationInfo.bAdmin;
}

/** user is logging in */
auto state Login
{
	function procLogin(coerce string line)
	{
		local array<string> input;

		if (split(line, " ", input) < 1) return; // always wrong
		input[0] = caps(input[0]);
		switch (input[0])
		{
			// NICK <nickname>
			case "NICK":	if (input.length < 2) SendIRC(":No nickname given", "431"); // ERR_NONICKNAMEGIVEN
							else GIIRCd(Interface).CheckNickName(Self, input[1]); // will check the name and assign it
							break;
			// PASS <password>
			case "PASS":	if (input.length < 2) SendIRC("PASS :Not enough parameters", "461"); // ERR_NEEDMOREPARAMS
							else if (sUsername != "" || sUserhost != "") SendIRC(":You may not reregister", "462"); // ERR_ALREADYREGISTRED
							else sPassword = input[1];
							break;
			// USER <username> <client host> <server host> :<real name>
			case "USER":	if (input.length < 4)
							{
								SendIRC("USER :Not enough parameters", "461"); // ERR_NEEDMOREPARAMS
								break;
							}
							sUserhost = input[1]$"@"$input[2]; // no ident lookup
							sRealname = Mid(line, InStr(line, ":")+1);  // strip :
							break;
			default:		SendIRC(input[0]@":Unknown command", "421"); // ERR_UNKNOWNCOMMAND
		}
		if (sUsername != "" && sUserhost != "")
		{
			if (sPassword != "") // try to login
			{
				if (!interface.gateway.Login(Self, sUsername, sPassword, interface.ident@sUserhost))
				{
					SendIRC(":Password incorrect", "464"); // ERR_PASSWDMISMATCH
			    	Close();
			    	return;
				}
			}
			if (bMustLogin && !IsAdmin())
			{
				SendIRC(":Password incorrect", "464"); // ERR_PASSWDMISMATCH
		    	Close();
		    	return;
			}
			ClientID = GIIRCd(Interface).GetIRCUser(self);
			interface.gateway.Logf("[Login] I am ClientID #"$ClientID, Name, interface.gateway.LOG_DEBUG);
			GIIRCd(Interface).IRCUsers[ClientID].Realname = sRealname;
			PlayerController.SetName(sUsername);
			Interface.gateway.NotifyClientJoin(self);
			GotoState('loggedin');
		}
	}

begin:
	ClientID=-1;
	OnReceiveLine=procLogin;
}

/** user has logged in */
state Loggedin
{
	function procIRC(coerce string line)
	{
		local array<string> input, data1, data2;
		local int i;

		if (split(line, " ", input) < 1) return; // always wrong
		input[0] = caps(input[0]);
		switch (input[0])
		{
			case "NICK":		data1[0] = sUsername$"!"$sUserhost;
								if (input.length < 2) SendIRC(":No nickname given", "431"); // ERR_NONICKNAMEGIVEN
								else if (GIIRCd(Interface).CheckNickName(Self, input[1])) // will check the name and assign it
								{
									GIIRCd(Interface).BroadcastMessageList(":"$data1[0]@"NICK"@sUsername, Channels);
								}
								break;
			case "PASS":		SendIRC(":You may not reregister", "462"); // ERR_ALREADYREGISTRED
								break;
			case "USER":		SendIRC(":You may not reregister", "462"); // ERR_ALREADYREGISTRED
								break;
			case "PING":		if (input.length < 2) SendIRC(":No origin specified", "409"); // ERR_NOORIGIN
								SendText("PONG"@input[1]); break;
			case "MOTD":		ircExecMOTD(); break;
			case "OPER":		if (input.length < 3) SendIRC("OPER :Not enough parameters", "461"); // ERR_NEEDMOREPARAMS
								else {
									//sUsername = input[1]; // don't set the username
									sPassword = input[2];
									if (!interface.gateway.Login(Self, input[1], sPassword, interface.ident@sUserhost))
									{
										SendIRC(":Password incorrect", "464"); // ERR_PASSWDMISMATCH
									}
									else {
										SendIRC(":You are now an IRC operator", "381"); // RPL_YOUREOPER
										if (GIIRCd(interface).IRCUserMode(ClientID, "o", true)) SendIRC("+o", "MODE"); //RPL_UMODEIS
										for (i = 0; i < Channels.length; i++)
										{
											channels[i].SetChannelModeUser(ClientID, "o");
										}
									}
								}
								break;
			case "QUIT":		ircExecQUIT(Mid(line, 6)); break;
			//case "SQUIT":		break; //TODO: NOT YET supported
			case "JOIN":		if (input.length < 2) SendIRC("JOIN :Not enough parameters", "461"); // ERR_NEEDMOREPARAMS
								else {
									split(input[1], ",", data1);
									if (input.length > 2) split(input[1], ",", data2);
									for (i = 0; i < data1.length; i++)
									{
										if (data2.length > i) ircExecJOIN(data1[i], data2[i]);
											else ircExecJOIN(data1[i]);
									}
								}
								break;
			case "PART":		if (input.length < 2) SendIRC("PART :Not enough parameters", "461"); // ERR_NEEDMOREPARAMS
								else {
									split(input[1], ",", data1);
									for (i = 0; i < data1.length; i++)
									{
										ircExecPART(data1[i]);
									}
								}
								break;
			case "MODE":		if (input.length < 2) SendIRC("MODE :Not enough parameters", "461"); // ERR_NEEDMOREPARAMS
								else {
									input.remove(0, 1);
									ircExecMODE(input);
								}
								break;
			case "TOPIC":		if (input.length < 2) SendIRC("TOPIC :Not enough parameters", "461"); // ERR_NEEDMOREPARAMS
								else {
									i = InStr(line, ":");
									if (i > -1)	ircExecTOPIC(input[1], Mid(line, i));
										else ircExecTOPIC(input[1]);
								}
								break;
			case "NAMES":		if (input.length > 1)
								{
									split(input[1], ",", data1);
									for (i = 0; i < data1.length; i++)
									{
										ircExecNAMES(data1[i]);
									}
								}
								else {
									for (i = 0; i < Channels.length; i++) ircExecNAMES(channels[i].ChannelName);
								}
								break;
			case "LIST":		ircExecLIST(); // can only print local channels
								break;
			//case "INVITE":	not supported
			//case "KICK":		break;//TODO: // not yet implemented
			case "VERSION":		if (input.length > 1) ircExecVERSION(input[1]);
								else ircExecVERSION();
								break;
			//case "STATS":		not supported
			//case "LINKS":		not supported, yet
			//case "TIME":		not supported, yet
			//case "CONNECT":	not supported, yet
			//case "TRACE":		not supported
			//case "ADMIN":		not supported, yet
			//case "INFO":		not supported, yet
			case "PRIVMSG":		if (input.length < 3) SendIRC("TOPIC :Not enough parameters", "461"); // ERR_NEEDMOREPARAMS
								else {
									split(input[1], ",", data1);
									i = InStr(line, ":");
									if (i == -1)
									{
										SendIRC(":No text to send", "412"); // ERR_NOTEXTTOSEND
										break;
									}
									input[2] = Mid(line, i);
									if (input[2] == "")
									{
										SendIRC(":No text to send", "412"); // ERR_NOTEXTTOSEND
										break;
									}
									for (i = 0; i < data1.length; i++)
									{
										ircExecPRIVMSG(data1[i], input[2]);
									}
								}
								break;
			case "NOTICE":		if (input.length < 3) break;
								else {
									split(input[1], ",", data1);
									i = InStr(line, ":");
									if (i == -1) break;
									input[2] = Mid(line, i);
									if (input[2] == "") break;
									for (i = 0; i < data1.length; i++)
									{
										ircExecNOTICE(data1[i], input[2]);
									}
								}
								break;
			case "WHO":			if (input.length == 1) ircExecWHO();
								else if (input.length == 2) ircExecWHO(input[1]);
								else if (input.length == 3) ircExecWHO(input[1], (input[2] == "o"));
								break;
			case "WHOIS":		if (input.length < 2) SendIRC("WHOIS :Not enough parameters", "461"); // ERR_NEEDMOREPARAMS
								else {
									if (input.length < 3) split(input[1], ",", data1);
									else split(input[2], ",", data1);
									ircExecWhois(data1); //!TODO: server support
								}
								break;
			case "WHOWAS":		if (input.length < 2) SendIRC("WHOIS :Not enough parameters", "461"); // ERR_NEEDMOREPARAMS
								else {
									ircExecWhowas(input[1]); //!TODO: other params
								}
								break;
			case "KILL":		if (input.length < 3) SendIRC("KILL :Not enough parameters", "461"); // ERR_NEEDMOREPARAMS
								else {
									ircExecKILL(input[1], "...");
								}
								break;
			default:			sendIRC(input[0]@":Unknown command", "421"); // ERR_UNKNOWNCOMMAND
		}
	}

begin:
	OnReceiveLine=procIRC;
	SendIRC(":Welcome to"@Level.GRI.ServerName@sUsername$"!"$sUserhost, "001");
	SendIRC(":Your host is"@interface.gateway.hostname$", running"@Level.EngineVersion, "002");
	SendIRC(":This server was created"@Interface.Gateway.CreationTime, "003");
	ircExecVERSION();
	SendIRC(":There are ... users and ... services on ... servers", "251");
	SendIRC("... :operators online", "252");
	SendIRC("... :unknown connections", "253");
	SendIRC(string(GIIRCd(Interface).Channels.length)$" :channels formed", "254");
	SendIRC(":I have ... users, 0 services and ... servers", "255");
	SendIRC(":Current local users: ... Max: ...", "265");
	SendIRC(":Current global users: ... Max: ...", "252");
	if (bShowMotd) ircExecMOTD();
	if (IsAdmin())
	{
		GIIRCd(interface).IRCUserMode(ClientID, "o", true);
		SendIRC(":You are now an IRC operator", "381");
	}
	SendIRC("+"$GIIRCd(interface).IRCUsers[ClientID].Mode, "MODE");
}

///////////////////////////////// IRC COMMANDS /////////////////////////////////

/** Send the message of the day to the user */
function ircExecMOTD()
{
	local int i;
	local string chans;
	if (MOTD.length == 0)
	{
		SendIRC(":MOTD File is missing", "422"); // ERR_NOMOTD
		return;
	}
	SendIRC(":-"@interface.gateway.hostname@"Message of the Day -", "375");
	for (i = 0; i < GIIRCd(Interface).Channels.length; i++)
	{
		chans $= GIIRCd(Interface).Channels[i].ChannelName$" ";
	}
	for (i = 0; i < MOTD.length; i++)
	{
		MOTD[i] = repl(MOTD[i], "%hostname%", interface.gateway.hostname);
		MOTD[i] = repl(MOTD[i], "%channels%", chans);
		SendIRC(":-"@MOTD[i], "372");
	}
	SendIRC(":End of MOTD command.", "376");
}

/** quit the IRC server */
function ircExecQUIT(optional string QuitMsg)
{
	if (QuitMsg == "") QuitMsg = sUsername;
	QuitMessage = QuitMsg;
	if (LinkState == STATE_Connected) Close();
}

/** join a channel */
function ircExecJOIN(string channel, optional string key)
{
	local UGIRCChannel id;
	if (!GIIRCd(interface).IRCChannelClass.static.checkValidChanName(channel))
	{
		SendIRC(channel@":ERR_BADCHANMASK", "476"); // ERR_BADCHANMASK
		return;
	}
	if (Channels.length >= MaxChannels)
	{
		SendIRC(channel@":You have joined too many channels", "405"); // ERR_TOOMANYCHANNELS
		return;
	}
	id = GIIRCd(Interface).GetChannel(channel);
	if (id == none) // create the channel
	{
		if (!bAllowCreateChannel)
		{
			SendIRC(channel@":No such channel", "403"); // ERR_NOSUCHCHANNEL
			return;
		}
		else {
			id = GIIRCd(Interface).CreateChannel(channel);
		}
	}

	if (IsIn(id)) // already in this channel
	{
	}
	else {
		if (id.Key != "" && id.Key != Key)
		{
			SendIRC(channel@":Cannot join channel (+k)", "475"); // ERR_BADCHANNELKEY
		}
		else if (id.Limit <= id.Users.length && id.Limit > 0)
		{
			SendIRC(channel@":Cannot join channel (+l)", "471"); // ERR_CHANNELISFULL
		}
		else if (id.IsBanned(sUsername$"!"$sUserhost))
		{
			SendIRC(channel@":Cannot join channel (+b)", "474"); // ERR_BANNEDFROMCHAN
		}
		else if (id.bAdmin && !PlayerController.PlayerReplicationInfo.bAdmin)
		{
			SendIRC(channel@":Cannot join channel (+b) (Admin only)", "474"); // ERR_BANNEDFROMCHAN
		}
		else if (InStr(id.Mode, "i") > -1)
		{
			SendIRC(channel@":Cannot join channel (+i)", "473"); // ERR_INVITEONLYCHAN
		}
		else {
			Channels.length = Channels.length+1;
			Channels[Channels.length-1] = id;
			id.Users.length = id.Users.length+1;
			id.Users[id.Users.length-1].uid = ClientID;
			if (id.bSpecial) {}
			else if (id.Users.length == 1) id.Users[id.Users.length-1].bOp = true;
			SendText(":"$sUsername$"!"$sUserhost@"JOIN"@channel);
			ircExecTOPIC(channel);
			ircExecNAMES(channel);
			id.BroadcastMessage(":"$sUsername$"!"$sUserhost@"JOIN"@channel, self);
			if (id.bSpecial)
			{
				if (IsAdmin())
				{
					id.Users[id.Users.length-1].bOp = true;
					id.BroadcastMessage(":"$interface.gateway.hostname@"MODE"@channel@"+o"@sUsername);
				}
			}
		}
	}
}

/** part a channel */
function ircExecPART(string channel)
{
	local int i;
	local UGIRCChannel id;
	id = GIIRCd(Interface).GetChannel(channel);
	if (IsIn(id))
	{
		id.PartUser(ClientID);
		for (i = 0; i < Channels.length; i++)
		{
			if (Channels[i] == id)
			{
				Channels.remove(i, 1);
				break;
			}
		}
	}
	else {
		SendIRC(channel@":You're not on that channel", "442"); // ERR_NOTONCHANNEL
	}
}

/** get or set a channel or user mode */
function ircExecMODE(array<string> args)
{
	local UGIRCChannel id;
	local bool bGrant, bRevoke;
	local int i;

	if (Left(args[0], 1) == "#" || Left(args[0], 1) == "&")
	{
		// chan modes
		id = GIIRCd(Interface).GetChannel(args[0]);
		if (IsIn(id))
		{
			if (args.length < 2)
			{
				// get
				SendIRC(args[0]@"+"$id.mode, "324"); // RPL_CHANNELMODEIS
				if (id.Key != "")
				{
					SendIRC(args[0]@"+k"@id.Key, "324"); // RPL_CHANNELMODEIS
				}
				if (id.Limit > 0)
				{
					SendIRC(args[0]@"+l"@id.Limit, "324"); // RPL_CHANNELMODEIS
				}
			}
			else {
				bGrant = (Left(args[1], 1) == "+");
				bRevoke = (Left(args[1], 1) == "-");
				if (bGrant || bRevoke)
				{
					args[1] = Locs(Mid(args[1], 1));
					if (!IsAdmin())
					{
						SendIRC(id.ChannelName@":You're not channel operator", "482"); //ERR_CHANOPRIVSNEEDED
						return;
					}
				}
				switch (args[1])
				{
					case "b":	if (bGrant)
								{
									if (id.AddBan(args[2])) id.BroadcastMessage(":"$sUsername$"!"$sUserhost@"MODE"@class'wArray'.static.Join(args, " "));
								}
								else if (bRevoke)
								{
									if (id.RevokeBan(args[2])) id.BroadcastMessage(":"$sUsername$"!"$sUserhost@"MODE"@class'wArray'.static.Join(args, " "));
								}
								else {
									for (i = 0; i < id.Bans.length; i++)
									{
										SendIRC(id.ChannelName@id.Bans[i], "367"); //RPL_BANLIST
									}
									SendIRC(id.ChannelName@":End of channel ban list", "368"); //RPL_ENDOFBANLIST
								}
								break;

					default:	SendIRC("MODE :Not enough parameters", "461"); //ERR_NEEDMOREPARAMS
				}
			}
		}
		else {
			SendIRC(args[0]@":You're not on that channel", "442"); // ERR_NOTONCHANNEL
		}
	}
	else {
		// nick modes
	}
}

/** get or set the channel topic */
function ircExecTOPIC(string channel, optional string newTopic, optional UGIRCChannel id)
{
	if (channel != "") id = GIIRCd(Interface).GetChannel(channel);
	if (!IsIn(id))
	{
		SendIRC(channel@":You're not on that channel", "442"); // ERR_NOTONCHANNEL
		return;
	}
	if (newTopic == "")
	{
		if (id.Topic != "")
		{
			SendIRC(channel@":"$id.Topic, "332"); // RPL_TOPIC
		}
		else {
			SendIRC(channel@":No topic is set", "331"); // RPL_NOTOPIC
		}
	}
	else {
		// ERR_CHANOPRIVSNEEDED
	}
}

/** get the names list of a channel */
function ircExecNAMES(optional string channel, optional UGIRCChannel id)
{
	local int i;
	local string tmp;

	if (channel != "") id = GIIRCd(Interface).GetChannel(channel);
	if (!IsIn(id))
	{
		SendIRC(channel@":You're not on that channel", "442"); // ERR_NOTONCHANNEL
		return;
	}
	for (i = 0; i < id.Users.length; i++)
	{
		if (tmp != "") tmp $= " ";
		if (id.Users[i].bOp) tmp $= "@";
		else if (id.Users[i].bHalfop) tmp $= "%";
		else if (id.Users[i].bVoice) tmp $= "+";
		tmp $= GIIRCd(Interface).IRCUsers[id.Users[i].uid].Nick;
		if (i+1 % 10 == 0)
		{
			SendIRC("="@id.ChannelName@":"$tmp, "353"); // RPL_NAMREPLY
			tmp = "";
		}
	}
	if (tmp != "") SendIRC("="@id.ChannelName@":"$tmp, "353"); // RPL_NAMREPLY
	SendIRC(id.ChannelName@":End of /NAMES list", "366"); // RPL_ENDOFNAMES
}

/** return the version information about a server */
function ircExecVERSION(optional string server)
{
	if (server == "")
	{
		SendIRC(":"$interface.gateway.hostname@"UnrealEngine2/"$Level.EngineVersion@Interface.gateway.Ident@Interface.Ident, "004");
		SendIRC("PREFIX=(ov)@+ MODES=1 CHANTYPES=#& MAXCHANNELS="$MaxChannels$" NICKLEN=20 TOPICLEN=160 KICKLEN=160 NETWORK=UnGateway CHANMODES=... :are supported by this server", "004");
	}
	else {
		//...
	}
}

/** send a message to a user or channel */
function ircExecPRIVMSG(string receipt, string text)
{
	local UGIRCChannel id;
	local array<string> cmd;

	if (Left(receipt, 1) == "#" || Left(receipt, 1) == "&")
	{
		id = GIIRCd(Interface).GetChannel(receipt);
		if (!IsIn(id))
		{
			SendIRC(receipt@":You're not on that channel", "442"); // ERR_NOTONCHANNEL
			return;
		}
		if (!id.bSpecial)
		{
			id.BroadcastMessage(":"$sUsername$"!"$sUserhost@"PRIVMSG"@receipt@text, self);
		}
		else {
			if (id == GIIRCd(Interface).GameChannel)
			{
				AdvSplit("say"@Mid(text, 1), " ", cmd);
				Interface.gateway.ExecCommand(self, cmd);
			}
			else if (id == GIIRCd(Interface).AdminChannel)
			{
				if (Mid(text, 1, 1) == ".") // command
				{
					AdvSplit(Mid(text, 2), " ", cmd, "\"");
					Interface.gateway.ExecCommand(self, cmd);
				}
				// adminchat
				else id.BroadcastMessage(":"$sUsername$"!"$sUserhost@"PRIVMSG"@receipt@text, self);
			}
			else {
				//TODO: unknown channel
			}
		}
	}
	else {
		// nick msg
	}
}

/** send a notice */
function ircExecNOTICE(string receipt, string text)
{
	//!TODO: ...
}

/** request information about a user/usermask */
function ircExecWHO(optional string mask, optional bool bOnlyOps)
{
	local int i, uid;
	local string tmp;
	local UGIRCChannel id;

	if (Left(mask, 1) == "#" || Left(mask, 1) == "&")
	{
		id = GIIRCd(Interface).GetChannel(mask);
		if (!IsIn(id))
		{
			SendIRC(mask@":You're not on that channel", "442"); // ERR_NOTONCHANNEL
			return;
		}
		for (i = 0; i < id.Users.length; i++)
		{
			// "<channel> <user> <host> <server> <nick> <H|G>[*][@|+] :<hopcount> <real name>"
			uid = id.Users[i].uid;
			tmp = mask@repl(GIIRCd(Interface).GetIRCUserHost(uid,,true),"@", " ");
			tmp @= interface.gateway.hostname;
			tmp @= GIIRCd(Interface).IRCUsers[uid].Nick;
			Tmp @= "H"; // only H, no away supported
			if (id.Users[i].bOp) tmp $= "@";
			else if (id.Users[i].bHalfop) tmp $= "%";
			else if (id.Users[i].bVoice) tmp $= "+";
			tmp @= ":0"@GIIRCd(Interface).IRCUsers[uid].Realname;
			SendIRC(tmp, "352"); // RPL_WHOREPLY
		}
	}
	else {
		// nick msg
	}
	SendIRC(mask@":End of /WHO list", "315"); // RPL_ENDOFWHO
}

/** return whois information */
function ircExecWhois(array<string> nickmask, optional string server)
{
	local int i, j;
	local string tmp, nicks;
	if (nickmask.length == 0)
	{
		SendIRC(":No nickname given", "431"); // ERR_NONICKNAMEGIVEN
		return;
	}
	for (i = 0; i < nickmask.length; i++)
	{
		for (j = 0; j < GIIRCd(interface).IRCUsers.length; j++)
		{
			if (GIIRCd(interface).IRCUsers[j].bDead) continue;
			if (class'wString'.static.MaskedCompare(GIIRCd(interface).IRCUsers[j].Nick, nickmask[i]))
			{
				tmp = GIIRCd(interface).GetIRCUserHost(j, IsAdmin());
				tmp = repl(repl(tmp, "@", " "), "!" , " ");
				tmp @= "* :"$GIIRCd(interface).IRCUsers[j].RealName;
				SendIRC(tmp, "311"); //RPL_WHOISUSER
				SendIRC(GIIRCd(interface).IRCUsers[j].Nick@interface.gateway.hostname@":"$interface.gateway.hostname@"UnrealEngine2/"$Level.EngineVersion@Interface.gateway.Ident@Interface.Ident, "312"); //RPL_WHOISSERVER
				if (level.Game.AccessControl.IsAdmin(GIIRCd(interface).IRCUsers[j].PC)) SendIRC(GIIRCd(interface).IRCUsers[j].Nick@":is an IRC operator", "313"); //RPL_WHOISOPERATOR

				if (nicks != "") nicks $= ",";
				nicks $= GIIRCd(interface).IRCUsers[j].Nick;
			}
		}
	}
	if (nicks == "") SendIRC(class'wArray'.static.Join(nickmask, ",", true)@":No such nick/channel", "401"); //ERR_NOSUCHNICK
	else SendIRC(nicks@":End of /WHOIS list", "318"); //RPL_ENDOFWHOIS
}

/** return whois information */
function ircExecWhowas(string nick, optional string server)
{
	local int j;
	local string tmp;
	for (j = 0; j < GIIRCd(interface).IRCUsers.length; j++)
	{
		if (!GIIRCd(interface).IRCUsers[j].bDead) continue;
		if (GIIRCd(interface).IRCUsers[j].Nick ~= nick)
		{
			tmp = GIIRCd(interface).GetIRCUserHost(j, IsAdmin());
			tmp = repl(repl(tmp, "@", " "), "!" , " ");
			tmp @= "* :"$GIIRCd(interface).IRCUsers[j].RealName;
			SendIRC(tmp, "314"); //RPL_WHOWASUSER
			SendIRC(GIIRCd(interface).IRCUsers[j].Nick@interface.gateway.hostname@":"$interface.gateway.hostname@"UnrealEngine2/"$Level.EngineVersion@Interface.gateway.Ident@Interface.Ident, "312"); //RPL_WHOISSERVER
			SendIRC(GIIRCd(interface).IRCUsers[j].Nick@":End of WHOWAS", "369"); //RPL_ENDOFWHOWAS
			return;
		}
	}
	SendIRC(nick@":There was no such nickname", "406"); // ERR_NONICKNAMEGIVEN
}

/** kill a client */
function ircExecKILL(string nick, string message)
{
	//...
}

/** list all channels on the server */
function ircExecLIST(optional string mask)
{
	local int i;
	SendIRC("Channel :Users  Name", "321"); // RPL_LISTSTART
	for (i = 0; i < GIIRCd(Interface).Channels.length; i++)
	{
		if (InStr(GIIRCd(Interface).Channels[i].ChannelName, "s") > -1) continue;
		if (InStr(GIIRCd(Interface).Channels[i].ChannelName, "p") > -1) continue;
		// todo: check mask
		SendIRC(GIIRCd(Interface).Channels[i].ChannelName@GIIRCd(Interface).Channels[i].Users.length@":"$GIIRCd(Interface).Channels[i].Topic, "322"); // RPL_LIST
	}
	SendIRC(":End of /LIST", "323"); // RPL_LISTEND
}

/** return of a function call, ident is used to ident the data, always output this to the admin channel */
function output(coerce string data, optional string ident, optional bool bDontWrapFirst)
{
	if (bDontWrapFirst) ident = "";
	SendText(":-output- PRIVMSG"@GIIRCd(Interface).AdminChannelName@ident$data);
}

/** return of a function call, ident is used to ident the data */
function outputError(string errormsg, optional string ident, optional bool bDontWrapFirst)
{
	if (bDontWrapFirst) ident = "";
	SendText(":-error- PRIVMSG"@GIIRCd(Interface).AdminChannelName@ident$errormsg);
}

/** will be called for chat messages, always output this to the game channel */
function outputChat(coerce string pname, coerce string message, optional name Type, optional PlayerReplicationInfo PC)
{
	local int id;
	id = GIIRCd(Interface).GetNick(,PC);
	if (id < 0)
	{
		id = GIIRCd(Interface).GetSystemIRCUser(PlayerController(PC.Owner));
		if (id < 0)
		{
			SendText(":?"$pname$"!~@unknown PRIVMSG"@GIIRCd(Interface).GameChannelName@message);
			return;
		}
	}
	if (id == ClientID) return;
	SendText(":"$GIIRCd(Interface).GetIRCUserHost(id)@"PRIVMSG"@GIIRCd(Interface).GameChannelName@message);
}

static function FillPlayInfo(PlayInfo PlayInfo)
{
	super.FillPlayInfo(PlayInfo);
	PlayInfo.AddSetting(default.PICat, "bMustLogin", 			default.PILabel[0], 255, 1, "Check");
 	PlayInfo.AddSetting(default.PICat, "bShowMotd", 			default.PILabel[1], 128, 1, "Check");
  	// adding MOTD crashes when it contains a lot of data
	//PlayInfo.AddSetting(default.PICat, "MOTD", default.PILabel[2], 128, 1, "Text");
	PlayInfo.AddSetting(default.PICat, "MaxChannels", 			default.PILabel[3], 128, 1, "Text", "3;1:999",,,true);
	PlayInfo.AddSetting(default.PICat, "bAllowCreateChannel", 	default.PILabel[4], 128, 1, "Text", "3;1:999",,,true);
}

static event string GetDescriptionText(string PropName)
{
	switch (PropName)
	{
		case "bMustLogin":			return default.PIDesc[0];
		case "bShowMotd":			return default.PIDesc[1];
		case "MOTD":				return default.PIDesc[2];
		case "MaxChannels":			return default.PIDesc[3];
		case "bAllowCreateChannel":	return default.PIDesc[4];
	}
	return "";
}

defaultproperties
{
	ClientID=-1
	CVSversion="$Id: GCIRC.uc,v 1.23 2004/06/02 15:43:18 elmuerte Exp $"

	PICat="IRC daemon"
	PILabel[0]="Must login"
	PIDesc[0]="If set the user must login with a valid username and password when they register."
	PILabel[1]="Show MOTD"
	PIDesc[1]="Show the message of the day on login."
	PILabel[2]="MOTD"
	PIDesc[2]="Message of the day"
	PILabel[3]="Maximum channels"
	PIDesc[3]="Maximum Channels a user can join"
	PILabel[4]="Allow channel creation"
	PIDesc[4]="Allow channel creation. It's strongly adviced not to enable this"

	bMustLogin=false
	bShowMotd=true
	MaxChannels=2
	bAllowCreateChannel=false

	MOTD[0]=""
	MOTD[1]="                               _gp-!NXs<_=.=<d+~.,     _ "
	MOTD[2]="                           qp4p)n=Xn#=Z=nIvvllii+|=]k,. -{. "
	MOTD[3]="                        a{wdY'_xZ=s<u2{vv||::`<|gw%!`:?w  -=q/"
	MOTD[4]="                     g]aWU1wc=#2vvvn==l|<+:=qwQ@(>  ==:.<,  -NQ"
	MOTD[5]="                   p\m@SnXooc=nv:||i|:=||=aQBSv5`.:;;=;..4r  4oY,"
	MOTD[6]="                 gaQ@XSoXXSox\a/`:::;:413WVQlz$[:..:.:: . ]   ?kmf"
	MOTD[7]="               _5yUaoXX#S2nX3XZ[::.: ..3pS1lxim=....   . ./p  -XeI/"
	MOTD[8]="              %\@SM?`  ]1X2ox2#[...    ]mnZnnoQ=.. .  .    i   ZXik"
	MOTD[9]="             /y@`:. _.,]ZX#n3Z#[ .  . .3DnXe1XW=..:.`.  .  x   #o0=."
	MOTD[10]="       jJ   zj?:`::|=+=]W12Sx1X[    .  ]k}0>l+#=           c   #(-{'"
	MOTD[11]="      a(   ]j( _<|+===:)m-?<iYX(  . _:_]fP=+n>m` .        )f  jP . ."
	MOTD[12]="  _,jZ(   _sf :==;:=-`-4m.+J/+n(    .  ]CkuxZ<X`.         /  _P."
	MOTD[13]="  ]S2':   )7 ;::::..:::j#_<,3==(       )Ci%sp>Z`   .     J`  f"
	MOTD[14]="  )|>vi   i`::..:. . : jk|%#||n=     . )fS<<sWX`_,.    _J'"
	MOTD[15]="   Qqi|   I;....  . ...jE:=l(>)'.      ]fv3dWmX`     q':"
	MOTD[16]="   ]25:   ),.  ...  -: ]#_ssd>Z`.  . .aW[S3xul>\_qaw^:."
	MOTD[17]="    = =L   (       ... j#dW=W(dg;QmBTTk##wWXXMXmmP`  ."
	MOTD[18]="     ` lL  ],        ^+^qQi=29iZ|WiZ=Xr .%{}<|dP`-."
	MOTD[19]="        `   ]p     .   -^_--3x=<#YiW` /  -s-+^.."
	MOTD[20]="         <_  -',        ,       -+-_-       _."
	MOTD[21]="           -\,  ~_.                    .jp\"'"
	MOTD[22]="              ^    )`__,          _g,\"^"
	MOTD[23]="                          . . ."
	MOTD[24]=""
	MOTD[25]="   Welcome to %hostname%"
	MOTD[26]="   Available channels are: %channels%"
	MOTD[27]=""
	MOTD[28]="   this server uses the UnGateway system made by Michiel 'El Muerte' Hendriks."
	MOTD[29]="   This IRC server is just part of an even larger system."
	MOTD[30]=""
	MOTD[31]="   For more information about UnGateway visit the homepage:"
	MOTD[32]="       http://ungateway.elmuerte.com"
	MOTD[33]=""
}
