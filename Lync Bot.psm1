﻿<#	
	===========================================================================
	 Created with: 	SAPIEN Technologies, Inc., PowerShell Studio 2014 v4.1.54
	 Created on:   	6/25/2014 7:20 PM
	 Created by:   	KSI SYN
	 Organization: 	SCN
	 Filename:     	Lync Bot.psm1
	-------------------------------------------------------------------------
	 Module Name: Lync Bot
	===========================================================================
#>

#region Pre-stage INIT Module Loading... 
# Clear all previous subscribed events
Get-EventSubscriber | Unregister-Event

$ModelPaths = @(); $ModelPaths = "C:\Program Files\Microsoft Office\Office15\LyncSDK\Assemblies\Desktop\Microsoft.Lync.Model.DLL,C:\Program Files\Microsoft Office\Office15\LyncSDK\Assemblies\Desktop\Microsoft.Lync.Controls.DLL"; $ModelPaths = $ModelPaths.Split(",")
Foreach ($ModelPath in $ModelPaths)
{
	If (Test-Path $ModelPath)
	{
		Import-Module $ModelPath
	}
	Else
	{
		$LIBName = $ModelPath.Split("\")
		
		Write-Host "Please Import the " $LIBName[-1] "from the MS Lync SDK Before using this Module"
		break
	}
}

# Obtain entry points to the Lync.Model API for Client and Automation + error handeling
try
{
	$global:Client = [Microsoft.Lync.Model.LyncClient]::GetClient()
	
	if ($Client -eq $null)
	{
		throw "Unable to obtain client interface"
	}
	
}
catch [Microsoft.Lync.Model.ClientNotFoundException]
{
	throw "Lync client is not running! Please launch your Lync client."
}

$Client.add_StateChanged

# test loading of Client Automation API's 
If ($Client.InSuppressedMode -eq $false)
{
	try
	{
		$global:Auto = [Microsoft.Lync.Model.LyncClient]::GetAutomation()
		
		if ($Auto -eq $null)
		{
			throw "Unable to obtain Lync Automation interface"
		}
		
	}
	catch
	{
		throw "Automation Session is unavaiable"
	}
	
	$global:Self = $client.Self
}
Else
{
	"UI Supression Mode is Active Suppressing UI Client Automation API's"
	'`n Sign in will need to be done via Command line'
}
#endregion

#region Functions Required by Events 

function Send-LyncMsg($msg)
{
	Write-Host "Bot Reply : " $msg.values
	# Send the message
	$null = $Modality.BeginSendMessage($msg, $null, $msg)
}

function Set-LyncAvailability
{
	
	<#
	.Synopsis
   		Set-LyncAvailability is a PowerShell function to configure a set of settings in the Microsoft Lync client via the Model API.

	.DESCRIPTION
  		 The purpose of Set-LyncAvailability is to demonstrate how PowerShell can be used to interact with the Lync SDK.

	.EXAMPLE
   		Set-LyncAvailability -Availability Available

	.EXAMPLE
  	  Set-LyncAvailability -Availability Away

	.EXAMPLE
    	Set-LyncAvailability -Availability "Off Work" -ActivityId off-work

	.EXAMPLE
  	  Set-LyncAvailability -PersonalNote test

	.EXAMPLE
  	  Set-LyncAvailability -Availability Available -PersonalNote ("Quote of the day: " + (Get-QOTD))

	.EXAMPLE
    	Set-LyncAvailability -Location Work

	.FUNCTIONALITY
  		 Provides a function to configure Availability, ActivityId and PersonalNote for the Microsoft Lync client.
#>
	Param (
		[ValidateSet("Appear Offline", "Available", "Away", "Busy", "Do Not Disturb", "Be Right Back", "Off Work")]
		[string]
		$Availability,
		# ActivityId as string
		[string]
		$ActivityId,
		# String value to be configured as personal note in the Lync client
		[string]
		$PersonalNote,
		# String value to be configured as location in the Lync client
		[string]
		$Location
	)
	$ContactInfo = New-Object 'System.Collections.Generic.Dictionary[Microsoft.Lync.Model.PublishableContactInformationType, object]'
	
	switch ($Availability)
	{
		"Available" { $AvailabilityId = 3000 }
		"Appear Offline" { $AvailabilityId = 18000 }
		"Away" { $AvailabilityId = 15000 }
		"Busy" { $AvailabilityId = 6000 }
		"Do Not Disturb" { $AvailabilityId = 9000 }
		"Be Right Back" { $AvailabilityId = 12000 }
		"Off Work" { $AvailabilityId = 15500 }
	}
	
	if ($Availability)
	{
		$ContactInfo.Add([Microsoft.Lync.Model.PublishableContactInformationType]::Availability, $AvailabilityId)
	}
	
	if ($ActivityId)
	{
		$ContactInfo.Add([Microsoft.Lync.Model.PublishableContactInformationType]::ActivityId, $ActivityId)
	}
	
	if ($PersonalNote)
	{
		$ContactInfo.Add([Microsoft.Lync.Model.PublishableContactInformationType]::PersonalNote, $PersonalNote)
	}
	
	if ($Location)
	{
		$ContactInfo.Add([Microsoft.Lync.Model.PublishableContactInformationType]::LocationName, $Location)
	}
	
	if ($ContactInfo.Count -gt 0)
	{
		
		$Publish = $Self.BeginPublishContactInformation($ContactInfo, $null, $null)
		$self.EndPublishContactInformation($Publish)
		
	}
	else
	{
		
		Write-Warning "No options supplied, no action was performed"
		
	}
	
	
}


function Convert-Rot13
{<#
	.SYNOPSIS
		13 Charater ASCII Shift.

	.DESCRIPTION
		Convert-Rot13 is a simple function that shifts text in a string value by 13 charaters.

	.EXAMPLE
		Convert-Rot13 "hello world"

	.INPUTS
		System.String

	.OUTPUTS
		System.String
#>

	[CmdletBinding()]
	param (
		[Parameter(
				   Mandatory = $true,
				   ValueFromPipeline = $true
		)]
		[String]
		$rot13string
	)
	
	[String] $string = $null;
	$rot13string.ToCharArray() |
	ForEach-Object {
		Write-Verbose "$($_): $([int] $_)"
		if ((([int] $_ -ge 97) -and ([int] $_ -le 109)) -or (([int] $_ -ge 65) -and ([int] $_ -le 77)))
		{
			$string += [char] ([int] $_ + 13);
		}
		elseif ((([int] $_ -ge 110) -and ([int] $_ -le 122)) -or (([int] $_ -ge 78) -and ([int] $_ -le 90)))
		{
			$string += [char] ([int] $_ - 13);
		}
		else
		{
			$string += $_
		}
	}
	$string
}

function Get-Hash
{
	<#
		.SYNOPSIS
			Creates hashes of string input
	
		.DESCRIPTION
			Get-Hash is used to generate a hash value based upon string input. outbpt methods include MD5, SHA1, SHA256,SH 384, SHA512, RACE Integrity Primitives Evaluation Message Digest 160, and Mac Triple DES.
	
		.PARAMETER algorithm  
			The algorithm parameter is used to set the hash output type. accepted values include 'mactripledes', 'md5', 'ripemd160', 'sha1', 'sha256', 'sha384', 'sha512'.
	
		.EXAMPLE
			$hash = Get-Hash -algorithm 'md5' -string "hello world"
	
		.INPUTS
			System.String
	
		.OUTPUTS
			System.String

	#>
	
	
	Param (
		[ValidateSet('mactripledes', 'md5', 'ripemd160', 'sha1', 'sha256', 'sha384', 'sha512')]
		[string]
		$algorithm,
		# ActivityId as string
		[string]
		$string
	)
	
	$crypto = [System.Security.Cryptography.HashAlgorithm]::create($algorithm)
	$utf8 = new-object -TypeName System.Text.UTF8Encoding
	$hash = [System.BitConverter]::ToString($crypto.ComputeHash($utf8.GetBytes($string)))
	$hash = $hash -replace "-", ""
	return $hash
}
#endregion

#region Event actions
# Job that is called on new message recievedvevent handeler
$global:action = {
	
	# get the conversation that caused the event
	$Conversation = $Event.Sender.Conversation
	 
	# Create a new msg collection for the response
	$msg = New-Object "System.Collections.Generic.Dictionary[Microsoft.Lync.Model.Conversation.InstantMessageContentType,String]"
	# Modality Type
	$Global:Modality = $Conversation.Modalities[1]
	
	# The message recieved
	[string]$msgStr = $Event.SourceArgs.Text
	$msgStr = $msgStr.ToString().ToLower().Trim()
	Write-Host "message Recieved" $msgStr
	$BotCMD = $msgStr.Split(" ")
	$attribs = $msgStr.TrimStart("$BotCMD[0]")
	$BotCMD = $BotCMD[0].TrimEnd(".!?")
#	Write-Host "First index in array is : " $BotCMD
	
	# switch commands / messages - add what you like here
	switch ($BotCMD)
	{
		"sorry" {
			$sendMe = 1
			$msg.Add(0, 'you should be sorry for what you have done :-(')
			
		}
		"wassup" {
			$sendMe = 1
			$msg.Add(0, 'nothing much, wassup with you?')
			
		}
		"how" {
			$sendMe = 1
			$msg.Add(0, 'How about you google it :-)')
			
		}
		"yes" {
			$sendMe = 1
			$msg.Add(0, 'Yessssssssiiirrrrrrrr')
			
		}
		"I" {
			$sendMe = 1
			$msg.Add(0, 'There is no I in team!')
			
		}
		"sup" {
			$sendMe = 1
			$msg.Add(0, 'Is it time for supper already?')
			
		}
		"you" {
			$sendMe = 1
			$msg.Add(0, 'its always you you you, what about me?')
			
		}
		"lol" {
			$sendMe = 1
			$msg.Add(0, 'whats so funny?')
			
		}
		"just" {
			$sendMe = 1
			$msg.Add(0, 'just what?')
			
		}
		"yeah" {
			$sendMe = 1
			$msg.Add(0, 'yeah what?')
			
		}
		"yea" {
			$sendMe = 1
			$msg.Add(0, 'yea what?')
			
		}
		"nothing" {
			$sendMe = 1
			$msg.Add(0, 'sounds like something!')
			
		}
		"what" {
			$sendMe = 1
			$msg.Add(0, 'whatup with you?')
			
		}
		"what`'s" {
			$sendMe = 1
			$msg.Add(0, "what`'s up with you?")
			
		}
		"whats" {
			$sendMe = 1
			$msg.Add(0, 'whats up with you?')
			
		}
		"nm" {
			$sendMe = 1
			$msg.Add(0, 'just chillin...')
			
		}
		"yo" {
			$sendMe = 1
			$msg.Add(0, 'Wassup?')
			
		}
		"hey" {
			$sendMe = 1
			$msg.Add(0, 'Hello')
			
		}
		"hi" {
			$sendMe = 1
			$msg.Add(0, 'Hello')
			
		}
		"hello" {
			$sendMe = 1
			$msg.Add(0, 'Hey Whats up?')
			
		}
		"moo" {
			$sendMe = 1
			$msg.Add(0, 'Are you a cow?')	
		}
		"help" {
			$sendMe = 1
			$msg.Add(0, 'Mr LyncBot at your service!')
			Send-LyncMsg -msg $msg
			sleep -Milliseconds 250
			$msg = New-Object "System.Collections.Generic.Dictionary[Microsoft.Lync.Model.Conversation.InstantMessageContentType,String]"
			$msg.Add(0, 'available commands:')
			Send-LyncMsg -msg $msg
			sleep -Milliseconds 250
			$msg = New-Object "System.Collections.Generic.Dictionary[Microsoft.Lync.Model.Conversation.InstantMessageContentType,String]"
			$msg.Add(0, 'hi, hey, hello')
			Send-LyncMsg -msg $msg
			sleep -Milliseconds 250
			$msg = New-Object "System.Collections.Generic.Dictionary[Microsoft.Lync.Model.Conversation.InstantMessageContentType,String]"
			$msg.Add(0, 'md5 <String>, sha1 <String>, sha256 <String>, sha384 <String>, sha512 <String>, mac3des <String>, ripemd160 <String>, rot13 <String>')
			Send-LyncMsg -msg $msg
			sleep -Milliseconds 250
			$msg = New-Object "System.Collections.Generic.Dictionary[Microsoft.Lync.Model.Conversation.InstantMessageContentType,String]"
			$msg.Add(0, 'time')
			Send-LyncMsg -msg $msg
			sleep -Milliseconds 250
			$msg = New-Object "System.Collections.Generic.Dictionary[Microsoft.Lync.Model.Conversation.InstantMessageContentType,String]"
			$msg.Add(0, '!busy, !free, !brb, !offline, !away')
		}
		"time" {
			$sendMe = 1
			$now = Get-Date
			$msg.Add(0, 'Current Date and Time : ' + $now)
		}
		"!busy" {
			$sendMe = 1
			$date = [DateTime]::Now
			Set-LyncAvailability -Availability 'Busy' -Location 'CyberSpace' -PersonalNote "Set availability to Busy using the Lync Model API in PowerShell on $date"
			$msg.Add(0, 'Bot Command Accepted: setting Avaiability to Busy')
		}
		"!free" {
			$sendMe = 1
			$date = [DateTime]::Now
			Set-LyncAvailability -Availability 'Available'  -Location 'CyberSpace' -PersonalNote "Set availability to Available using the Lync Model API in PowerShell on $date"
			$msg.Add(0, 'Bot Command Accepted: setting Avaiability to Available')
		}
		"!brb" {
			$sendMe = 1
			$date = [DateTime]::Now
			Set-LyncAvailability -Availability 'Be Right Back' -Location 'Away From Keybord' -PersonalNote "Be Right Back"
			$msg.Add(0, 'Bot Command Accepted: setting Avaiability to Be Right Back')
		}
		"!away" {
			$sendMe = 1
			$date = [DateTime]::Now
			Set-LyncAvailability -Availability 'Away' -Location 'Away From Keybord' -PersonalNote "I'm not here at the moment."
			$msg.Add(0, 'Bot Command Accepted: setting Avaiability to away')
		}
		"!offline" {
			$sendMe = 1
			$date = [DateTime]::Now
			Set-LyncAvailability -Availability 'Appear Offline' 
			$msg.Add(0, 'Bot Command Accepted: setting Avaiability to Offline')
		}
		"dcpromo"{
			$sendMe = 1
			$msg.Add(0, 'Promoteing Server as new node in Forest Gentry.IsMyHero.Local')
		}
		"thanks"{ $sendMe = 1
			$msg.Add(0, 'NP, Your Welcome')
		}
		
		"thank"{
			$sendMe = 1
			$msg.Add(0, 'NP, Your Welcome')
		}
		"huh"{
			$sendMe = 1
			$msg.Add(0, 'What ?')
		}
		"md5"{
			$hash = Get-Hash -algorithm 'md5' -string $attribs
			$sendMe = 1
			$msg.Add(0, "$hash")
		}
		"sha1"{
			$hash = Get-Hash -algorithm 'sha1' -string $attribs
			$sendMe = 1
			$msg.Add(0, "$hash")
		}
		"sha256"{
			$hash = Get-Hash -algorithm 'sha256' -string $attribs
			$sendMe = 1
			$msg.Add(0, "$hash")
		}
		"sha384"{
			$hash = Get-Hash -algorithm 'sha384' -string $attribs
			$sendMe = 1
			$msg.Add(0, "$hash")
		}
		"sha512"{
			$hash = Get-Hash -algorithm 'sha512' -string $attribs
			$sendMe = 1
			$msg.Add(0, "$hash")
		}
		"mac3des"{
			$hash = Get-Hash -algorithm 'mactripledes' -string $attribs
			$sendMe = 1
			$msg.Add(0, "$hash")
		}
		"ripemd160"{
			$hash = Get-Hash -algorithm 'ripemd160' -string $attribs
			$sendMe = 1
			$msg.Add(0, "$hash")
		}
		"rot13"{
			$out = Convert-Rot13 $attribs
			$sendMe = 1
			$msg.Add(0, "$out")
		}
		default
		{
			# do nothing
			$sendMe = 0
		}
	}
	
	if ($sendMe -eq 1)
	{
		# Send the message
		Send-LyncMsg -msg $msg
	}
}

#endregion

#region Lync Bot Management Functions
#Test Client State for Logon/init state
function Register-LyncStateChange
{
		<#
		.SYNOPSIS
			Register-LyncStateChange is a PowerShell function to detect the current Lync Client state.  
		
		.DESCRIPTION
   			The purpose of Register-LyncStateChange is to demonstrate how PowerShell can be used to interact with the Lync SDK.
	
		.EXAMPLE
			Restart-LyncBot
	#>
	
	
	$Lyncstate = $Client.State
	if ($Lyncstate -eq [Microsoft.Lync.Model.ClientState]::Uninitialized)
	{
		Write-Host "Lync Client not in Initialized State.`n Initializeing ..."
		$ar = $Client.BeginInitialize()
		$Client.EndInitialize($ar)
		
	}
	elseif ($Lyncstate -eq [Microsoft.Lync.Model.ClientState]::SignedIn)
	{
		Write-Host "User is logged in and Powershell is ready for Bot Startup"
		function Global:prompt { [System.String]$Global:usr = $Client.Uri.TrimStart("sip:"); "Lync Bot CLI [$usr] [Bot:OFF] >" }
		prompt
	}
	elseif ($Lyncstate -eq [Microsoft.Lync.Model.ClientState]::SignedOut)
	{
		Write-Host "No user is logged into the Lync Client.`n login before running Start-LyncBot"
	}
	elseif ($Lyncstate -eq [Microsoft.Lync.Model.ClientState]::SigningIn)
	{
		Write-Host "Client is Logging in.`n Please standby."
	}
	elseif ($Lyncstate -eq [Microsoft.Lync.Model.ClientState]::ShuttingDown)
	{
		Write-Host "Lync Client is Shutting Down.`n Terminateing Bot Event Handelers"
	}
}

function get-lynccommand
{
Get-Command -Module 'lync bot'	
}

function Stop-LyncBot
{
	<#
		.SYNOPSIS
			Stop-LyncBot is a PowerShell function to turn off the Lync Autoresponce bot 

		.DESCRIPTION
   			The purpose of Stop-LyncBot is to demonstrate how PowerShell can be used to interact with the Lync SDK.
	
		.EXAMPLE
			Stop-LyncBot
	#>
	
	# Clear all Bot subscribed events
	Get-EventSubscriber | Unregister-Event
	function Global:prompt { [System.String]$Global:usr = $Client.Uri.TrimStart("sip:"); "Lync Bot CLI [$usr] [Bot:OFF] >" }
}

function Request-LyncSignin ([System.String]$UserURI)
{
		<#
		.SYNOPSIS
			Request-LyncSignin is a PowerShell function to turn off the Lync Autoresponce bot and sign out of the Lync client 

		.DESCRIPTION
   			The purpose of Request-LyncSignin is to demonstrate how PowerShell can be used to interact with the Lync SDK.
	
		.EXAMPLE
			Request-LyncSignin -UserURI User@demo.com
	#>
	$credential = Get-Credential -message "Lync Credentials requires `nSpecify Username as Domain\user"
	Write-Host "Signing in Please stand by"
	$ar = $Client.BeginSignIn($UserURI, $credential.UserName, $credential.Password, $communicatorClientCallback, $state)
	while ($ar.IsCompleted -eq $false) { }
	$Client.EndSignIn($ar)
	Write-Host "Signed in. `nRun Start-LyncBot to start the bot."
	function Global:prompt { [System.String]$Global:usr = $Client.Uri.TrimStart("sip:"); "Lync Bot CLI [$usr] [Bot:OFF] >" }
}

function Request-LyncSignout
{
		<#
		.SYNOPSIS
			Request-LyncSignout is a PowerShell function to turn off the Lync Autoresponce bot and sign out of the Lync client 

		.DESCRIPTION
   			The purpose of Request-LyncSignout is to demonstrate how PowerShell can be used to interact with the Lync SDK.
	
		.EXAMPLE
			Request-LyncSignout
	#>
	
	Write-Host "Unsubscribeing All Lync Events this session"
	Stop-LyncBot
	Write-Host "initializeing signout process"
	$ar = $Client.BeginSignOut($communicatorClientCallback, $null)
	while ($ar.IsCompleted -eq $false) { }
	$Client.EndSignOut($ar)
	Write-Host "Signed out of Lync Client"
	function Global:prompt { "Lync Bot CLI [Signed Out] [Bot:OFF] >" }
prompt	
}

function Exit-LyncBot ([system.Boolean]$Confirm)
{
		<#
		.SYNOPSIS
			Exit-LyncBot is a PowerShell function to Shutdown the Lync Client 
		
		.DESCRIPTION
   			The purpose of Exit-LyncBot is to demonstrate how PowerShell can be used to interact with the Lync SDK.
	
		.PARAMETER Confirm
				Used to Confirm the Lync Client Shutdown Process

		.EXAMPLE
			Exit-LyncBot -Confirm
	#>
	
	if ($Confirm -eq $true)
	{
		Request-LyncSignout
		Write-Host "Starting Client Shutdown"
		$ar = $Client.BeginShutdown($communicatorClientCallback, $null)
		while ($ar.IsCompleted -eq $false) { }
		$Client.EndShutdown($ar)
		Write-Host "Client Shutdown: Background Process Terminated."
	}
	else { Write-Host 'Please confirm Client Shutdown with "-Confirm"' }
	
	
}

function Start-LyncBot
{
		<#
		.SYNOPSIS
			Start-LyncBot is a PowerShell function to Start the Lync Auto responder bot 
		
		.DESCRIPTION
   			The purpose of Start-LyncBot is to demonstrate how PowerShell can be used to interact with the Lync SDK.
	
		.EXAMPLE
			Start-LyncBot
	#>
	$ErrorActionPreference = [System.Management.Automation.ActionPreference]::SilentlyContinue
		# Register events for current open conversation participants
	foreach ($con in $client.ConversationManager.Conversations)
	{
		# For each participant in the conversation
		$moo = $con.Participants | Where { !$_.IsSelf }
		
		foreach ($mo in $moo)
		{
			try
			{
				if (!(Get-EventSubscriber $mo.Contact.uri))
				{
					Register-ObjectEvent -InputObject $mo.Modalities[1] `
										 -EventName "InstantMessageReceived" `
										 -SourceIdentifier $mo.Contact.uri `
										 -action $action
				}
			}
			catch [system.ArgumentException] { }
		}
		
	}
	# Add event to pickup new conversations and register events for new participants
	$conversationMgr = $client.ConversationManager
	Register-ObjectEvent -InputObject $conversationMgr `
						 -EventName "ConversationAdded" `
						 -SourceIdentifier "NewIncomingConversation" `
						 -action {
		$client = [Microsoft.Lync.Model.LyncClient]::GetClient()
		foreach ($con in $client.ConversationManager.Conversations)
		{
			# For each participant in the conversation
			$moo = $con.Participants | Where { !$_.IsSelf }
			foreach ($mo in $moo)
			{
				$mo.Contact.uri
				if (!(Get-EventSubscriber $mo.Contact.uri))
				{
					Register-ObjectEvent -InputObject $mo.Modalities[1] `
										 -EventName "InstantMessageReceived" `
										 -SourceIdentifier $mo.Contact.uri `
										 -action $action
				}
			}
		}
	}
	$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
	function Global:prompt { [System.String]$Global:usr = $Client.Uri.TrimStart("sip:");"Lync Bot CLI [$usr] [Bot:ON] >" }
}

function Restart-LyncBot
{
	<#
		.SYNOPSIS
			Restart-LyncBot is a PowerShell function to Kill the autoresponce bot and reload the Lync bot module.  
		
		.DESCRIPTION
   			The purpose of Restart-LyncBot is to demonstrate how PowerShell can be used to interact with the Lync SDK.
	
		.EXAMPLE
			Restart-LyncBot 
	#>
	
	Stop-LyncBot
	Remove-Module 'Lync Bot'
	Import-Module '.\Lync Bot.psd1'
}

#endregion

#region Runtime INIT
# Runtime INIT
clear
$Host.UI.RawUI.WindowTitle = "Lync Bot C&C Console"
function Global:prompt { "Lync Bot CLI [Signed Out] [Bot:OFF] >" }
prompt

#State change notification event registration
Register-ObjectEvent -InputObject $Client `
					 -EventName "StateChanged" `
					 -SourceIdentifier "LyncClientStateChanged" `
					 -action { Register-LyncStateChange }

#init state change processing
Register-LyncStateChange

#endregion

#region Export Module members	
# export module members
Export-ModuleMember Register-LyncStateChange
Export-ModuleMember Send-LyncMsg
Export-ModuleMember Start-LyncBot
Export-ModuleMember Stop-LyncBot
Export-ModuleMember Exit-LyncBot
Export-ModuleMember Request-LyncSignout
Export-ModuleMember Request-LyncSignin
Export-ModuleMember Set-LyncAvailability
Export-ModuleMember Restart-LyncBot
Export-ModuleMember Convert-Rot13
Export-ModuleMember Get-Hash
Export-ModuleMember get-lynccommand
#endregion