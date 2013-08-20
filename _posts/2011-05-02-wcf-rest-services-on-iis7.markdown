---
layout: post
title: "WCF REST Services on IIS7"
tags: ["access denied","net40","rest","wcf"]
author: { link: "https://plus.google.com/111921112014612222144/about", name: Chris Duck }
---
If you're using everything below:

* A .svc file for activation, hosted locally (not over UNC) with or without fixed credentails
* Windows Authentication

You will fall under the "NTFS ACL-based Authorization" rules in this document ([http://technet.microsoft.com/en-us/library/dd163543.aspx][ntfsacl]). If that is the case and you are developing a REST service, you will probably experience an Access Denied error the first time you try and PUT a new object (assuming your application doesn't have write access to its own code).

The NTFS ACL-based authorization is built in to the core of IIS 7 so there is no way to disable it, except for breaking one of the conditions that triggers it. The solution for me was to eliminate the physical file that my service was mapping to (ie my ServiceName.svc file). This is possible due to a new feature in .Net 4.0 called Configuration-Based Activation (CBA).

You can read a little bit about CBA and see the basic configuration here: [http://blogs.msdn.com/b/rampo/archive/2009/10/27/activation-without-svc-files-config-based-activation-cba.aspx][activationcba]

This site has a full example of a service along with the full configuration: [http://geekswithblogs.net/michelotti/archive/2010/08/21/restful-wcf-services-with-no-svc-file-and-no-config.aspx][geekblog]

Neither of these sites was enough to get my service working though. I had a service that was telling me it could not work with Windows authentication turned on and that I needed to enable Anonymous. The bit that I was missing from my config was this:

{% highlight xml %}
<system.serviceModel>
  <bindings>
    <basicHttpBinding>
      <binding>
        <security mode="TransportCredentialOnly">
          <transport clientCredentialType="Windows" />
        </security>
      </binding>
    </basicHttpBinding>
  </bindings>
</system.serviceModel>
{% endhighlight %}

Which I found here: [http://blogs.msdn.com/b/drnick/archive/2007/03/23/preventing-anonymous-access.aspx][preventanon]

At this point, I stopped getting errors, but my service only returned blank pages, not any data. The last piece was to configure my service activation element with the System.ServiceModel.Activation.WebServiceHostFactory like this:

{% highlight xml %}
<system.serviceModel>
  <serviceHostingEnvironment aspNetCompatibilityEnabled="true">
    <serviceActivations>
      <add
        factory="System.ServiceModel.Activation.WebServiceHostFactory"
          relativeAddress="ServiceName.svc"
          service="Namespace.ServiceClass" />
      </serviceActivations>
    </serviceHostingEnvironment>
</system.serviceModel>
{% endhighlight %}

[ntfsacl]: http://technet.microsoft.com/en-us/library/dd163543.aspx
[activationcba]: http://blogs.msdn.com/b/rampo/archive/2009/10/27/activation-without-svc-files-config-based-activation-cba.aspx
[geekblog]: http://geekswithblogs.net/michelotti/archive/2010/08/21/restful-wcf-services-with-no-svc-file-and-no-config.aspx
[preventanon]: http://blogs.msdn.com/b/drnick/archive/2007/03/23/preventing-anonymous-access.aspx