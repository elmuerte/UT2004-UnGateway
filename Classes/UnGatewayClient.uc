/*******************************************************************************
	UnGatewayClient																<br />
	client for TCP based services linked in the Gateway system					<br />
																				<br />
	Authors:	Michiel 'El Muerte' Hendriks &lt;elmuerte@drunksnipers.com&gt;	<br />
																				<br />
	Copyright 2003, 2004 Michiel "El Muerte" Hendriks							<br />
	Released under the Lesser Open Unreal Mod License							<br />
	http://wiki.beyondunreal.com/wiki/LesserOpenUnrealModLicense				<br />
	<!-- $Id: UnGatewayClient.uc,v 1.12 2004/04/06 18:58:11 elmuerte Exp $ -->
*******************************************************************************/
class UnGatewayClient extends TCPLink abstract config;

/** CVS Id string */
var const string CVSversion;
/** the interface this class belongs to */
var UnGatewayInterface Interface;
/** the controller class to spawn to represent this TCP client in game */
var class<UnGatewayPlayer> PlayerControllerClass;
/** thr in game representation */
var UnGatewayPlayer PlayerController;

/** login tries */
var protected int LoginTries;
/** input buffer */
var protected string inbuffer;
/** the username used to authenticate with */
var string sUsername;
/** the password used */
var protected string sPassword;
/** the client's address */
var string ClientAddress;

/** called when binary input is received */
delegate OnReceiveBinary(int Count, byte B[255]);
/** called when a line is received (sans the CR\LF) */
delegate OnReceiveLine(coerce string line);
/** called when raw text is received */
delegate OnReceiveText(coerce string line);
/** called when a client wants to log out */
delegate OnLogout();
/** called to complete the current inbuffer, e.g. tab completion */
delegate OnTabComplete();

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
/*
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
	*/
	if (Line != "")
	{
		interface.gateway.Logf("ReceivedLine:"@Line, Name, interface.gateway.LOG_DEBUG);
		OnReceiveLine(Line);
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
	local int delimlen, quotelen;
	if (quoteChar == "") return Split(input, delim, elm);

	delimlen = Len(delim);
	quotelen = Len(quoteChar);
	while (input != "")
	{
		if (elm.length > 0)
		{
			if (left(input, delimlen) == delim)
			{
				input = Mid(input, delimlen);
				elm.length = elm.length+1;
			}
		}
		else {
			elm.length = 1;
		}
		if (left(input, quotelen) == quoteChar)
		{
			input = mid(input, quotelen);
			i = InStr(input, quoteChar);
			if (i == -1) i = Len(input);
			while (mid(input, i-1, 1) == "\\")
			{
				elm[elm.length-1] $= Left(input, i-1)$quoteChar;
				input = Mid(input, i+quotelen);
				i = InStr(input, quoteChar);
				if (i == -1) i = Len(input);
			}
			elm[elm.length-1] $= Left(input, i);
			input = Mid(input, i+quotelen);
		}
		else {
			i = InStr(input, delim);
			if (i == -1) i = Len(input);
			elm[elm.length-1] $= Left(input, i);
			input = Mid(input, i);
		}
	}
	return elm.length;
}

defaultproperties
{
	PlayerControllerClass=class'UnGateway.UnGatewayPlayer'
	CVSversion="$Id: UnGatewayClient.uc,v 1.12 2004/04/06 18:58:11 elmuerte Exp $"
}
