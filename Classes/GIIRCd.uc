/**
	GIIRCd
	IRC server
	$Id: GIIRCd.uc,v 1.2 2003/09/04 11:26:41 elmuerte Exp $
*/
class GIIRCd extends UnGatewayInterface;

/** we need to keep a record of clients here */
var array<GCIRC> Clients;

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
			Clients.Remove(i, 1);
			return;
		}
	}
}

function string FixName(string username)
{
	// TODO:
	return username;
}

defaultproperties
{
	Ident="IRC/100"
	AcceptClass=class'UnGateway.GCIRC'
}