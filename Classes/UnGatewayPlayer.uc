/*******************************************************************************
    UnGatewayPlayer                                                             <br />
    Player used for communication with players on the server                    <br />
                                                                                <br />
    Authors:    Michiel 'El Muerte' Hendriks &lt;elmuerte@drunksnipers.com&gt;  <br />
                                                                                <br />
    Copyright 2003, 2004 Michiel "El Muerte" Hendriks                           <br />
    Released under the Open Unreal Mod License                                  <br />
    http://wiki.beyondunreal.com/wiki/OpenUnrealModLicense
    <!-- $Id: UnGatewayPlayer.uc,v 1.6 2004/10/20 14:08:47 elmuerte Exp $ -->
*******************************************************************************/
class UnGatewayPlayer extends MessagingSpectator;

var UnGatewayClient client;

var localized string msgGameEnded;

function Create(UnGatewayClient clnt)
{
    client = clnt;
}

function InitPlayerReplicationInfo()
{
    Super.InitPlayerReplicationInfo();
    PlayerReplicationInfo.PlayerName = "UnGatewayPlayer";
}

function GameHasEnded()
{
    client.output(msgGameEnded);
}

event ClientMessage( coerce string S, optional Name Type )
{
    SendFormattedMessage(None, S, Type);
}

function TeamMessage( PlayerReplicationInfo PRI, coerce string S, name Type)
{
    SendFormattedMessage(PRI, S, Type);
}

/** format the message and send it to the client */
function SendFormattedMessage(PlayerReplicationInfo PRI, coerce string S, optional name Type)
{
    local string pname;
    if (PRI != none)
    {
        pname = PRI.PlayerName;
    }
    client.outputChat(pname, S, Type, PRI);
}

defaultproperties
{
    msgGameEnded="The game has ended, you will be disconnected within a few seconds"
}
