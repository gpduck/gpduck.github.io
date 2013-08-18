---
layout: post
title: Deploying WDS Across Domain Forests
tags: [dotnet, hacking, powershell]
author: { link: "https://plus.google.com/111921112014612222144/about", name: Chris Duck }
---
I'm not going to cover how to setup your unattend file, or how to customize a PE image... there are plenty of people out there who have covered those topics.  What I do want to cover here is how to edit your PE image so that you can force it to connect to a specific WDS server.  This will help solve the problem where you want to deploy computers into two domains on the same subnet, but WDS only looks for prestaged computers objects on the domain it is joined to.

This process does require two WDS servers, one joined to each domain you want to deploy computers into.  I'm going to refer to them as WDSPrimary and WDSSecondary.  I'm assuming you have either WDSPrimary configured to listen to broadcast requests, or your DHCP server options 66 and 67 pointed at WDSPrimary and boot\x64\wdsnbp.com respectively.  The challenge is to be able to add a boot image on WDSPrimary that tells setup.exe to contact WDSSecondary to deploy the image.

###Extract Your Existing Boot Image###

Assuming you already have a boot image customized for deploying to WDSPrimary, export that image to a work folder using the Windows Deployment Services management console.  For this example, I'm going to use c:\PEBoot\SecondaryBoot.wim as the extracted file name.

###Mount the Image###

Using Windows 7 or Server 2008 R2, first create a mount folder to mount the wim image to.  I'll use c:\PEBoot\mount.  Then run the following command to mount the image (remember to launch your shell as Administrator)

``dism /mount-wim /mountdir:c:\PEBoot\mount /wimfile:c:\PEBoot\SecondaryBoot.wim /index:2``

###Configure the PE Image###

Window PE includes a file called [winpeshl.ini](http://technet.microsoft.com/en-us/library/dd744560(WS.10).aspx) ([Win 8/2012 version](http://technet.microsoft.com/en-us/library/hh825046.aspx)) that you can use to specify custom applications to run instead of starting setup.exe automatically.  We will use this file to start [setup.exe with custom options](http://technet.microsoft.com/en-us/library/dd799264(WS.10).aspx) that will tell it to connect to WDSSecondary instead of defaulting to the WDS server that it booted from (WDSPrimary).

Open notepad and create a new file with the following contents

``
[LaunchApps]
%SYSTEMDRIVE%\windows\system32\wpeinit.exe
%SYSTEMDRIVE%\setup.exe, "/wds /wdsdiscover /wdsserver:WDSSecondary.contoso.com"
``

Make sure you enclose multiple command-line parameters in double quotes when you specify them in winpeshl.ini or they will not be properly passed to the command.

###Unmount the PE Image and Import it into WDS###

Now we need to unmount the wim file and commit our changes.  This is accomplished using the following command.

``dism /unmount-wim /mountdir:c:\PEBoot\mount /commit``

Now all that is left is to import the new boot image into the primary WDS server that all clients boot to.  In this case, you would go to WDSPrimary and right click "Boot Images" and select "Add Boot Image".  Now when you PXE boot, you will have an option to boot to the customized image that connects to WDSSecondary to deploy the operating system.