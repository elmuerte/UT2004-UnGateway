-------------------------------------------------------------------------------

				   UnGateway
                                version 102 Beta
                          Michiel "El Muerte" Hendriks
                           elmuerte@drunksnipers.com

-------------------------------------------------------------------------------

UnGateway is a system that provides additional methods for server 
administration. It's a base system that can easily be extended to support
additional protocols.

At the moment it provides a Telnet server with VT102 terminal emulation, it 
behaves much like the Bash shell.
The telnet server has been tested with the Linux telnet client and a MS Windows
telnet client: PuTTY. The MS Telnet client that comes with every MS Windows
version also works, but it's advised to use a different telnet client (like 
PuTTY, free software).

Security notice: the telnet protocol is plain text, there is no form of 
encryption. On the side note: the UT2004 webadmin does not have any better
protection.

Additionally from version 102 beta the IRC daemon is also functional. The IRC
server works pretty much like any other IRC server, so a normal IRC client 
should work.
Not every function of the IRC protocol has been implemented, but at the moment
it's functional.

-------------------------------------------------------------------------------
Installation:

Copy the .u and .int files to the System directory.
Add the following to your system configuration (UT2004.ini):

	[Engine.GameEngine]
	ServerActors=UnGateway.GatewayDaemon

-------------------------------------------------------------------------------
Configuration:

Out of the box UnGateway doesn't do much. You need to configure interfaces and 
applications that are available. To add an interface add the following to your 
system configuration:

	[UnGateway.GatewayDaemon]
	InterfaceClasses=<interface class 1>
	InterfaceClasses=<interface class 2>
	InterfaceClasses=...

To add applications add the following to your configuration file:
	
	[UnGateway.GatewayDaemon]
	ApplicationClasses=<application class 1>
	ApplicationClasses=<application class 2>
	ApplicationClasses=...


The following interface classes are available:
* UnGateway.GITelnetd
	Telnet server
* UnGateway.GIIRCd
	IRC server, only partialy implemented and not completely functions

The following application classes are available:
* UnGateway.GAppDebug
	Contains debug commands, there's no need to install this application
* UnGateway.GAppDefault
	Contain default commands like "help" and "quit"
* UnGateway.GAppCron
	Provides a cron daemon to program commands to be executed at a set 
	time.
* UGUT2004.GAppSystem
	Provides general system commands for UT2004, like shutdown and 
	servertravel
* UGUT2004.GAppSettings
	Contains commands to change settings and maplists

For an overview of all available commands and some additional information
checkt the UnGateway-help.txt file

-------------------------------------------------------------------------------
Interface configurations:

Each interface contains at least the following configuration variables:

* int: iListenPort
	The port this interface will listen on. It should be an unused port.
	No interface has a default listen port configured, thus you should
	always have to set this option or else it won't work.
* bool: bUseNextAvailable
	If the current listen port is in use, pick the next available port.
* int: iMaxClients
	The maximum number of clients that may connect to this interface. if 
	the maximum is reached new clients will be rejected.
* APEntry: AccessPolicy
	A list with access policies that can connect to this interface. By 
	default connections are accepted from any interface.

Additional configuration variable can be available for each interface.

-------------------------------------------------------------------------------
Additional configuration options (per class):

[UnGateway.Cron]
* array: Crontab
	List with crontab entries, format:
	Crontab=(Command="somecommand",Type=EC_Delay,Time="5",Desc="added by Admin",bDisabled=False)
		Command:	the command to secute
		Type:		EC_Delay or EC_Time
		Time:		time configuration, format depends on the 
				value of Type.
		Desc:		description
		bDisabled:	when true the command will never be executed
* string: DummyClientClass
	Dummy gateway client to receive the results of the commands. No need 
	to edit this command.

EC_Delay:
	The command will be executed after set number of minutes after the level has
	been loaded.
EC_Time:
	The command will be executed when the set time has been	reached.
	Time field format, 5 fields:	minute hour day month day_of_week 
		minute:			0-59
		hour: 			0-23
		day:			0-31
		month:			0-11
		day_of_week:		0-6
 	A * can be used as wild card. Optionally each field can have a divider for
	re-occurance: val/div. For example a field has the value: "0/5". This means
	that it will match: time % div == val -> time % 5 == 0. If time is minutes
	then it will match every 5 minutes, 1/5 will also match every 5 minutes,
	except that it's the 2nd minute of every 5 minutes, 5/5 will never match. A
	wildcard in a divider will be changed to 0: * /5 -> 0/5, 0/ * -> 0/0 (never
	matches)


[UnGateway.CronClient]
* bool: bSilent
	only log errors
* bool: bExternalLog
	use and external log file
* string: LogFilename
	Log filename to use. The following formatting rules are accepted:
	%P		server port
	%Y		year
	%M		month
	%D		day
	%H		hour
	%I		minute
	%S		second
	%W		day of the week

[UnGateway.GAppCron]
* string: CronClass
	the Cron daemon class, no need to change this

[UnGateway.GatewayDaemon]
* string: AuthClass
	the authentication class to use. By default this is set to
	UnGateway.GAuthSystem which uses the systems AccessControl class

[UnGateway.GCTelnet]
* string: CommandPrompt
	The command prompt format. The following replacements can be used: 
	%username%, %computername%, %hostname%, %hostaddress%, %clientaddress%
* bool: bShowMotd
	Show the message of the day
* string array: MOTD
	The Messsage Of The Day
* int: iMaxLogin
	The maximum login tries before the connection is closed
* float: fDelayInitial
	the number of seconds to wait before the user can try to log in
* float: fDelayWrongPassword
	Number of seconds to wait before a user can try to log in again. this 
	prevents brute forcing a password.
* bool: bDisableAuth
	Disable authentication completely. You should not do this, it will allow 
	everybody to login without a username and password.
* bool: bEnablePager
	The pager is the automatic scroll feature that allows users to scroll up 
	or down when a command output is more than could fit on the screen.
* bool: bSaveHistory
	Save each user's command history to the UnGateway.ini file. This will 
	add some useless overhead during login and logout.
* string: CommandHistoryClass
	The class to spawn for saving\loading the command history
* ChatMode
	The intial chat mode. With full chat mode everything the user enters 
	will be a chat command. With partial chat only part of the screen is 
	reserved for messages and only when the user uses the say command it 
	will be considerd as a chat message.
	CM_Disabled = Disabled
	CM_Full = Full chat mode
	CM_Partial = Partial chat mode
	When logged in you can use the following commands to change the chat
	mode:
		Alt+c	toggle partial chat mode
		Alt+C	full chat mode
	Note: instead of Alt the Esc can be used


Note: IRCd configuration variables omitted because of the implementation state
of this interface.

