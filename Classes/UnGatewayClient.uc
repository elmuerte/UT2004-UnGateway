/**
	UnGatewayClient
	client for TCP based services linked in the Gateway system
	$Id: UnGatewayClient.uc,v 1.1 2003/09/04 08:11:46 elmuerte Exp $
*/
class UnGatewayClient extends TCPLink abstract config;

var UnGatewayInterface Interface;
var class<UnGatewayPlayer> PlayerControllerClass;
var UnGatewayPlayer PlayerController;

/** called after the interface received the event GainedChild */
event Accepted()
{
	Interface.Gateway.Logf("Accepted", Name, Interface.Gateway.LOG_EVENT);
	Interface.Gateway.Logf("[Accepted] Connection opened from"@IpAddrToString(RemoteAddr), Name, Interface.Gateway.LOG_INFO);
	PlayerController = spawn(PlayerControllerClass, Self);
}

event Closed()
{
	Interface.Gateway.Logf("Closed", Name, Interface.Gateway.LOG_EVENT);
	Interface.Gateway.Logout(Self);
}

/** should be overwritten */
event ReceivedLine( string Line )
{
	interface.gateway.Logf("ReceivedLine:"@Line, Name, interface.gateway.LOG_DEBUG);
}

/** should be overwritten */
event ReceivedText( string Text )
{
	interface.gateway.Logf("ReceivedText:"@Text, Name, interface.gateway.LOG_DEBUG);
}

/** should be overwritten */
event ReceivedBinary( int Count, byte B[255] )
{
	local int i;
	local string res;
	for (i = 0; i < Count; i++)
	{
		res $= Chr(B[i]);
	}
	interface.gateway.Logf("ReceivedBinary:"@res, Name, interface.gateway.LOG_DEBUG);
}

/** return of a function call */
function output(string data);

/** return of a function call */
function outputError(string errormsg);

/** split a string with quotes */
function int AdvSplit(string input, string delim, out array<string> elm, optional string quoteChar)
{
	local int i;
	if (quoteChar == "") return Split(input, delim, elm);
	while (input != "")
	{
		elm.length = elm.length+1;
		if (left(input, 1) == "\"")
		{
			input = mid(input, 1);
			i = InStr(input, "\"");
			if (i == -1) i = Len(input);
			elm[elm.length-1] = Left(input, i);
			input = Mid(input, i+1);
		}
		else {
			i = InStr(input, " ");
			elm[elm.length-1] = Left(input, i);
			input = Mid(input, i+1);
		}
		if (left(input, 1) == " ")
		{
			input = Mid(input, 1);
		}
	}
}

defaultproperties
{
	PlayerControllerClass=class'UnGateway.UnGatewayPlayer'
}