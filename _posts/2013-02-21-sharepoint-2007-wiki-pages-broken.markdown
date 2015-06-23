---
layout: post
title: SharePoint 2007 Wiki Pages Broken
tags: [powershell, sharepoint]
author: { link: "https://plus.google.com/111921112014612222144/about", name: Chris Duck }
---
One of our SharePoint wiki libraries got in a state where we couldn't edit any of the pages.  When we clicked "Edit" we would get the document properties page instead of the wiki editor page.  I believe the root cause was someone moving a page from another wiki and the page ended up in the library as a "document" instead of a "wiki page".

I found a solution [here](http://social.technet.microsoft.com/forums/en-US/sharepointgenerallegacy/thread/99b145bb-2c31-4bdd-8f52-060936ec5b97), but it required installing SharePoint Manager 2007 in order to change the ``ContentTypesEnabled`` property on the list.  I wasn't really wanting to install any additional software, so I set out to determine if there was a way to modify the property using the SharePoint API, and it turns out there is.

The following script uses the SharePoint API to modify your list properties to enable the content types UI elements in your list settings in order to clean up your wiki content types.  I ran it from a SharePoint server in my farm, I assume it's possible to run remotely but have no idea how that would be done.

{% highlight powershell %}
[reflection.assembly]::LoadWithPartialName("Microsoft.SharePoint")
$Site = [Microsoft.SharePoint.SPSite]("http://site.com")
$Web = $Site.OpenWeb("pat/to/web")
$WikiList = $Web.Lists["WikiListName"]
$WikiList.ContentTypesEnabled = $true
$WikiList.Update()
{% endhighlight %}

With this script, you can follow the instructions linked above to fix the content types on your existing documents, using the script instead of SharePoint Manager to enable editing the content types on your wiki library.  Then you can delete the "Document" content type from your library.

After you have everything cleaned up, you can run the following script to return your wiki library to the default configuration.

{% highlight powershell %}
[reflection.assembly]::LoadWithPartialName("Microsoft.SharePoint")
$Site = [Microsoft.SharePoint.SPSite]("http://site.com")
$Web = $Site.OpenWeb("pat/to/web")
$WikiList = $Web.Lists["WikiListName"]
$WikiList.ContentTypesEnabled = $false
$WikiList.Update() 
{% endhighlight %}