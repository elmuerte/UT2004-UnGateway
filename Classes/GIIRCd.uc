/**
	GIIRCd
	IRC server
	$Id: GIIRCd.uc,v 1.5 2003/09/08 20:01:08 elmuerte Exp $
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
};
var array<IRCUserRecord> IRCUsers;

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
		Client.SendIRC(RequestedName@":ERR_ERRONEUSNICKNAME", "432");
		return false;
	}
	for (i = 0; i < IRCUsers.length; i++)
	{
		if (RequestedName != IRCUsers[i].Nick)
		{
			Client.SendIRC(RequestedName@":ERR_NICKNAMEINUSE", "433");
			return false;
		}
	}	
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
	IRCUsers.length = IRCUsers.length+1;
	IRCUsers[IRCUsers.length-1].Nick = client.sUsername;
	IRCUsers[IRCUsers.length-1].Userhost = client.sUserhost;
	IRCUsers[IRCUsers.length-1].PC = client.PlayerController;
	return IRCUsers.length-1;
}

defaultproperties
{
	Ident="IRC/100"
	AcceptClass=class'UnGateway.GCIRC'
}