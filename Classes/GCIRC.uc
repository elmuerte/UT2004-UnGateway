/**
	GCIRC
	IRC client, spawned from GIIRCd
	RFC: 1459
	$Id: GCIRC.uc,v 1.3 2003/09/08 16:26:36 elmuerte Exp $
*/
class GCIRC extends UnGatewayClient;

/** Show the message of the day on login */
var config bool bShowMotd;
/** Message of the Day */
var config array<string> MOTD;

struct ChannelRecord
{
	var string name;
	var string topic;
};

/** listening on these channels */
var array<ChannelRecord> Channels;

/** userhost string: username@hostname*/
var string sUserhost;

event Accepted()
{
	Super.Accepted();
}

// send RAW irc
function SendIRC(string data, coerce string code)
{
	local string nm;
	if ((code == "") || (data == "")) return;
	if (!IsInState('Login')) nm = sUsername;
		else nm = "*";
	// :<server host> <code> <nickname> <additional data>
	SendText(":"$interface.gateway.hostname@code@nm@data);
}

auto state Login
{

	function procLogin(coerce string line)
	{
		local array<string> input;
		local int i;

		if (split(line, " ", input) < 1) return; // always wrong
		input[0] = caps(input[0]);
		switch (input[0])
		{
			// NICK <nickname>
			case "NICK":	if (input.length < 2) SendIRC(":ERR_NONICKNAMEGIVEN", "431");
										else GIIRCd(Interface).CheckNickName(Self, input[1]); // will check the name and assign it 
										break;
			// PASS <password>
			case "PASS":	if (input.length < 2) SendIRC("PASS :ERR_NEEDMOREPARAMS", "461");
										else if (sUsername != "" || sUserhost != "") SendIRC(":ERR_ALREADYREGISTRED", "462");
										else sPassword = input[1]; 
										break;
			// USER <username> <client host> <server host> :<real name>
			case "USER":	if (input.length < 4) 
										{
											SendIRC("USER :ERR_NEEDMOREPARAMS", "461");
											break;
										}
										sUserhost = input[1]$"@"$input[2];
										if (sPassword != "") // try to login
										{
											if (!interface.gateway.Login(Self, sUsername, sPassword, interface.ident@sUserhost))
											{
												SendIRC(":ERR_PASSWDMISMATCH", "464");
								        Close();
											}
										}
										i = GIIRCd(Interface).GetIRCUser(self);
										GIIRCd(Interface).IRCUsers[i].Realname = Mid(input[3], 1); // strip :
										GotoState('loggedin');
										break;
			default:			SendIRC(input[0]@":ERR_UNKNOWNCOMMAND", "421");
		}
	}

begin:
	OnReceiveLine=procLogin;
}

state Loggedin
{
	function procIRC(coerce string line)
	{
		local array<string> input;

		if (split(line, " ", input) < 1) return; // always wrong
		input[0] = caps(input[0]);
		switch (input[0])
		{
			case "PING":		if (input.length < 2) SendIRC(":ERR_NOORIGIN", "409");
											SendText("PONG"@input[1]); break;
			case "MOTD":		ShowMOTD(); break;
			case "OPER":		if (input.length < 3) SendIRC("OPER :ERR_NEEDMOREPARAMS", "461");
											else {
												//sUsername = input[1]; // don't set the username
												sPassword = input[2];
												if (!interface.gateway.Login(Self, input[1], sPassword, interface.ident@sUserhost))
												{
													SendIRC(":ERR_PASSWDMISMATCH", "464");
												}
												// ....
											}
											break;
			default:				SendIRC(input[0]@":ERR_UNKNOWNCOMMAND", "421");
		}
	}

begin:
	OnReceiveLine=procIRC;
	SendIRC(":Welcome to"@Level.GRI.ServerName@sUsername$"!"$sUserhost, "001");
	SendIRC(":Your host is"@interface.gateway.hostname$", running"@Level.EngineVersion, "002");
	SendIRC(":This server was created"@Interface.Gateway.CreationTime, "003");
	SendIRC(":"$interface.gateway.hostname@"UnrealWarfare/"$Level.EngineVersion@Interface.gateway.Ident@Interface.Ident, "004");
	SendIRC("MAP PREFIX=(ov)@+ MODES=3 CHANTYPES=#& MAXCHANNELS=2 NICKLEN=9 TOPICLEN=160 KICKLEN=160 NETWORK=... CHANMODES=... :are supported by this server", "004");
	SendIRC(":There are ... users and ... services on ... servers", "251");
	SendIRC("... :operators online", "252");
	SendIRC("... :unknown connections", "253");
	SendIRC("... :channels formed", "254");
	SendIRC(":I have ... users, 0 services and ... servers", "255");
	SendIRC(":Current local users: ... Max: ...", "265");
	SendIRC(":Current global users: ... Max: ...", "252");
	if (bShowMotd) ShowMOTD();
}

function ShowMOTD()
{
	local int i;
	if (MOTD.length == 0) 
	{
		SendIRC(":ERR_NOMOTD", "422");
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

defaultproperties
{
	bShowMotd=true

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