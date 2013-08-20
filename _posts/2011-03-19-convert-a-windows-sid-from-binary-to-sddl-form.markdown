---
layout: post
title: "Convert a Windows SID from Binary to SDDL Form"
tags: ["binary","powershell","security","sid","sql"]
author: { link: "https://plus.google.com/111921112014612222144/about", name: Chris Duck }
---
At work I had a problem that required me to decode a SID that was stored in a database in binary form in order to locate the user/group that it represented. It turns out this is fairly easy to do, but I couldn't find a Powershell solution online and the solutions in those "other" languages tended to be overly complicated.

###Getting the Initial Data###

The first task was to get from the binary data from SQL into an appropriate .Net object. Browsing through MSDN, it looks like [System.Security.Principal.SecurityIdentifier][sid] would be a good choice :)

{% highlight powershell linenos %}
Add-PSSnapin SqlServerCmdletSnapin100

$binsid = (Invoke-SQLCmd "SELECT operators_sid FROM [FIMDatabase].[mms_server_configuration]").operators_sid
$sid = new-object security.principal.securityidentifier($binsid, 0)
{% endhighlight %}

###Converting From a SID to a Principal###

Now that we have a SID object we can use that to convert the binary SID to a string and then use the string value to search either our local SAM database or an Active Directory Domain to locate the account the SID represents. For this task, I've written a script called [Get-Principal.ps1][getprincipal]:

{% highlight powershell linenos %}
<#
.SYNOPSIS

Gets a principal object from either an Active Directory Domain or a "local" SAM account database.
This can be either a user or a group. Note that this is not a search function, you must fully specify
a unique identifier for a principal.

.DESCRIPTION

Uses the System.DirectoryServices.AccountManagement namespace introduced in .Net 3.5 to locate
a principal object. Can bind on any property in the System.DirectoryServices.AccountManagement.IdentityType
enumeration (SamAccountName, Name, UserPrincipalName, DistinguishedName, Sid (in SDDL form), or Guid).

.PARAMETER Identity

The value to match on as a string. Should be one of the following:

SamAccountName (Administrator)
Name (Smith)
UserPrincipalName (user@domain.com)
DistinguishedName (cn=smith,ou=users,dc=domain,dc=com)
Sid (S-1-5-32-544)
Guid (0d15a1bb-dbec-4855-b949-25999828c24c)

.PARAMETER DomainName

The domain name to query. If none of DomainName, ComputerName, or Local are specified,
the default domain is queried. This can be specified as the NetBIOS name or FQDN of 
the domain.

.PARAMETER ComputerName

The name of the computer to query.

.PARAMETER Local

Query the local computer.

.EXAMPLE

Get the Administrators group on the local computer.

.\Find-Principal.ps1 Administrators -local

.EXAMPLE

Get a principal for a user named jsmith on the default domain.

.\Find-Principal.ps1 jsmith

.EXMAPLE

Get the user with sid S-1-5-21-654981354-654786135-6565798-327 on the domain example.com.

.\Find-Principal.ps1 "S-1-5-21-654981354-654786135-6565798-327" -domain "example.com"

.NOTES

This function requires .Net 3.5 or greater.

#>
[CmdletBinding(DefaultParametersetName="Domain")]
Param(
    [Parameter(Position=0, ValueFromPipeline=$true, Mandatory=$true)]
    $Identity,
    
    [Parameter(ParameterSetName="Domain")]
    $DomainName,
    
    [Parameter(ParameterSetName="Computer")]
    $ComputerName,
    
    [Parameter(ParameterSetName="Computer")]
    [switch]$Local
)

if(![reflection.assembly]::LoadWithPartialName("System.DirectoryServices.AccountManagement")) {
    throw ".Net 3.5 required to run Find-Principal"
}

switch ($PsCmdlet.ParameterSetName) {
    "Domain" {
        if($DomainName) {
            $ctx = New-Object System.DirectoryServices.AccountManagement.PrincipalContext([System.DirectoryServices.AccountManagement.ContextType]::Domain, $DomainName)
        } else {
            $ctx = New-Object System.DirectoryServices.AccountManagement.PrincipalContext([System.DirectoryServices.AccountManagement.ContextType]::Domain)
        }
    }
    "Computer" {
        if($ComputerName) {
            $ctx = New-Object System.DirectoryServices.AccountManagement.PrincipalContext([System.DirectoryServices.AccountManagement.ContextType]::Machine, $ComputerName)
        } else {
            $ctx = New-Object System.DirectoryServices.AccountManagement.PrincipalContext([System.DirectoryServices.AccountManagement.ContextType]::Machine, $env:computername)
        }
    }
}

return [System.DirectoryServices.AccountManagement.Principal]::FindByIdentity($ctx, $identity)
{% endhighlight %}

Now we can take the string SID from $sid.ToString() and resolve the SID to either an account or group on the domain:

``.\Get-Principal.ps1 $sid.ToString()``

or on the local computer:

``.\Get-Principal.ps1 $sid.ToString() -Local``

###Converting a Principal Back to a Binary SID###

Going the other way is just as simple... there is a method on [System.Security.Principal.SecurityIdentifier][sid] called GetBinaryForm that takes a byte array and populates it with the binary SID. You just have to make sure that you create an empty byte array with enough space to hold the SID:

<div class="psconsole">#Get the SID for the local Administrators group as an example<br />
$sid = (.\Get-Principal "Administrators" -local).sid<br />
<br />
#Create a byte array long enough to hold the whole SID<br />
$BinarySid = new-object byte[]($sid.BinaryLength)<br />
<br />
#Copy the binary sid into the byte array, starting at index 0<br />
$sid.GetBinaryForm($BinarySid, 0)<br />
<br />
$BinarySid<br />
1<br />
2<br />
0<br />
0<br />
0<br />
0<br />
0<br />
5<br />
32<br />
0<br />
0<br />
0<br />
32<br />
2<br />
0<br />
0</div>

###Saving it Back to SQL###

To bring this example back around full circle, the last bit is to save the new binary SID back into the database:

<div class="psconsole">#Create a template string to perform the update in SQL, in my case there is only 1 row in the table so it is easy<br />
$SQLUpdate = "UPDATE [FIMDatabase].[mms_server_configuration] set [<span class="Apple-style-span" style="color: darkred; font-family: Consolas, 'Lucida Console'; font-size: 13px; white-space: nowrap;">operators_sid</span>] = {0}"<br />
Invoke-SQLCmd ($SQLUpdate -f $BinarySid)</div>

I'll talk about why I'm actually doing all this in another post.

[sid]: http://msdn.microsoft.com/en-us/library/system.security.principal.securityidentifier.aspx
[getprincipal]: {{ site.baseurl }}/blogscripts/get-principal.ps1