---
layout: post
title: "April MS Patch Issue"
tags: ["exchange","patches","powershell"]
author: { link: "https://plus.google.com/111921112014612222144/about", name: Chris Duck }
---
After deploying our April patches we were having trouble with our Exchange servers, specifically our web mail servers were not responsive and we had high cpu utilization on all our Exchange (2010) boxes (sorry, I don't know exactly which process was going crazy with the CPU).  In our initial troubleshooting, it was discovered that other symptoms were Event Viewer and Powershell both crashed immediately upon loading.  This pointed us to [KB2540222][].

The problem turns out to be an older patch (979744) and there is also an easy way to detect the problem before the new patches cause it and a new version of 979744 that can be installed to prevent the issue.

I wrote the following quick script to check all servers on our network for the bad version of the patch so we could get them all updated during our maintenance window, even if we weren't experiencing a problem with them at the time. This script queries your Active Directory to locate servers to check and then uses your current credentials to make a remote registry query to check the keys listed in the KB for the broken version of the patch. It assumes that you only have server computer objects in your OU and that you aren't running IA-64 based servers (it only checks 2008 x86, 2008 x64, and 2008 R2 registry paths). The script displays the computers with the broken patch on the screen as well as saving them to the $broken variable.

{% highlight powershell %}
$RootOU = "ou=servers,dc=contoso,dc=com"
$Timeout = 100

$x86 = "SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\Packages\Package_for_KB979744~31bf3856ad364e35~x86~~6.0.1.0"
$x64 = "SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\Packages\Package_for_KB979744~31bf3856ad364e35~amd64~~6.0.1.0"
$r2 = "SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\Packages\Package_for_KB979744~31bf3856ad364e35~amd64~~6.1.1.0"

$ds = new-object DirectoryServices.DirectorySearcher
$ds.filter = "(objectcategory=computer)"
$ds.searchroot = [adsi]"LDAP://$RootOU"
$computers = $ds.findall() | %{ $_.properties.cn[0] }

$ping = new-object net.networkinformation.ping

$broken = $computers | %{
 $computer = $_
 if($ping.send($_, $timeout).status -eq "Success") {
  $hklm = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, $computer)
  $x86, $x64, $r2 | %{
   $key = $hklm.opensubkey($_)
 
   if($key) {
    if($key.getValue("currentstate") -eq 7) {
     Write-Host "$Computer is broken"
     $computer
    }
   }
  }
 }
}
{% endhighlight %}

Once you have identified all the servers that need the new version of 979744, you can download it from the link above, making sure to grab the V2 version for your OS and architecture.

[kb2540222]: http://support.microsoft.com/kb/2540222