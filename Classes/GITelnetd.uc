/**
	GITelnetd
	Telnet server
	$Id: GITelnetd.uc,v 1.2 2004/01/02 09:19:24 elmuerte Exp $
*/
class GITelnetd extends UnGatewayInterface;

defaultproperties
{
	Ident="Telnet/100"
	CVSversion="$Id: GITelnetd.uc,v 1.2 2004/01/02 09:19:24 elmuerte Exp $"
	AcceptClass=class'UnGateway.GCTelnet'
	RequestedLinkMode=MODE_Binary
}
