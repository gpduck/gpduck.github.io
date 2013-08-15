---
layout: default
title: Hacking ValidateSet
tags: [dotnet, hacking, powershell]
---
I guess I should start off this post by saying what I'm doing is a dirty hack, in no way supported, and in general a terrible idea.  But it's also really awesome.

Occasionally I find it would be nice to be able to dynamically generate the values used in a ``ValidateSet`` attribute on a function parameter.  Joel Bennett wrote a post a while back explaining how to build a [custom validation attribute](http://huddledmasses.org/better-error-messages-for-powershell-validatepattern/) that could be written to include the ability to update the set list dynamically. Or you could even use his technique of using ``ValidateScript`` and throwing a custom error message to generate the set dynamically.