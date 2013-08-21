---
layout: post
title: "Kerberos Authentication in IIS and IE"
tags: ["authentication","delegation","ie","iis","impersonation","kerberos"]
author: { link: "https://plus.google.com/111921112014612222144/about", name: Chris Duck }
---
###What is Kerberos###

Kerberos authentication is very useful when you need to impersonate the end user's credentials to access another system.  This is also known as a double-hop authentication.  The alternative to implementing Kerberos on the initial request is to enable constrained delegation with protocol transition.  This will enable the client (IE) to fall back to NTLM authentication to the server (IIS) and then the server will transition the authentication token to Kerberos to pass along to the back end systems (SQL, SSRS, web services, cifs, etc).  Constrained delegation can be hard to implement and maintain as you have to approve each allowed back end service the front end server is allowed to delegate to, but this is also more secure as your credentials cannot be delegated to any random service on the network.

This post is going to cover the basics of getting Kerberos working and the speed bumps I have encountered in my implementations at work.  If you want to learn the details behind what is going on, I recommend you read the series posted by Ken Shaefer on his blog, starting with [What is Kerberos and how does it work?][whatis].

###Configuring Kerbros on IIS###

Initially, you need to determine two pieces of information to successfully implement Kerberos:

1. What is the URL my service will be exposed at?
    For example: ``http://www.example.com``
2. What is the account the service will be running as?
    For example: ``corp.example.com\wwwPool``

###Determining the SPN###

The URL will be used to construct the [Service Principal Name (SPN)][spn] for your service.  This will be used by the KDC (a Domain Controller in AD) to locate the service account that is running your site.  In my example above, IE will generate an SPN like this:

> ``HTTP/www.example.com``

Some things to watch out for here are:

* If your page is hosted on a non-standard port (not 80 or 443), out of the box IE will ignore the port when generating the SPN.  This means you cannot have 2 websites running on the same DNS name and different application pool identities, unless you implement [KB908209][] on all of your IE clients who will be accessing your site.  If you are running IE6, you have to make sure your version includes the hotfix listed in the KB before it will read the registry keys.  All later versions already include the hotfix, but you still have to apply the registry key changes listed in the KB as the default behavior is still to ignore the port.  I do not have any information on how other browsers construct their SPNs.
* You cannot use a CNAME record for your DNS entry without applying the registry changes in [KB911149][] (IE6 also requires the hotfix, newer versions already have the patch included).  This is because IE will use the A Name that the CNAME is pointing to when it constructs the SPN.  You can see this in action by disabling IWA and browsing to the site.  On the credential prompt you will see the server listed as the A Name instead of the correct CNAME record.  You can either apply this KB or use an A Name record to work around this issue.

###Assigning the SPN to the Correct Account###

The next piece of the puzzle is the account you are running the site as.  Kerberos is designed to ensure the identity of the user to the server AND the server to the user.  This requires an administrator to link the service (site) to the account that is supposed to be running that service, which is done by setting an SPN on the application pool identity account.  The SPN needs to match the one IE will generate exactly so the correct account can be located in AD.

If you are running this site on multiple servers (ie behind a load balancer or using round-robin DNS), you have to setup a domain service account because the two-way authentication requires the service (your site) maps to a single service account, not to two different machine accounts.

Since I used a domain account in my example above, I would use the following command to create my SPN <sup>[1]</sup>:

> ``setspn.exe -s& HTTP/www.example.com corp.example.com\wwwPool``
 
If you have applied KB908209 and are running your site on a non-standard port, you would use:

> ``setspn.exe -s HTTP/www.example.com:8080 corp.example.com\wwwPool``

When setting an SPN, you need to make sure you have not created a duplicate, as this leaves the KDC (DC in AD) unable to locate the correct account to encrypt the tokens for and will cause kerberos authentication to fail.  Newer versions of setspn.exe have the -s and -x switches to help you locate duplicate SPNs.  You may also need to do a forest wide search using the -f parameter.

If your site is running on the same DNS name as your server AND your site is running as Network Service, you do not need to create an SPN as the KDC will fail back to the host SPN for the computer (ie ``HOST/wfe1.corp.example.com``), which is automatically set on the machine account when it joins the domain.

###Configuring IIS/Asp.NET/IE###

The last step is to make sure the site has "Integrated Windows Authentication"<sup>[3]</sup> enabled and that your IE is showing "Local Intranet" for your zone and that "Automatic Login" is enabled for the zone.  An important note to consider in IIS7+ is that when you enable "Integrated Windows Authentication", you also need to determine if you need to leave kernel mode authentication enabled.  By default, IWA in IIS7 assumes your site will be running under the *Network Service* account which would require your SPN to be set on the machine account.  If you set an SPN on a domain account, you will need to click the "Advanced Settings" link and un-check (disable) kernel mode authentication<sup>[3]</sup> on your site.  This will cause the Kerberos tokens to be processed by the application pool account instead of the machine account.

At this point you should be able to authenticate to your web server using Kerberos. You can verify that you are using Kerberos by checking your security log and look for event 4624 with the "Authentication Package" field set to Kerberos.

###Delegation###

Now that you are successfully authenticating using Kerberos, you may want to pass those credentials on to the next tier of your application.  You'll need to open up Users and Computers and locate the service account.  This is the account that you set the SPN on, in my example above it would be the ``corp.example.com\wwwPool`` account.  You should now have a "Delegation" tab available (this tab only shows up when an SPN is set on an account).  You will need to enable one of the "Trust this user for delegation" settings, you can read about [Simple Delegation][simple]"> and [Constrained Delegation][constrained] at Ken's blog, but the easiest setting to make here would be to enable delegation to any service.  This will allow your site to delegate a user's credentials to any other service running in environment.  If you want to restrict where the delegated credentials can go, you will want to read about constrained delegation.

The final setting you need to make to enable delegation is in your application.  You can either set the entire web application to run using the end user's credentials via the "ASP.Net Impersonation" setting in the "Authentication" module of IIS manager <sup>[2]</sup>, or use the instructions in the section titled *Impersonate the Authenticating User in Code* in [KB306158][] to only impersonate the user in specific code sections in your site.

1. I'm assuming you are using setspn from Vista or newer, if not use "-a" instead of "-s".  The "-s" switch searches for an existing SPN to help prevent duplicates from being set.
2. This sets the &lt;identity&gt; tag in your web.config file to enable impersonation.  Full documentation can be found on [MSDN][id].
3. While this setting can be set in the IIS manager, in IIS7+ the default configuration is for this setting to be saved in the application's web.config file.

[whatis]: http://www.adopenstatic.com/cs/blogs/ken/archive/2006/10/19/512.aspx
[spn]: http://www.adopenstatic.com/cs/blogs/ken/archive/2006/11/19/606.aspx
[kb908209]: http://support.microsoft.com/default.aspx?scid=kb;EN-US;908209
[kb911149]: http://support.microsoft.com/default.aspx?scid=kb;EN-US;911149
[simple]: http://www.adopenstatic.com/cs/blogs/ken/archive/2007/01/28/1282.aspx
[constrained]: http://www.adopenstatic.com/cs/blogs/ken/archive/2007/07/19/8460.aspx
[kb306158]: http://support.microsoft.com/kb/306158/
[id]: http://msdn.microsoft.com/en-us/library/72wdk8cc(VS.71).aspx