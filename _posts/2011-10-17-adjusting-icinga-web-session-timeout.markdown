---
layout: post
title: "Adjusting Icinga-Web Session Timeout"
tags: [icinga,icinga-web,timeout]
author: { link: "https://plus.google.com/111921112014612222144/about", name: Chris Duck }
---
Icinga-Web is a more modern interface to Icinga (as opposed to the Icinga Classic interface that seeks to mimic the traditional Nagios web interface).  A comparison of all three interfaces is provided at the Icinga site (https://www.icinga.org/nagios/webinterface/).

One thing you will quickly notice is that after 24 minutes, your session disappears and you are prompted to log in again.  From a quick glance through the code it appears they are using a very heavy handed garbage collection where they delete any sessions that are older than the php configuration variable session.gc_maxlifetime.  Out of the box (on our RedHat 5.7 distro) this is configured as 1440 (1440 seconds = 24 minutes).  This means that NO session can live past 24 minutes, no matter how frequently you are using it.

###How to Extend the Icinga-Web Session Timeout###

There are two pieces to the Icinga-Web session: PHP max session lifetime variable and the Icinga-Web session cookie lifetime variable.

####To adjust the PHP max session lifetime variable:####

1. Open ``/etc/php.ini``
2. Change the ``session.gc_maxlifetime`` value to something more appropriate

Setting the PHP max session lifetime to 0 will cause no sessions to be cleaned out of your database, which will eventually cause problems.  Icinga really needs to patch this so that accessing the Icinga-Web site updates the ``session_modified`` value and then only do GC on stale sessions.

####To adjust the Icinga-Web session cookie lifetime variable:####

1. Open ``/usr/local/icinga-web/app/config/factories.site.xml``
2. Adjust the ``&lt;ae:parameter name="session_cookie_lifetime"&gt;`` parameter to a more appropriate value

This value sets the lifetime of the cookie in your browser.  Setting it to 0 will cause Icinga-Web to create a session cookie that will be valid for as long as your browser is open.  This is a reasonable setting for your browser, but you will still be subjected to the PHP max lifetime value, so you will still experience timeouts.