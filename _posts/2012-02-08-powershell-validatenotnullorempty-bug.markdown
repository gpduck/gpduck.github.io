---
layout: post
title: "Powershell ValidateNotNullOrEmpty Bug"
tags: [powershell]
author: { link: "https://plus.google.com/111921112014612222144/about", name: Chris Duck }
---
I was showing a co-worker how easy it is to ensure that the parameters to his script were actually being set using the ``[Parameter(Mandatory=$true)]`` and ``[ValidateNotNullOrEmpty()]`` decorators on his parameter declaration block, and we encountered a bug where he was able to pass an empty string as a parameter to his function and the validation did not catch it.

###Reproduction Steps###

In our search to explain what was going on, we located a couple of forum posts which led us to 2 bugs filed on connect that I believe are related to the same problem: [610176][] and [677559][].

Our steps mirrored [610176][] almost exactly, so I'm going to copy the reproduction steps from that bug here, with a few changes.

{% highlight powershell linenos %}
Function test
{
  param([Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $param
  )
  $param.GetType().FullName
  "Entered: '$param'"
  [string]::IsNullOrEmpty($param)
} 
{% endhighlight %}

The expected result when you pass an empty string would be an error stating that the parameter failed vaildation, no matter how you generated that string:

<div class="psconsole"><span class="code">PS> test ""</span><br />
<span style="color: red; background: black;">test : Cannot validate argument on parameter 'param'. The argument is null or empty. Supply an argument that is not null or empty and then try the command again.</span></div>

However, when you call the function without any parameters, Powershell sees that you forgot a mandatory parameter and prompts you for a value.  If you just press &lt;enter&gt;, the empty string incorrectly passes validation and your function is executed:

<pre><span class="code">PS> test

cmdlet test at command pipeline position 1
Supply values for the following parameters:
param:&lt;just press enter here&gt;

System.String
Entered: ''
True</span></pre>

As you can see, the parameter is a string and it is an empty string, which should never have passed validation.

###Explanation###

Using [Reflector][], I tracked down the ``ValidateNotNullOrEmptyAttribute`` class (load ``System.Management.Automation`` from the GAC and then drill down to the ``System.Management.Automation`` namespace and then the ``Validate`` method on the ``ValidateNotNullOrEmptyAttribute`` class) and discovered the following code:

{% highlight csharp %}
//... (tests the arguments variable for null)

str = arguments as string;
if (str != null)
{
    if (string.IsNullOrEmpty(str))
    {
        throw new ValidationMetadataException("ArgumentIsEmpty", null, "Metadata", ValidateNotNullOrEmptyFailure", new object[0]);
    }
}
else
{

//... (continues on to handle special cases for enumerable objects)
{% endhighlight %}

You can see they are using the [C# as operator][as] to attempt to convert the parameter into a ``string`` object.  The problem is that Powershell uses an [adaptive type system][adaptive] to work magic on some particularly annoying types (XML and WMI come to mind), and apparently the method that is reading the input when you forget to specify a mandatory parameter (and also the Read-Host cmdlet as demonstrated in [677559][]) are returning Powershell objects that ___look___ like strings, but aren't actual .Net strings.

###Go Vote###

If you're not a fan of this behavior, go [vote for the bug on Connect][610176].  I've posted a comment with a link back to this post, so hopefully there is enough detail here to get the problem fixed in V3 :)

###Digging Deeper###

So I fired up Visual C# Express and wrote a little C# program that embeds a Powershell runspace and reproduces the problem, then extracts the variables and tests them in C# to see what types the objects really are.  While I was testing different scenarios with my co-worker, I discovered you can also convert a string object to a Powershell adapted object by just referencing ``$MyString.PSBase``, and this breaks ``ValidateNotNullOrEmpty`` just as badly as ``Read-Host``, so I used this method in my C# application as it was easier to code than trying to work out how to get input from the C# console to the Powershell runtime properly.

{% highlight csharp %}
using System;
using System.Collections.Generic;
using System.Text;
using System.Management.Automation;
using System.Management.Automation.Runspaces;

namespace ConsoleApplication1
{
  public class Program
  {
    public static void Main(string[] args)
    {
      using (Runspace rs = RunspaceFactory.CreateRunspace())
      {
        rs.Open();
        using (Pipeline pl = rs.CreatePipeline())
        {
          pl.Commands.AddScript("$str = \"\"");
          pl.Commands.AddScript("$pso = \"\"");
          pl.Commands.AddScript("$pso.psbase");
          pl.Invoke();
          Object oStr = rs.SessionStateProxy.GetVariable("str");
          Object oPso = rs.SessionStateProxy.GetVariable("pso");
          Console.WriteLine(string.Format("oStr type = {0}", oStr.GetType().FullName));
          Console.WriteLine(string.Format("oPso type = {0}", oPso.GetType().FullName));
          string sStr = oStr as string;
          if (sStr != null)
          {
            Console.WriteLine(string.Format("sStr.IsNullOrEmpty = {0}", string.IsNullOrEmpty(sStr)));
          }
          else
          {
            Console.WriteLine("oStr is not a string");
          }
          string sPso = oPso as string;
          if (sPso != null)
          {
            Console.WriteLine(string.Format("sPso.IsNullOrEmpty = {0}", string.IsNullOrEmpty(sPso)));
          }
          else
          {
            Console.WriteLine("oPso is not a string");
          }
        }
      }
    }
  }
}
{% endhighlight %}

The output is as follows:

<pre><span class="code">oStr type = System.String
oPso type = System.Management.Automation.PSObject
sStr.IsNullOrEmpty = True
oPso is not a string</span></pre>

As you can see, the string->string conversion was successful (oStr->sStr variables), while the PSObject->string conversion was not (oPso->sPso).  This results in the PSObject argument being treated as a regular object (which is not null) instead of a string, even though it is type-adapting a string object.

[610176]: http://connect.microsoft.com/PowerShell/feedback/details/610176/validatenotnullorempty-and-read-host-something-wierd
[677559]: http://connect.microsoft.com/PowerShell/feedback/details/677559/-validatenotnullorempty-behavior-not-as-expected#details
[Reflector]: http://www.reflector.net/
[as]: http://msdn.microsoft.com/en-us/library/cscsdfbt(VS.71).aspx
[adaptive]: http://blogs.msdn.com/b/powershell/archive/2006/11/24/what-s-up-with-psbase-psextended-psadapted-and-psobject.aspx