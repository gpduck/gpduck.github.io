---
layout: post
title: "(Not) Using PowerShell v2 to View WSMan Data From ESX"
tags: ["esx","powershell","vmware","wsman"]
author: { link: "https://plus.google.com/111921112014612222144/about", name: Chris Duck }
redirect_from: "/2009/09/not-using-PowerShell-v2%20to-view-wsman.html"
---
Today I was trying to get at my "Health Status" data on my ESX servers though PowerShell using the tutorial posted on the PowerCLI Blog ([Monitoring ESX Hardware with Powershell][monitoringhw]), but I kept getting an "Access Denied" message.  I did a little more research into using WSMan in PowerShell and discovered that before V2, there was a way to use a COM object to query WSMan that gave you a little more control over the connection ([http://technet.microsoft.com/en-us/magazine/2007.11.heyscriptingguy.aspx][scriptingguy]).

Here is a PowerShell script based on the PowerCLI script that uses the COM object from the Scripting Guy article (it assumes you're already connected to your Virtual Center server):

{% highlight powershell %}
$vmhost = get-vmhost ""
$view = get-view $vmhost.id

$token = $view.acquireCimServicesTicket().sessionId

$uri = "https:///wsman"
$object = "http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_NumericSensor"

$wsman = new-object -com WSMan.automation
$options = $wsman.createConnectionOptions()
$options.username = $token
$options.password = $token
$flags = $wsman.sessionFlagUseBasic() -bor $wsman.sessionFlagCredUserNamePassword() -bor $wsman.sessionflagskipcacheck() -bor $wsman.sessionflagskipcncheck() -bor $wsman.sessionflagskiprevocationcheck()

$session = $wsman.createSession($uri, $flags, $options)
$result = $session.enumerate($object)

$xml = while(!$result.atendofstream) {
  $result.readitem()
}
{% endhighlight %}

This proved that it was possible to pull this data from Windows, but I wanted to use my shiny new v2 cmdlets to do it (plus I wanted objects instead of XML that I was having problems casting without modification).

My next step was to sniff the network from my workstation and see exactly what Get-WSManInstance was passing to the ESX server for the username and password.  That involved locating a version of Wireshark that had the SSL decryption libraries enabled (I'm using x64 Windows 7) and copying the private key from the ESX server to my workstation.

After installing many different versions of Wireshark (1.2.2 for x86 worked) , I discovered that OpenWSMan logs authentication messages (that include the username) to /var/log/messages on the ESX server.  Either way you decide to go, what you will find is that Get-WSManInstance is pre-pending a "\" before the username:

Sep 16 21:34:00 xvhalp22 openwsman(pam_unix)[12388]: bad username [\5297c1ab-ecf9-43c1-6b4a-cb7dce63d813]

I decided to try and determine if the Powershell cmdlet was the culprit or if it was the .Net implementation of WSMan that was adding the extra character, so I did a little searching and came across this blog post that includes a function that allows you to pipe a cmdlet to it and it will locate the appropriate class and DLL and then load it up in Reflector ([A trick to jump directly to a Cmdlet's implementation in Reflector][cmdletreflector]).  The command would be:

<div class="psconsole">PS> get-command Get-WSManInstance | Reflect-Cmdlet</div>

What I found after a little digging is that in the CreateSessionObject function of the WSManHelper class, they are setting the credentials as follows:

{% highlight csharp %}
if (credential != null)
{
  NetworkCredential networkCredential = new NetworkCredential();
  if (credential.get_UserName() != null)
  {
    networkCredential = credential.GetNetworkCredential();
    if (string.IsNullOrEmpty(networkCredential.Domain))
    {
      if (authentication.Equals(AuthenticationMechanism.Digest))
      {
         connectionOptions.UserName = networkCredential.UserName;
      }
      else
      {
        connectionOptions.UserName = @"\" + networkCredential.UserName;
      }
    }
    else
    {
      connectionOptions.UserName = networkCredential.Domain + @"\" + networkCredential.UserName;
    }
    connectionOptions.Password = networkCredential.Password;
    if ((!authentication.Equals(AuthenticationMechanism.Credssp) || !authentication.Equals(AuthenticationMechanism.Digest)) || authentication.Equals(AuthenticationMechanism.Basic))
{% endhighlight %}

I think line 15 is the cause of my problem and I believe this is a bug in the cmdlet.  I'm not sure which "basic" authentication schemes would be expecting a username like "\user", and in fact the System.Net.WebClient doesn't add this leading slash when you use Basic and a PSCredential.

I haven't tried this on the Vista or XP PowerShell v2 RC, but I have to assume that this behavior was introduced sometime after CTP3, or the PowerCLI Blog people would never have been able to connect.

[monitoringhw]: http://blogs.vmware.com/vipowershell/2009/03/monitoring-esx-hardware-with-powershell.html
[scriptingguy]: http://technet.microsoft.com/en-us/magazine/2007.11.heyscriptingguy.aspx
[cmdletreflector]: http://www.nivot.org/2008/10/30/ATrickToJumpDirectlyToACmdletsImplementationInReflector.aspx
