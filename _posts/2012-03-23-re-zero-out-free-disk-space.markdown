---
layout: post
title: Re: Zero Out Free Disk Space
tags: [powershell]
author: { link: "https://plus.google.com/111921112014612222144/about", name: Chris Duck }
---
We've been having weekly script club meetings at work where anyone who is interested gets together in a conference room and we all work on scripts together so we all have a chance to learn new techniques while solving our real-world problems at the same time.  This week I developed a script to mimic the behavior of the SysInternals utility SDelete.  The script will be used to reclaim thin-provisioned space from our SAN, and I wanted to develop it during script club to use as an example of how to use the classes in the System.IO namespace to get better IO performance from PowerShell.

One of my co-workers shared the script from the meeting with Don Jones and he was nice enough to post it on [his blog][jonesblog] along with a few comments about the script.


Don's blog doesn't seem to support public comments, so I wanted to take a few minutes to respond to his comments here.  I've reproduced his comments (in italics below) along with my responses:

___I wish the comment-based help was a bit more complete, but I love that they're using it!___

>This script was written in a "class" setting and I was focusing more on solving the task at hand than producing a share-able script.  The parameter block and help content were actually thrown in at the very end of the session just as a quick "finishing touch" and were never even run.  I agree that well documented scripts are important and I try to write more complete help on my scripts when I don't have an audience watching me code :)

___They're overriding $PercentFree to always be 0.5 - not sure if that's on purpose___

>This is a bug due to the way I'm trying to teach programming at work.  I've been encouraging people to use variables for things even when they are just starting a script and are still in "explore" mode, with the idea that this makes it easy to turn the script into a function just by deleting the explicit variable declarations and moving them up to a parameter block.

___Yay! Error handling!___
>I really wanted to take the opportunity to highlight the proper way to deal with external resources (ie file handles, network ports, etc) for my team.  I see a lot of people who either don't bother to close things or don't put the close statements in a finally block and end up leaking resources.

___Yay! Variable-replacement-within-double-quotes instead of concatenation!___

___Really brilliant technique of creating an empty file and then deleting it - clever thinking.___

>Can't really take credit for this one, just replicating the way sdelete works :)

___Kind of a lot of variables. Like, why put 64KB into $ArraySize, and then only use it once? Why not use use the literal 64KB? Doing so would make the script a bit more concise and possibly easier to read.___

>This again comes from my programming style.  At the time I thought there was potential we might want to make $ArraySize a parameter so I built it from the start so that it would be easy to convert down the line if we decided to go that way.  Also I wanted to make it very easy to modify so we could do some performance testing to determine what the optimal block size to write was. In general I try to avoid hard coding any values into the meat of my scripts to make them easier to modify if the needs change down the road.

###After Further Review###

The script that Don was kind enough to review was written live during class and I never even got to the point of saving the script to a file in my editor, much less cleaning it up to make it "enterprise class" or "share worthy".  Some other rough areas I have noticed in it after having time to review it are:

* It should probably test to make sure the file doesn't exist already so it doesn't clobber existing data
* It should test to make sure the $Root path/volume exists
* It should validate that $PercentFree is between 0 and 1
* The delete command should probably be moved up into the finally block to ensure the file gets deleted
* I also would consider putting the whole thing in a process block, adding a "Name" alias to $Root, and enabling "ValueFromPipelineByPropertyName" so you could do:

	``gwmi Win32_Volume | Write-ZeroesToFreeSpace``

###The "Real" Script###

I've sort of posted these last two blog entries in reverse order, as my [previous post][myblog] is the cleaned up version of the script that addresses Don's comments as well as my additional comments posted above.

Thanks again Don for taking the time to review our little script and give us the opportunity to share a little bit of our development process with the community!

[jonesblog]: http://powershell.com/cs/blogs/donjones/archive/2012/03/22/zero-out-free-disk-space.aspx
[myblog]: http://blog.whatsupduck.net/2012/03/powershell-alternative-to-sdelete.html