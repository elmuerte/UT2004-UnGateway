/*******************************************************************************
	UnGatewayPlayer																<br />
	Player used for communication with players on the server					<br />
																				<br />
	Authors:	Michiel 'El Muerte' Hendriks &lt;elmuerte@drunksnipers.com&gt;	<br />
																				<br />
	Copyright 2003, 2004 Michiel "El Muerte" Hendriks							<br />
	Released under the Lesser Open Unreal Mod License							<br />
	http://wiki.beyondunreal.com/wiki/LesserOpenUnrealModLicense				<br />
	<!-- $Id: UnGatewayPlayer.uc,v 1.2 2004/04/06 18:58:11 elmuerte Exp $ -->
*******************************************************************************/
class UnGatewayPlayer extends MessagingSpectator;

var UnGatewayClient client;

function Create(UnGatewayClient clnt)
{
	client = clnt;
}

function InitPlayerReplicationInfo()
{
	Super.InitPlayerReplicationInfo();
	PlayerReplicationInfo.PlayerName = "UnGatewayPlayer";
}
