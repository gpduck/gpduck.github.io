---
layout: post
title: "Adding a Custom Certificate to McAfee ePO Server 4.0 (Apache)"
tags: ["certificate","epo","java","ssl","tomcat"]
author: { link: "https://plus.google.com/111921112014612222144/about", name: Chris Duck }
---
Our ePO adminitrators came to me asking for help installing an enterprise certificate on our new ePO 4.0 server so they could provide a vanity dns name for management to view reports. [According to McAfee][kb52736], this is not supported in 4.0, but will be a feature of 4.5. Knowing that ePO runs on Tomcat, I was pretty confident that I could get it working anyway... just remember that none of this is supported. If you need a supported solution on 4.0, I recommend adding the self signed certificate to your domain certificate trust list and using the computer name to access the site.

If you just have to have your vanity url, here's how you can get it set up.

The main idea here is to import a certificate that will be trusted by your browsers (either a domain certificate or a public certificate from a trusted CA like EnTrust or Verisign) into the Java keystore that Tomcat is using. Our security team provided us with a certificate and a private key from an existing wildcard certificate for our domain.

In order to locate the correct keystore, I loaded up the Tomcat configuration file located at ``c:\Program Files\McAfee\ePolicy Orchestrator\Server\conf\server.xml``. From here, you need to locate the "Connector" element that is binding to the port for the site you are using. In our case, this is 8443 so the element looks like this:

{% highlight xml %}
<connector acceptcount="100" ciphers="...list of encyrption algorithms..." clientauth="false" disableuploadtimeout="true" enablelookups="false" keystorefile="keystore/server.keystore" keystorepass="*****" maxhttpheadersize="8192" maxsparethreads="75" maxthreads="150" minsparethreads="25" port="8443" scheme="https" secure="true" server="Undefined" sslprotocol="TLS" truststorefile="keystore/ca.keystore" truststorepass="*****" uriencoding="UTF-8"></connector>
{% endhighlight %}

Sun Java provides a tool to edit keystores called [keytool.exe][keytool]. However, there is a limitation on this tool (described [here][importingkeys]) that prevents us from adding a private key separately. Fortunately ePO uses the latest version of Java, so we do have the ability to import a PKCS12 file containing both our public certificate as well as our private key.

First, I had to get my separate files into one PKCS12 file. I did this using the following [OpenSSL][] command:

<div class="psconsole">PS> openssl pkcs12 -export -out c:\temp\store.pfx -in c:\temp\certificate.cer -inkey c:\temp\private.key</div>

Now that I have a PKCS12 file with both the certificate and private key, I can import those into the Java keystore for Tomcat. My first step was to add the JRE\bin to my path and change to the directory of the keystore:

<div class="psconsole">PS> set path=%path%;c:\Program Files\McAfee\ePolicy Orchestrator\JRE\bin<br />
PS> cd C:\Program Files\McAfee\ePolicy Orchestrator\Server\keystore\</div>
 
Next I made a backup of the original McAfee keystore (so we can go back to the supported configuration if needed):

<div class="psconsole">PS> copy server.keystore server.keystore.original</div>

Then I deleted the existing certificate and private key from the keystore, then imported the new pair from the PKCS12 file, and finally renamed the alias for the key to match the original:

<div class="psconsole">PS> keytool -delete -alias mykey -keystore server.keystore<br />
PS> keytool -delete -alias cacert -keystore server.keystore<br />
PS> keytool -importkeystore -srckeystore c:\vhacert\store.pfx -destkeystore server.keystore -srcstoretype pkcs12<br />
PS> keytool -changealias -keystore server.keystore -alias 1 -destalias mykey</div>

Finally, you just need to restart all 3 ePO services. Tomcat should now be providing your custom certificate.

[kb52736]: https://kc.mcafee.com/corporate/index?page=content&amp;id=KB52736
[keytool]: http://java.sun.com/javase/6/docs/technotes/tools/windows/keytool.html
[importingkeys]: http://cunning.sharp.fm/2008/06/importing_private_keys_into_a.html
[openssl]: http://www.slproweb.com/products/Win32OpenSSL.html