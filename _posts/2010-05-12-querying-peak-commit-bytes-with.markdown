---
layout: post
title: "Querying Peak Commit Bytes with Powershell (via NtQuerySystemInformation)"
tags: ["memory","powershell"]
author: { link: "https://plus.google.com/111921112014612222144/about", name: Chris Duck }
---
One of the more interesting values to determine how much memory to allocate a machine is the *Peak Committed Bytes*. This value is available as "Commit Charge (K) - Peak" from Windows 2003 Task Manger and from [Sysinternals Process Explorer][procexp] and is a good representation of the maximum amount of memory that has been used at once since the computer was last rebooted. Wikipedia has more details about the [Commit Charge][] numbers if you want to read more.

The current committed bytes and current commit limit are both available as memory performance counters and can be accessed using the WMI class [``Win32_PerfFormattedData_PerfOS_Memory``][perfosmemory] as ``CommitLimit`` and ``CommittedBytes``. Unfortunately, Microsoft has not provided a performance counter for the peak committed bytes. In fact, the only way I have been able to locate this counter is through the undocumented [``NtQuerySystemInformation``][querysysinfo] function of ntdll.dll.

Powershell can be used to call unmanaged APIs as described in [Powershell P/Invoke Walkthrough][holmes] by Lee Holmes. I used the information in Lee's post as well as the examples on [www.pinvoke.net][pinvoke] and the python solution by Mike Driscoll at [Python: Finding the Commit Charge Values in Windows][pyhonpeak] to construct the following Powershell script to query for the committed bytes peak value:

{% highlight powershell linenos %}
<# 
.SYNOPSIS 
    Returns the PeakCommitment value using NtQuerySystemInformation 

.DESCRIPTION 
    Uses p/Invoke to query the undocumented (unsupported) NtQuerySystemInformation 
    function in ntdll.dll. 

.NOTES 
    Author : Chris Duck 
    Name : Get-CommittedBytesPeak.ps1 
     
.LINK 
    http://blog.whatsupduck.net 
     
.INPUTS 
    None 
     
.OUTPUTS 
    The value of committed bytes peak in bytes. 

.EXAMPLE 
get-committedbytespeak.ps1 

Returns the value for committed bytes peak on the local machine. 
.EXAMPLE 
[string]::format("{0:#,#}Kb", (.\get-committedbytespeak.ps1) / 1KB) 

Formats the value for committed bytes peak on the local machine as 8,301,621Kb. 
.EXAMPLE 
Invoke-Command remoteserver -FilePath .\get-committedbytespeak.ps1 

Returns the value for committed bytes peak on a remote machine named "remoteserver". 
#> 
$sig = @' 
[StructLayout(LayoutKind.Sequential)] 
public struct SYSTEM_PERFORMANCE_INFORMATION { 
    public Int64 IdleTime; 
    public Int64 ReadTransferCount; 
    public Int64 WriteTransferCount; 
    public Int64 OtherTransferCount; 
    public uint ReadOperationCount; 
    public uint WriteOperationCount; 
    public uint OtherOperationCount; 
    public uint AvailablePages; 
    public uint TotalCommittedPages; 
    public uint TotalCommitLimit; 
    public uint PeakCommitment; 
    public uint PageFaults; 
    public uint WriteCopyFaults; 
    public uint TransitionFaults; 
    public uint Reserved1; 
    public uint DemandZeroFaults; 
    public uint PagesRead; 
    public uint PageReadIos; 
    public ulong Reserved2; 
    public uint PagefilePagesWritten; 
    public uint PagefilePageWriteIos; 
    public uint MappedFilePagesWritten; 
    public uint MappedFilePageWriteIos; 
    public uint PagedPoolUsage; 
    public uint NonPagedPoolUsage; 
    public uint PagedPoolAllocs; 
    public uint PagedPoolFrees; 
    public uint NonPagedPoolAllocs; 
    public uint NonPagedPoolFrees; 
    public uint TotalFreeSystemPtes; 
    public uint SystemCodePage; 
    public uint TotalSystemDriverPages; 
    public uint TotalSystemCodePages; 
    public uint SmallNonPagedLookasideListAllocateHits; 
    public uint SmallPagedLookasideListAllocateHits; 
    public uint Reserved3; 
    public uint MmSystemCachePage; 
    public uint PagedPoolPage; 
    public uint SystemDriverPage; 
    public uint FastReadNoWait; 
    public uint FastReadWait; 
    public uint FastReadResourceMiss; 
    public uint FastReadNotPossible; 
    public uint FastMdlReadNoWait; 
    public uint FastMdlReadWait; 
    public uint FastMdlReadResourceMiss; 
    public uint FastMdlReadNotPossible; 
    public uint MapDataNoWait; 
    public uint MapDataWait; 
    public uint MapDataNoWaitMiss; 
    public uint MapDataWaitMiss; 
    public uint PinMappedDataCount; 
    public uint PinReadNoWait; 
    public uint PinReadWait; 
    public uint PinReadNoWaitMiss; 
    public uint PinReadWaitMiss; 
    public uint CopyReadNoWait; 
    public uint CopyReadWait; 
    public uint CopyReadNoWaitMiss; 
    public uint CopyReadWaitMiss; 
    public uint MdlReadNoWait; 
    public uint MdlReadWait; 
    public uint MdlReadNoWaitMiss; 
    public uint MdlReadWaitMiss; 
    public uint ReadAheadIos; 
    public uint LazyWriteIos; 
    public uint LazyWritePages; 
    public uint DataFlushes; 
    public uint DataPages; 
    public uint ContextSwitches; 
    public uint FirstLevelTbFills; 
    public uint SecondLevelTbFills; 
    public uint SystemCalls; 
} 

[DllImport("ntdll.dll")] 
public static extern int NtQuerySystemInformation( 
    uint SYSTEM_INFORMATION_CLASS, 
    ref SYSTEM_PERFORMANCE_INFORMATION returnStruct, 
    uint length, 
    ref uint returnLength); 
'@ 

Add-Type -MemberDefinition $sig -Name NTDLL -Namespace Win32 > $null 

$out = New-Object Win32.NTDLL+SYSTEM_PERFORMANCE_INFORMATION 
$outlen = New-Object int 

[Win32.NTDLL]::NtQuerySystemInformation(2, [ref]$out, [System.Runtime.InteropServices.Marshal]::SizeOf($out), [ref]$outlen) > $null 
return $out.PeakCommitment * 4096
{% endhighlight %}

As shown in the examples included in the script, this can be used with ``Invoke-Command`` to run on remote servers. It could even be combined with [``Win32_OperatingSystem.TotalVisibleMemorySize``][win32os] to determine if a server has enough (or too much) memory allocated to it. Just remember that the counter starts over every time the server is rebooted, so make sure there has been plenty of time since the last reboot when you are reading this number or it may not be an accurate reflection of all of the server's workloads.

[procexp]: http://technet.microsoft.com/en-us/sysinternals/bb896653.aspx
[commit charge]: http://en.wikipedia.org/wiki/Commit_charge
[holmes]: http://www.leeholmes.com/blog/PowerShellPInvokeWalkthrough.aspx
[pinvoke]: http://www.pinvoke.net
[pythonpeak]: http://www.blog.pythonlibrary.org/2010/03/05/python-finding-the-commit-charge-values-in-windows/
[perfosmemory]: http://msdn.microsoft.com/en-us/library/aa394268(VS.85).aspx
[querysysinfo]: http://msdn.microsoft.com/en-us/library/ms724509(VS.85).aspx
[win32os]: http://msdn.microsoft.com/en-us/library/aa394239(VS.85).aspx