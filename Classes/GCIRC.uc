/**
	GCIRC
	IRC client, spawned from GIIRCd
	RFC: 1459
	$Id: GCIRC.uc,v 1.1 2003/09/04 11:26:42 elmuerte Exp $
*/
class GCIRC extends UnGatewayClient;

struct ChannelRecord
{
	var string name;
	var string topic;
};

/** listening on these channels */
var array<ChannelRecord> Channels;

var protected string sUserhost;

event Accepted()
{
	Super.Accepted();
}

// send RAW irc
function SendRaw(string data)
{
	SendText(":"$interface.gateway.hostname@data);
}

auto state Login
{

	function procLogin(coerce string line)
	{
		local array<string> input;
		if (split(line, " ", input) < 2) return; // always wrong
		input[0] = caps(input[0]);
		switch (input[0])
		{
			// NICK <nickname>
			case "NICK":	sUsername = GIIRCd(Interface).FixName(input[1]); break;
			case "PASS":	sPassword = input[1]; break;
			// USER <username> <client host> <server host> :<real name>
			case "USER":	sUserhost = input[1];
										if (sPassword != "") // try to login
										{
											if (!interface.gateway.Login(Self, sUsername, sPassword, interface.ident@sUserhost))
											{
												SendRaw("464 : Incorrect login");
								        Close();
											}
										}
										//TODO: check nickname
										//TODO: bAutoFixName
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
}

defaultproperties
{
}