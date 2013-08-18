---
layout: post
title: A PowerShell Alternative to SDelete
tags: [powershell,sdelete,sysinternals]
author: { link: "https://plus.google.com/111921112014612222144/about", name: Chris Duck }
excerpt: "Many storage appliances support thin provisioning by not storing large blocks of zeros on disk, thus saving expensive physical disks for actual data.  One of the challenges of this feature is that Windows (or most file systems really) does not zero out space that was used by files that have been deleted.  This means that over time as files are written an deleted, the amount of physical disk that is saved by thin provisioning grows smaller."
---
###Problem Background###

Many storage appliances support thin provisioning by not storing large blocks of zeros on disk, thus saving expensive physical disks for actual data.  One of the challenges of this feature is that Windows (or most file systems really) does not zero out space that was used by files that have been deleted.  This means that over time as files are written an deleted, the amount of physical disk that is saved by thin provisioning grows smaller.

One popular solution (really the only one we've been able to find) is to use the SysInternals utility [SDelete's][SDelete] ``-z`` switch to write zeros to all the free space, thus allowing the storage appliance to use all that empty space for something else.  The challenge with sdelete is that it only supports volumes mounted as drive letters, not volumes that are mounted to folders.  Another concern with SDelete is that it appears to fill up the entire disk, if only for that brief second between finishing writing the file out and deleting the file.  We were concerned with using this tool at work on a workload like SQL that might not take kindly to a disk filling up.

Our storage administrator tried to solve this problem using the standard PowerShell techniques of redirecting null strings to files and found the performance to be somewhat lacking.  I don't want to get into a detailed analysis of PowerShell IO characteristics (mostly because I haven't spent much time researching how PowerShell does IO), but instead just post that the solution is to turn to the System.IO .Net namespace and perform the IO operations the "hard way".

###The Script###

Here is the script I came up with using a FileStream to write out the zero file.  We informally compared a couple of runs between this script and sdelete and saw roughly the same performance.

##Write-ZeroesToFreeSpace.ps1##

{% highlight powershell linenos %}
<#
.SYNOPSIS
 Writes a large file full of zeroes to a volume in order to allow a storage
 appliance to reclaim unused space.

.DESCRIPTION
 Creates a file called ThinSAN.tmp on the specified volume that fills the
 volume up to leave only the percent free value (default is 5%) with zeroes.
 This allows a storage appliance that is thin provisioned to mark that drive
 space as unused and reclaim the space on the physical disks.
 
.PARAMETER Root
 The folder to create the zeroed out file in.  This can be a drive root (c:\)
 or a mounted folder (m:\mounteddisk).  This must be the root of the mounted
 volume, it cannot be an arbitrary folder within a volume.
 
.PARAMETER PercentFree
 A float representing the percentage of total volume space to leave free.  The
 default is .05 (5%)

.EXAMPLE
 PS> Write-ZeroesToFreeSpace -Root "c:\"
 
 This will create a file of all zeroes called c:\ThinSAN.tmp that will fill the
 c drive up to 95% of its capacity.
 
.EXAMPLE
 PS> Write-ZeroesToFreeSpace -Root "c:\MountPoints\Volume1" -PercentFree .1
 
 This will create a file of all zeroes called
 c:\MountPoints\Volume1\ThinSAN.tmp that will fill up the volume that is
 mounted to c:\MountPoints\Volume1 to 90% of its capacity.

.EXAMPLE
 PS> Get-WmiObject Win32_Volume -filter "drivetype=3" | Write-ZeroesToFreeSpace
 
 This will get a list of all local disks (type=3) and fill each one up to 95%
 of their capacity with zeroes.
 
.NOTES
 You must be running as a user that has permissions to write to the root of the
 volume you are running this script against. This requires elevated privileges
 using the default Windows permissions on the C drive.
#>
param(
  [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
  [ValidateNotNullOrEmpty()]
  [Alias("Name")]
  $Root,
  [Parameter(Mandatory=$false)]
  [ValidateRange(0,1)]
  $PercentFree =.05
)
process{
  #Convert the $Root value to a valid WMI filter string
  $FixedRoot = ($Root.Trim("\") -replace "\\","\\") + "\\"
  $FileName = "ThinSAN.tmp"
  $FilePath = Join-Path $Root $FileName
  
  #Check and make sure the file doesn't already exist so we don't clobber someone's data
  if( (Test-Path $FilePath) ) {
    Write-Error -Message "The file $FilePath already exists, please delete the file and try again"
  } else {
    #Get a reference to the volume so we can calculate the desired file size later
    $Volume = gwmi win32_volume -filter "name='$FixedRoot'"
    if($Volume) {
      #I have not tested for the optimum IO size ($ArraySize), 64kb is what sdelete.exe uses
      $ArraySize = 64kb
      #Calculate the amount of space to leave on the disk
      $SpaceToLeave = $Volume.Capacity * $PercentFree
      #Calculate the file size needed to leave the desired amount of space
      $FileSize = $Volume.FreeSpace - $SpacetoLeave
      #Create an array of zeroes to write to disk
      $ZeroArray = new-object byte[]($ArraySize)
      
      #Open a file stream to our file 
      $Stream = [io.File]::OpenWrite($FilePath)
      #Start a try/finally block so we don't leak file handles if any exceptions occur
      try {
        #Keep track of how much data we've written to the file
        $CurFileSize = 0
        while($CurFileSize -lt $FileSize) {
          #Write the entire zero array buffer out to the file stream
          $Stream.Write($ZeroArray,0, $ZeroArray.Length)
          #Increment our file size by the amount of data written to disk
          $CurFileSize += $ZeroArray.Length
        }
      } finally {
        #always close our file stream, even if an exception occurred
        if($Stream) {
          $Stream.Close()
        }
        #always delete the file if we created it, even if an exception occurred
        if( (Test-Path $FilePath) ) {
          del $FilePath
        }
      }
    } else {
      Write-Error "Unable to locate a volume mounted at $Root"
    }
  }
} 
{% endhighlight %}

[sdelete]: http://technet.microsoft.com/en-us/sysinternals/bb897443