/**
	GITelnetd
	Telnet server
	$Id: GITelnetd.uc,v 1.1 2003/09/04 08:11:46 elmuerte Exp $
*/
class GITelnetd extends UnGatewayInterface;

defaultproperties
{
	Ident="Telnet/100"
	AcceptClass=class'UnGateway.GCTelnet'
	RequestedLinkMode=MODE_Binary
}
