/**
	GCIRC
	IRC client, spawned from GIIRCd
	RFC: 1459
	$Id: GCIRC.uc,v 1.2 2003/09/08 14:05:53 elmuerte Exp $
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
function SendRaw(string data, string code)
{
	local string nm;
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

		if (split(line, " ", input) < 2) return; // always wrong
		input[0] = caps(input[0]);
		switch (input[0])
		{
			// NICK <nickname>
			case "NICK":	if (input.length < 2) SendRaw(":ERR_NONICKNAMEGIVEN", "431");
										else GIIRCd(Interface).CheckNickName(Self, input[1]); // will check the name and assign it 
										break;
			// PASS <password>
			case "PASS":	if (input.length < 2) SendRaw("PASS :ERR_NEEDMOREPARAMS", "461");
										else if (sUsername != "" || sUserhost != "") SendRaw(":ERR_ALREADYREGISTRED", "462");
										else sPassword = input[1]; 
										break;
			// USER <username> <client host> <server host> :<real name>
			case "USER":	if (input.length < 4) 
										{
											SendRaw("USER :ERR_NEEDMOREPARAMS", "461");
											break;
										}
										sUserhost = input[1]$"@"$input[2];
										if (sPassword != "") // try to login
										{
											if (!interface.gateway.Login(Self, sUsername, sPassword, interface.ident@sUserhost))
											{
												SendRaw(":ERR_PASSWDMISMATCH", "464");
								        Close();
											}
										}
										i = GIIRCd(Interface).GetIRCUser(self);
										GIIRCd(Interface).IRCUsers[i].Realname = Mid(input[3], 1); // strip :
										GotoState('loggedin');
										break;
		}
	}

begin:
	OnReceiveLine=procLogin;
}

state Loggedin
{
	function procIRC(coerce string line)
	{
	}

begin:
	OnReceiveLine=procIRC;
	SendRaw(":Welcome to"@Level.GRI.ServerName@sUsername$"!"$sUserhost, "001");
	SendRaw(":Your host is"@interface.gateway.hostname$", running"@Level.EngineVersion, "002");
	SendRaw(":This server was created"@Interface.Gateway.CreationTime, "003");
	SendRaw(":"$interface.gateway.hostname@"UnrealWarfare/"$Level.EngineVersion@Interface.gateway.Ident@Interface.Ident, "004");
	SendRaw("MAP PREFIX=(ov)@+ MODES=3 CHANTYPES=#& MAXCHANNELS=2 NICKLEN=9 TOPICLEN=160 KICKLEN=160 NETWORK=... CHANMODES=... :are supported by this server", "004");
	SendRaw(":There are ... users and ... services on ... servers", "251");
	SendRaw("... :operators online", "252");
	SendRaw("... :unknown connections", "253");
	SendRaw("... :channels formed", "254");
	SendRaw(":I have ... users, 0 services and ... servers", "255");
	SendRaw(":Current local users: ... Max: ...", "265");
	SendRaw(":Current global users: ... Max: ...", "252");
	if (bShowMotd) ShowMOTD();
}

function ShowMOTD()
{
	local int i;
	if (MOTD.length == 0) return;
	SendRaw(":-"@interface.gateway.hostname@"Message of the Day -", "275");
	for (i = 0; i < MOTD.length; i++) 
	{
		// TODO: processing
		SendRaw(":"$MOTD[i], "272");
	}
	SendRaw(":End of MOTD command.", "376");
}

defaultproperties
{
	bShowMotd=true

	MOTD[0]=",.-----------------------------------------------------------.,"
	MOTD[1]="   Welcome to %hostname%"
	MOTD[2]=""
	MOTD[3]="   This server uses the UnGateway system maybe by"
	MOTD[4]="   Michiel 'El Muerte' Hendriks".
	MOTD[5]="   This IRC server is just part of an even larger system."
	MOTD[6]=""
	MOTD[7]="   For more information about UnGateway visit the homepage:"
	MOTD[8]="       http://ungateway.drunksnipers.com"
	MOTD[9]="`'----------------------------------------------------------'`"
}