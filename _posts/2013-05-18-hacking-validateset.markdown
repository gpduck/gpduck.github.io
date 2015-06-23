---
layout: post
title: Hacking ValidateSet
tags: [dotnet, hacking, powershell]
author: { link: "https://plus.google.com/111921112014612222144/about", name: Chris Duck }
---
I guess I should start off this post by saying what I'm doing is a dirty hack, in no way supported, and in general a terrible idea.  But it's also really awesome.

Occasionally I find it would be nice to be able to dynamically generate the values used in a ``ValidateSet`` attribute on a function parameter.  Joel Bennett wrote a post a while back explaining how to build a [custom validation attribute](http://huddledmasses.org/better-error-messages-for-powershell-validatepattern/) that could be written to include the ability to update the set list dynamically. Or you could even use his technique of using ``ValidateScript`` and throwing a custom error message to generate the set dynamically.

The problem with these other techniques is that ``ValidateSet`` [comes with magic](http://blogs.msdn.com/b/powershell/archive/2006/05/10/594175.aspx") that they don't include.  This magic provides tab-completion, error messages, and a listing of valid values in help, all for free.  I actually started off my experiment by following Joel's post and implementing my own ``ValidateDynamicSetAttribute`` class that provided ``Add()`` and ``Remove()`` methods so the values could be changed on the fly.

But that class wouldn't have come with the magic of ``ValidateSet``, and while I was using ILSpy to learn how ``ValidateSet`` was implemented, I discovered that it was based on a private string array and it turns out I had just learned how to access private members while I was at the PowerShell Summit 2013 (thanks Adam!).

The result is the following function that takes a FunctionInfo object (use ``Get-Command``), the name of the parameter that is using ``ValidateSet``, and the new set of valid inputs.  It hacks its way into the command, locates the correct parameter, locates all the ``ValidateSet`` attributes on it, and rips into the heart of each one and replaces the private ``validValues`` array with the one provided in the ``-NewSet`` parameter.

{% highlight powershell %}
<#
  .SYNOPSIS
    Replace the set of valid values on a function parameter that was defined using ValidateSet.

  .DESCRIPTION
    Replace the set of valid values on a function parameter that was defined using ValidateSet.

  .PARAMETER Command
    A FunctionInfo object for the command that has the parameter validation to be updated.  Get this using:

    Get-Command -Name YourCommandName

  .PARAMETER ParameterName
    The name of the parameter that is using ValidateSet.

  .PARAMETER  NewSet
    The new set of valid values to use for parameter validation.

  .EXAMPLE
    Define a test function:

    PS> Function Test-Function {
      param(
        [ValidateSet("one")]
        $P
      )
    }

    PS> Update-ValidateSet -Command (Get-Command Test-Function) -ParameterName "P" -NewSet @("one","two")

    After running Update-ValidateSet, Test-Function will accept the values "one" and "two" as valid input for the -P parameter.

  .OUTPUTS
    Nothing

  .NOTES
    This function is updating a private member of ValidateSetAttribute and is thus not following the rules of .Net and could break at any time.  Use at your own risk!

    Author : Chris Duck

  .LINK
    http://blog.whatsupduck.net/2013/05/hacking-validateset.html
#>
function Update-ValidateSet {
  [CmdletBinding(SupportsShouldProcess=$true)]
  param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [System.Management.Automation.FunctionInfo]$Command,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$ParameterName,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [String[]]$NewSet
  )

  #Find the parameter on the command object
  $Parameter = $Command.Parameters[$ParameterName]
  if($Parameter) {
    #Find all of the ValidateSet attributes on the parameter
    $ValidateSetAttributes = @($Parameter.Attributes | Where-Object {$_ -is [System.Management.Automation.ValidateSetAttribute]})
    if($ValidateSetAttributes) {
      $ValidateSetAttributes | ForEach-Object {
        #Get the validValues private member of the ValidateSetAttribute class
        $ValidValuesField = [System.Management.Automation.ValidateSetAttribute].GetField("validValues", [System.Reflection.BindingFlags]::NonPublic -bor [System.Reflection.BindingFlags]::Instance)
        if($PsCmdlet.ShouldProcess("$Command -$ParameterName", "Set valid set to: $($NewSet -join ', ')")) {
          #Update the validValues array on each instance of ValidateSetAttribute
          $ValidValuesField.SetValue($_, $NewSet)
        }
      }
    } else {
      Write-Error -Message "Parameter $ParameterName in command $Command doesn't use [ValidateSet()]"
    }
  } else {
    Write-Error -Message "Parameter $ParameterName was not found in command $Command"
  }
}
{% endhighlight %}
