/**
	UnGatewayClient
	client for TCP based services linked in the Gateway system
	$Id: UnGatewayClient.uc,v 1.7 2003/09/27 15:13:08 elmuerte Exp $
*/
class UnGatewayClient extends TCPLink abstract config;

var UnGatewayInterface Interface;
var class<UnGatewayPlayer> PlayerControllerClass;
var UnGatewayPlayer PlayerController;

var protected int LoginTries;
var protected string inbuffer;
var string sUsername;
var protected string sPassword;
var string ClientAddress;

/** called when binary input is received */
delegate OnReceiveBinary(int Count, byte B[255]);
/** called when a line is received (sans the CR\LF) */
delegate OnReceiveLine(coerce string line);
/** called when raw text is received */
delegate OnReceiveText(coerce string line);
/** called when a client wants to log out */
delegate OnLogout();

/** called after the interface received the event GainedChild */
event Accepted()
{
	Interface.Gateway.Logf("Accepted", Name, Interface.Gateway.LOG_EVENT);	
	Interface.Gateway.Logf("[Accepted] Connection opened from"@IpAddrToString(RemoteAddr), Name, Interface.Gateway.LOG_INFO);
	ClientAddress = IpAddrToString(RemoteAddr);
	ClientAddress = Left(ClientAddress, InStr(ClientAddress, ":"));
	PlayerController = spawn(PlayerControllerClass, Self);
	sUsername = "";
	sPassword = "";
	inbuffer = "";
	LoginTries = 0;
}

/** connection closed, clean up */
event Closed()
{
	Interface.Gateway.Logf("Closed", Name, Interface.Gateway.LOG_EVENT);
	Interface.Gateway.Logout(Self);
}

/** don't override, use the delegate */
event ReceivedLine( string Line )
{
	local string x, tmp;
	local int i;
	while (line != "")
	{
		i = InStr(line, Chr(13));
		if (i == -1) InStr(line, Chr(10));
		if (i == -1) i = Len(line);
		tmp = Left(line, i);
		line = Mid(line, i+1);

		x = Right(tmp, 1);
		while ((x == Chr(10)) || (x == Chr(13)))
		{
			tmp = Left(tmp, len(tmp)-1);
			x = Right(tmp, 1);
		}
		x = Left(tmp, 1);
		while ((x == Chr(10)) || (x == Chr(13)))
		{
			tmp = Mid(tmp, 1);
			x = Left(tmp, 1);
		}
	
		if (tmp != "")
		{
			interface.gateway.Logf("ReceivedLine:"@tmp, Name, interface.gateway.LOG_DEBUG);	
			OnReceiveLine(tmp);
		}
	}
}

/** don't override, use the delegate */
event ReceivedText( string Text )
{
	interface.gateway.Logf("ReceivedText:"@Text, Name, interface.gateway.LOG_DEBUG);
	if (Text == "") return;
	OnReceiveText(text);
}

/** don't override, use the delegate */
event ReceivedBinary( int Count, byte B[255] )
{
	interface.gateway.Logf("ReceivedBinary:"@Count@"bytes", Name, interface.gateway.LOG_DEBUG);
	if (Count == 0) return;
	OnReceiveBinary(Count, B);
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
			if (i == -1) i = Len(input);
			elm[elm.length-1] = Left(input, i);
			input = Mid(input, i+1);
		}
		if (left(input, 1) == " ")
		{
			input = Mid(input, 1);
		}
	}
	return elm.length;
}

/*
// UT2003 Compatibility functions

function string repl(string Source, string Replace, coerse string With)
{
	// waring: case sensitive
	local int i;
	local string Input;

	if ( Source == "" || Replace == "" ) return;

	Input = Source;
	Source = "";
	i = InStr(Input, Replace);
	while(i != -1)
	{
		Source = Source $ Left(Input, i) $ With;
		Input = Mid(Input, i + Len(Replace));
		i = InStr(Input, Replace);
	}
	Source = Source $ Input;
	return Source;
}

static final operator(44) string $= ( out	string A, coerce string B )
{
	A = A$B;
	return A;
}

static final operator(44) string @= ( out string A, coerce string B )
{
	A = A@B;
	return A;
}

*/

defaultproperties
{
	PlayerControllerClass=class'UnGateway.UnGatewayPlayer'
}