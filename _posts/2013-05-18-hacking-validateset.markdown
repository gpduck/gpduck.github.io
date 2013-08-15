---
layout: default
title: Hacking ValidateSet
tags: [dotnet, hacking, powershell]
---
I guess I should start off this post by saying what I'm doing is a dirty hack, in no way supported, and in general a terrible idea.  But it's also really awesome.

Occasionally I find it would be nice to be able to dynamically generate the values used in a ``ValidateSet`` attribute on a function parameter.  Joel Bennett wrote a post a while back explaining how to build a [custom validation attribute](http://huddledmasses.org/better-error-messages-for-powershell-validatepattern/) that could be written to include the ability to update the set list dynamically. Or you could even use his technique of using ``ValidateScript`` and throwing a custom error message to generate the set dynamically.

The problem with these other techniques is that ``ValidateSet`` [comes with magic](http://blogs.msdn.com/b/powershell/archive/2006/05/10/594175.aspx") that they don't include.  This magic provides tab-completion, error messages, and a listing of valid values in help, all for free.  I actually started off my experiment by following Joel's post and implementing my own ``ValidateDynamicSetAttribute`` class that provided ``Add()`` and ``Remove()`` methods so the values could be changed on the fly.

But that class wouldn't have come with the magic of ``ValidateSet``, and while I was using ILSpy to learn how ``ValidateSet`` was implemented, I discovered that it was based on a private string array and it turns out I had just learned how to access private members while I was at the PowerShell Summit 2013 (thanks Adam!).

The result is the following function that takes a FunctionInfo object (use ``Get-Command``), the name of the parameter that is using ``ValidateSet``, and the new set of valid inputs.  It hacks its way into the command, locates the correct parameter, locates all the ``ValidateSet`` attributes on it, and rips into the heart of each one and replaces the private ``validValues`` array with the one provided in the ``-NewSet`` parameter.

{% highlight powershell %}

<#
	.SYNOPSIS
#>
{% endhighlight %}