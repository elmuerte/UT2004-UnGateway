/*******************************************************************************
    TelnetCommandHistory                                                        <br />
    Used to store the command history of a user                                 <br />
                                                                                <br />
    Authors:    Michiel 'El Muerte' Hendriks &lt;elmuerte@drunksnipers.com&gt;  <br />
                                                                                <br />
    Copyright 2003, 2004 Michiel "El Muerte" Hendriks                           <br />
    Released under the Open Unreal Mod License                                  <br />
    http://wiki.beyondunreal.com/wiki/OpenUnrealModLicense
    <!-- $Id: TelnetCommandHistory.uc,v 1.3 2004/10/20 14:08:47 elmuerte Exp $ -->
*******************************************************************************/

class TelnetCommandHistory extends Object config(UnGateway) perobjectconfig parseconfig;

var config array<string> History;

