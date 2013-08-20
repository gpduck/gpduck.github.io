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