---
layout: post
title: "Configuring Icinga Classic for Active Directory Authentication via IWA"
tags: ["apache","authentication","icinga","kerberos"]
author: { link: "https://plus.google.com/111921112014612222144/about", name: Chris Duck }
---
Out of the box, the Icinga Classic interface uses standard Apache .htaccess files ([http://docs.icinga.org/1.5.0/en/cgiauth.html][cgiauth]) to secure both the CGIs and the classic web interface.  Living in an Active Directory world, I'm always looking for ways to integrate products with my existing AD credentials so I don't have to log in again.  I decided our move from Nagios to Icinga was a good opportunity to figure out how achieve integrated Windows authentication (IWA) in Apache since we were having to figure out how to configure everything anyway.

To maintain my focus on this post, I'm not going to cover installing Icinga or configuring Kerberos on your Linux box.  I'm also only covering instructions for RedHat 5.7.  Most of my information was pulled from the Apache + Windows Kerberos tutorial found here: [http://grolmsnet.de/kerbtut/][kerbtut]

###Example Configuration###

Throughout this example, I'm going to use the following hypothetical configuration:

* Icinga site = icinga.example.com
* AD Domain FQDN = corp.example.com
* AD Domain Netbios = ExampleCorp
* icinga.example.com is an A record in DNS (important for IE spn building)
* Apache Configuration = /etc/httpd/conf and /etc/httpd/conf.d
* Apache User = apache
* Apache Group = apache
* My AD Credentials = ExampleCorp\cduck or cduck@corp.example.com

###Create an AD Account###

The first step is to create an account in AD for the site to use to validate credentials with.  In this example, I'm going to use apache_icinga.example.com. The account is configured as follows in AD:

* **Full name:** apache_icinga.example.com
* **User UPN logon:** apache_icinga.example.com@corp.example.com
* **User SamAccountName:** ExampleCorp\apache_icinga.exampl
* **Password Never Expires**
* **Password:** Pass1234

###Generate a Keytab for the AD Account###

This step will use the Windows command-line utility ktpass to generate a keytab file for the AD account so that the Linux server will have a valid private key for the account.  This command was run on a Windows 2008 R2 server, alternate commands are available in the [original tutorial][kerbtut]. Note that this command should all be run on one line.

``c:\ktpass -princ HTTP/icinga.example.com@CORP.EXAMPLE.COM -mapuser apache_icinga.example.com@CORP.EXAMPLE.COM -crypto RC4-HMAC-NT -ptype KRB5_NT_PRINCIPAL -pass Pass1234 -out c:\icinga.example.com.keytab -setupn``

The ``-setupn`` option above is important to include (and missing from the original tutorial) as it prevents ktpass from altering the account's userPrincipalName attribute.  The remainder of this tutorial assume that the userPrincipalName has been preserved as above and not altered by ktpass.

You now need to copy the keytab file created above to your Icinga server. I recommend using [PSCP][], but you can do this however you want.  I copied my keytab to ``/etc/httpd/conf`` as it will be referenced in the Apache.conf files that are living there.

Now you need to change the owner and permissions for the keytab to the apache user and group:

	chown apache:apache /etc/httpd/conf/icinga.example.com.keytab
	chmod 400 /etc/httpd/conf/icinga.example.com.keytab

###Configure Apache to use Kerberos###

Edit your icinga.conf apache file (mine is at /etc/httpd/conf.d/icinga.conf). You need to add the [kerberos authorization module][modauthkerb] and then configure the Icinga directories to use it for authentication. Here is my icinga.conf with the changes <span class="highlight-add">highlighted</span>:

{% highlight apacheconf %}
# SAMPLE CONFIG SNIPPETS FOR APACHE WEB SERVER
#
# This file contains examples of entries that need
# to be incorporated into your Apache web server
# configuration file.  Customize the paths, etc. as
# needed to fit your system.
<span class="highlight-add">LoadModule auth_kerb_module modules/mod_auth_kerb.so</span>
ScriptAlias /icinga/cgi-bin "/usr/lib64/icinga/cgi"
<Directory "/usr/lib64/icinga/cgi">
#  SSLRequireSSL
   Options ExecCGI
   AllowOverride None
   Order allow,deny
   Allow from all
#  Order deny,allow
#  Deny from all
#  Allow from 127.0.0.1
   AuthName "Icinga Access"
<span class="highlight-add"># AuthType Basic</span>
<span class="highlight-add">   AuthType Kerberos</span>
<span class="highlight-add">   KrbAuthRealms CORP.EXAMPLE.COM</span>
<span class="highlight-add">   KrbServiceName HTTP/icinga.example.com@CORP.EXAMPLE.COM</span>
<span class="highlight-add">   Krb5Keytab /etc/httpd/conf/icinga.example.com.keytab</span>
<span class="highlight-add">   KrbMethodNegotiate on</span>
<span class="highlight-add">   KrbMethodK5Passwd on</span>
<span class="highlight-add">#   AuthUserFile /etc/icinga/htpasswd.users</span>
   Require valid-user

Alias /icinga "/usr/share/icinga/"

<Directory "/usr/share/icinga/">
#  SSLRequireSSL
   Options None
   AllowOverride All
   Order allow,deny
   Allow from all
#  Order deny,allow
#  Deny from all
#  Allow from 127.0.0.1
   AuthName "Icinga Access"
<span class="highlight-add"># AuthType Basic</span>
<span class="highlight-add">   AuthType Kerberos</span>
<span class="highlight-add">   KrbAuthRealms CORP.EXAMPLE.COM</span>
<span class="highlight-add">   KrbServiceName HTTP/icinga.example.com@CORP.EXAMPLE.COM</span>
<span class="highlight-add">   Krb5Keytab /etc/httpd/conf/icinga.example.com.keytab</span>
<span class="highlight-add">   KrbMethodNegotiate on</span>
<span class="highlight-add">   KrbMethodK5Passwd on</span>
<span class="highlight-add">#   AuthUserFile /etc/icinga/htpasswd.users</span>
   Require valid-user
{% endhighlight %}

Restart Apache (/etc/init.d/httpd restart) and you should be able to authenticate via IWA to your Icinga site.

###Grant IWA Credentials Access to the Icinga CGIs###

mod_auth_kerberos will set your username to your userPrincipalName from AD. In my implementation, the entire userPrincipalName was converted to upper case, even though it wasn't set that way in Active Directory.  So for this example my username according to Icinga would be CDUCK@CORP.EXAMPLE.COM.  This is the value that you need to use to grant permissions in the [Icinga CGIs][cgiauth]. In my case, my Icinga CGI config file was at /etc/icinga/cgi.cfg and I edited the following lines to grant my account access:

<span class="code">``authorized_for_system_information=CDUCK@CORP.EXAMPLE.COM``<br />
``authorized_for_configuration_information=CDUCK@CORP.EXAMPLE.COM``<br />
``authorized_for_system_commands=CDUCK@CORP.EXAMPLE.COM``<br />
``authorized_for_all_service_commands=CDUCK@CORP.EXAMPLE.COM``<br />
``authorized_for_all_host_commands=CDUCK@CORP.EXAMPLE.COM``</span>

</p><p>You'll want to read the Icinga documentation on the CGI authorization and determine what is appropriate for your environment.</p>
<p>***** Updated 3-24-2012 - The crypto parameter for the ktpass utility should read "RC4-HMAC-NT" as pointed out by reader Stefan.  Thanks for the correction!</p>

[cgiauth]: http://docs.icinga.org/1.5.0/en/cgiauth.html
[kerbtut]: http://grolmsnet.de/kerbtut/
[pscp]: http://www.chiark.greenend.org.uk/~sgtatham/putty/download.html
[modauthkerb]: http://modauthkerb.sourceforge.net/