/*******************************************************************************
    GITelnetd                                                                   <br />
    Telnet server                                                               <br />
                                                                                <br />
    Authors:    Michiel 'El Muerte' Hendriks &lt;elmuerte@drunksnipers.com&gt;  <br />
                                                                                <br />
    Copyright 2003, 2004 Michiel "El Muerte" Hendriks                           <br />
    Released under the Open Unreal Mod License                                  <br />
    http://wiki.beyondunreal.com/wiki/OpenUnrealModLicense
    <!-- $Id: GITelnetd.uc,v 1.7 2004/10/20 14:08:47 elmuerte Exp $ -->
*******************************************************************************/
class GITelnetd extends UnGatewayInterface config;

defaultproperties
{
    Ident="Telnet/100"
    CVSversion="$Id: GITelnetd.uc,v 1.7 2004/10/20 14:08:47 elmuerte Exp $"
    AcceptClass=class'UnGateway.GCTelnet'
    RequestedLinkMode=MODE_Binary
    PICat="Telnet"
}
