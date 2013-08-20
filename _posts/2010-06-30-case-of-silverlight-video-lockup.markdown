---
layout: post
title: "The Case of the Silverlight Video Lockup"
tags: ["drm","hang","silverlight"]
author: { link: "https://plus.google.com/111921112014612222144/about", name: Chris Duck }
---
I came home to a computer unwilling to play video today.  Netflix would launch the silverlight player, determine my video quality, buffer 5-30% of the video, then hard hang my computer.  I couldn't even get [CrashOnCtrlScroll][crash] to work so I could try using WinDbg to determine what was causing the hang.

After uninstalling loads of software and drivers (I had recently installed the Silverlight SDK, so I thought maybe that had something to do with it), I ended up in the system event log where I noticed this event:

<table>
  <tr>
    <td colspan="2">Unused media renderer devices were not removed from the list of devices because required DRM components cannot run while a debugger is attached. Detach the debugger from the machine or from the WMPNetworkSvc service, and then restart the WMPNetworkSvc service.</td>
  </tr>
  <tr><td><b>Log Name:</b></td><td>System</td>   </tr>
  <tr><td><b>Source:</b></td><td>Windows Media Player Network Sharing Service</td></tr>
  <tr><td><b>Event ID:</b></td><td>14105</td></tr>
  <tr><td><b>Level:</b></td><td>Warning</td></tr>
  <tr><td><b>OpCode:</b></td><td>Info</td></tr>
</table>

At this point, I connected the dots that last night I had enabled live kernel debugging (``bcdedit /debug on``) while working through one of the examples in [Windows Internals, 5th Edition][winternals] (great book btw). Disabling debugging and rebooting solved the hang.

Apparently kernel debugging is the sworn enemy of watching 30 Rock on Netflix and Silverlight protects the content by hanging my computer. Thanks a lot DRM.

[crash]: http://msdn.microsoft.com/en-us/library/ff545499(VS.85).aspx
[winternals]: http://www.amazon.com/Windows%C2%AE-Internals-Including-Windows-PRO-Developer/dp/0735625301?ie=UTF8&tag=widgetsamazon-20&link_code=btl&camp=213689&creative=392969