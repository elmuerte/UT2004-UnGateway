/*******************************************************************************
	GITelnetd																	<br />
	Telnet server																<br />
																				<br />
	Authors:	Michiel 'El Muerte' Hendriks &lt;elmuerte@drunksnipers.com&gt;	<br />
																				<br />
	Copyright 2003, 2004 Michiel "El Muerte" Hendriks							<br />
	Released under the Open Unreal Mod License									<br />
	http://wiki.beyondunreal.com/wiki/OpenUnrealModLicense						<br />
	<!-- $Id: GITelnetd.uc,v 1.5 2004/04/16 10:38:22 elmuerte Exp $ -->
*******************************************************************************/
class GITelnetd extends UnGatewayInterface;

defaultproperties
{
	Ident="Telnet/100"
	CVSversion="$Id: GITelnetd.uc,v 1.5 2004/04/16 10:38:22 elmuerte Exp $"
	AcceptClass=class'UnGateway.GCTelnet'
	RequestedLinkMode=MODE_Binary
	PICat="Telnet"
}
