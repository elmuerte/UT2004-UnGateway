/**
	GCIRC
	IRC client, spawned from GIIRCd
	RFC: 1459
	$Id: GCIRC.uc,v 1.7 2003/09/23 07:53:59 elmuerte Exp $
*/
class GCIRC extends UnGatewayClient;

/** Show the message of the day on login */
var config bool bShowMotd;
/** Message of the Day */
var config array<string> MOTD;
/** Maximum Channels a user can join */
var config int MaxChannels;
/** 
	Allow channel creation
	Turning this on will enable remote channels, it's strongly adviced not to enable this
	Note: remote channels are NOT supported
*/
var config bool bAllowCreateChannel;

struct UserChannelRecord
{
	var int channel; // pointer to the channel record
	var string UserMode; // user mode
};
/** listening on the channels this client is in */
var array<UserChannelRecord> Channels;

/** userhost string: username@hostname*/
var string sUserhost;

/** pointer to this clients entry in the IRC user list */
var int ClientID;

event Accepted()
{
	Super.Accepted();
	ClientID = -1;
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
}

/** 
	return true if this user is in the channel 
	using the channel record pointer is faster
*/
function bool IsIn(optional string channelname, optional int id)
{
	local int i;
	if (id == -1) return false;
	if (channelname == "")
	{
		for (i = 0; i < Channels.length; i++)
		{
			if (Channels[i].channel == id) return true;
		}
	}
	else {
		for (i = 0; i < Channels.length; i++)
		{
			if (GIIRCd(Interface).Channels[Channels[i].channel].Name ~= channelname) return true;
		}
	}
	return false;
}

/** check if a channel name is valid */
function bool checkValidChanName(string channel)
{
	if ((Left(channel, 1) != "#" && Left(channel, 1) != "&") || (InStr(channel, ",") > -1) || (InStr(channel, Chr(7))))
	{
		return false;
	}
	return true;
}

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
										sUserhost = input[1]$"@"$input[2];
										if (sPassword != "") // try to login
										{
											if (!interface.gateway.Login(Self, sUsername, sPassword, interface.ident@sUserhost))
											{
												SendIRC(":Password incorrect", "464"); // ERR_PASSWDMISMATCH
								        Close();
											}
										}
										ClientID = GIIRCd(Interface).GetIRCUser(self);
										GIIRCd(Interface).IRCUsers[ClientID].Realname = Mid(input[3], 1); // strip :
										GotoState('loggedin');
										break;
			default:			SendIRC(input[0]@":Unknown command", "421"); // ERR_UNKNOWNCOMMAND
		}
	}

begin:
	OnReceiveLine=procLogin;
}

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
			case "NICK":		if (input.length < 2) SendIRC(":No nickname given", "431"); // ERR_NONICKNAMEGIVEN
											else GIIRCd(Interface).CheckNickName(Self, input[1]); // will check the name and assign it 
											break;
			case "PASS":		SendIRC(":You may not reregister", "462"); // ERR_ALREADYREGISTRED
											break;
			case "USER":		SendIRC("::You may not reregister", "462"); // ERR_ALREADYREGISTRED
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
												}
											}
											break;
			case "QUIT":		ircExecQUIT(Mid(line, 6)); break;
			case "SQUIT":		break; // NOT YET supported
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
												for (i = 0; i < Channels.length; i++) ircExecNAMES(GIIRCd(Interface).Channels[Channels[i].Channel].Name);
											}
											break;
			case "LIST":		ircExecLIST(); // can only print local channels
											break;
			//case "INVITE":	not supported
			case "KICK":		break; // not yet implemented
			case "VERSION":	if (input.length > 1) ircExecVERSION(input[1]);
											else ircExecVERSION();
											break;
			//case "STATS":		not supported
			//case "LINKS":		not supported, yet
			//case "TIME":		not supported, yet
			//case "CONNECT":	not supported, yet
			//case "TRACE":		not supported
			//case "ADMIN":		not supported, yet
			//case "INFO":		not supported, yet
			case "PRIVMSG":	if (input.length < 3) SendIRC("TOPIC :Not enough parameters", "461"); // ERR_NEEDMOREPARAMS
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
			case "NOTICE":	if (input.length < 3) break;
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
			case "WHOIS":		// not yet implemented
											break;
			case "WHOWAS":	// not yet implemented
			case "KILL":		if (input.length < 3) SendIRC("KILL :Not enough parameters", "461"); // ERR_NEEDMOREPARAMS
											else {
												ircExecKILL(input[1], "...");
											}
											break;
			default:				SendIRC(input[0]@":Unknown command", "421"); // ERR_UNKNOWNCOMMAND
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
	SendIRC("... :channels formed", "254");
	SendIRC(":I have ... users, 0 services and ... servers", "255");
	SendIRC(":Current local users: ... Max: ...", "265");
	SendIRC(":Current global users: ... Max: ...", "252");
	if (bShowMotd) ircExecMOTD();
}

///////////////////////////////// IRC COMMANDS /////////////////////////////////

