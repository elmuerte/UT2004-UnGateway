/**
	UnGatewayPlayer
	Player used for communication with players on the server
	$Id: UnGatewayPlayer.uc,v 1.1 2003/09/04 08:11:46 elmuerte Exp $
*/
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