function ircExecMOTD()
{
	local int i;
	if (MOTD.length == 0) 
	{
		SendIRC(":MOTD File is missing", "422"); // ERR_NOMOTD
		return;
	}
	SendIRC(":-"@interface.gateway.hostname@"Message of the Day -", "375");
	for (i = 0; i < MOTD.length; i++) 
	{
		MOTD[i] = repl(MOTD[i], "%hostname%", interface.gateway.hostname);
		SendIRC(":-"@MOTD[i], "372");
	}
	SendIRC(":End of MOTD command.", "376");
}

function ircExecQUIT(optional string QuitMsg, optional bool bDontClose)
{
	if (QuitMsg == "") QuitMsg = sUsername;
	// TODO: broadcast mesg
	if (!bDontClose) Close();
}

function ircExecJOIN(string channel, optional string key)
{
	local int i, id;
	if (checkValidChanName(channel))
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
	if (id == -1) // create the channel
	{
		if (!bAllowCreateChannel)
		{
			SendIRC(channel@":No such channel", "403"); // ERR_NOSUCHCHANNEL
			return;
		}
		else {
			id = CreateChannel(channel);
		}
	}

	if (IsIn(, id)) // already in this channel
	{			
	}
	else {			
		if (GIIRCd(Interface).Channels[id].Key != "" && GIIRCd(Interface).Channels[id].Key != Key)
		{
			SendIRC(channel@":Cannot join channel (+k)", "475"); // ERR_BADCHANNELKEY
		}
		else if (GIIRCd(Interface).Channels[id].Limit <= GIIRCd(Interface).Channels[id].Users.length)
		{
			SendIRC(channel@":Cannot join channel (+l)", "471"); // ERR_CHANNELISFULL
		}
		else if (GIIRCd(Interface).IsBanned(id, sUsername$"!"$sUserhost))
		{
			SendIRC(channel@":Cannot join channel (+b)", "474"); // ERR_BANNEDFROMCHAN
		}
		else if (InStr(GIIRCd(Interface).Channels[id].Mode, "i") > -1)
		{
			SendIRC(channel@":Cannot join channel (+i)", "473"); // ERR_INVITEONLYCHAN
		}
		else {
			Channels.length = Channels.length+1;
			Channels[Channels.length-1].Channel = id;
			GIIRCd(Interface).Channels[id].Users.length = GIIRCd(Interface).Channels[id].Users.length+1;
			GIIRCd(Interface).Channels[id].Users[GIIRCd(Interface).Channels[id].Users.length-1] = ClientID;
			ircExecTOPIC(channel);
			ircExecNAMES(channel);
		}
	}
}

function ircExecPART(string channel)
{
	local int i, id;
	id = GIIRCd(Interface).GetChannel(channel);
	for (i = 0; i < Channels.length; i++)
	{
		if (GIIRCd(Interface).Channels[Channels[i].channel].Name ~= channel)
		{
			id = Channels[i].channel;
			break;
		}
	}
	if (IsIn(, id))
	{
		// partChannel(id, self);
		// partChannel( channel id, client, bNoBroadcast );
	}
	else {
		// not on channel
	}
}

function ircExecMODE(array<string> args)
{
	//...
}

function ircExecTOPIC(string channel, optional string newTopic)
{
	local int id;
	id = GIIRCd(Interface).GetChannel(channel);
	if (!IsIn(, id))
	{
		SendIRC(channel@":You're not on that channel", "442"); // ERR_NOTONCHANNEL
		return;
	}
	if (newTopic == "")
	{
		if (GIIRCd(Interface).Channels[id].Topic != "")
		{
			SendIRC(channel@":"$GIIRCd(Interface).Channels[id].Topic, "332"); // RPL_TOPIC
		}
		else {
			SendIRC(channel@":No topic is set", "331"); // RPL_NOTOPIC
		}
	}
	else { 
		// ERR_CHANOPRIVSNEEDED
	}
}

function ircExecNAMES(string channel)
{
	// ...
}

function ircExecVERSION(optional string server)
{
	if (server == "")
	{
		SendIRC(":"$interface.gateway.hostname@"UnrealWarfare/"$Level.EngineVersion@Interface.gateway.Ident@Interface.Ident, "004");
		SendIRC("PREFIX=(ov)@+ MODES=3 CHANTYPES=#& MAXCHANNELS="$MaxChannels$" NICKLEN=9 TOPICLEN=160 KICKLEN=160 NETWORK=... CHANMODES=... :are supported by this server", "004");
	}
	else {
		//...
	}
}

function ircExecPRIVMSG(string receipt, string text)
{
	// ...
}

function ircExecNOTICE(string receipt, string text)
{
	// ...
}

function ircExecWHO(optional string mask, optional bool bOnlyOps)
{
	//...
}

function ircExecKILL(string nick, string message)
{
	//...
}

function ircExecLIST()
{
	//...
}

defaultproperties
{
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
	MOTD[26]=""
	MOTD[27]="   This server uses the UnGateway system maybe by Michiel 'El Muerte' Hendriks."
	MOTD[28]="   This IRC server is just part of an even larger system."
	MOTD[29]=""
	MOTD[30]="   For more information about UnGateway visit the homepage:"
	MOTD[31]="       http://ungateway.drunksnipers.com"
	MOTD[32]=""
}