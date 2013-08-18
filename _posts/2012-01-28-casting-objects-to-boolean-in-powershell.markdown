---
layout: post
title: "Casting Objects to Boolean in Powershell"
tags: [powershell]
author: { link: "https://plus.google.com/111921112014612222144/about", name: Chris Duck }
---
A question came up on the Powershell technet forum asking why an empty [System.DirectoryServices.SearchResultCollection][collection] was evaluating to ``$true``.  The original post is [HERE][question], but the gist of the question is this:

> Why does an empty [System.DirectoryServices.SearchResultCollection][collection] object evaluate to ``$true`` when used in an if statement (ie if($SearchResult)), but an empty [System.Array][array] and [System.Collections.ArrayList][arraylist] both evaulate to ``$false``?

I was aware that Powershell has some special rules for casting objects, but a search for exactly what those rule are only returned very generic terms for how collections were handled (ie [this blog post][cookbook] and [this book][googlebook]).  Nothing specified exactly which types/interfaces were expanded as collections and which were not.

So I did a little digging and came up with the following...

The reason a [SearchResultCollection][collection] evaluates to true even when it is empty is because it does not implement the [IList][] interface:</p>

<div class="poshconsole">PS&gt; [System.DirectoryServices.SearchResultCollection].GetInterfaces()<br />
<br />
IsPublic IsSerial Name<br />
-------- -------- ----<br />
True     False    ICollection<br />
True     False    IEnumerable<br />
True     False    IDisposable<br />
<br />
PS&gt; [System.Array].GetInterfaces()<br />
<br />
IsPublic IsSerial Name<br />
-------- -------- ----<br />
True     False    ICloneable<br />
True     False    IList<br />
True     False    ICollection<br />
True     False    IEnumerable<br />
<br />
PS&gt; [System.Collections.ArrayList].GetInterfaces()<br />
<br />
IsPublic IsSerial Name<br />
-------- -------- ----<br />
True     False    IList<br />
True     False    ICollection<br />
True     False    IEnumerable<br />
True     False    ICloneable<br />
</div>

As you can see, both [System.Array][array] and [System.Collections.ArrayList][arraylist] implement [IList][]. This is apparently what Powershell uses to determine if it should "look inside" when it converts the object to a boolean.

You can see (what I think is) the proof of this if you load up [Reflector][] ([dotPeek][], [ILSpy][], and [JustDecompile][] are free alternatives):

1. Open System.Management.Automation from the GAC
2. Expand the System.Management.Automation namespace
3. Browse down to LanguagePrimitives
4. Browse down to the IsTrue(object obj) method and decompile it

In there you can see the algorithm (which I am assuming is being used in this case) that converts objects to boolean. The basic logic is:

1. If it is null, return ``$false``.
2. If it is a boolean, return the boolean.
3. If it is a string, return ``$false`` if it is empty, else return ``$true``.
4. If it is a number, return ``$false`` if it is ``0``, else return ``$true``.
5. If it is a SwitchParameter, call its own ``ToBool()`` method.
6. Convert it to an IList:
  1. If this conversion fails, return ``$true`` (meaning it was an object that was not null, not any of the "special" things above, and not a list for PS to count).
  2. If it is a list and has ``0`` elements, return ``$false``.
  3. If it is a list and has ``1`` element, return the ``IsTrue(list[0])`` value (ie recurse on the one element and return its value.
  4. If it is a list with more than ``1`` thing in it, return ``$true``.

As you can see, the [Array][] and [ArrayList][] fall into rules 6.2-6.4 because they implement [IList][], whereas the [SearchResultCollection][collection] falls into rule 6.1 because it does not implement [IList][] so the conversion to a list fails, which means it was a plain old non-null object which evaluates to ``$true`` in Powershell.

[collection]: http://msdn.microsoft.com/en-us/library/system.directoryservices.searchresultcollection.aspx
[question]: http://social.technet.microsoft.com/Forums/en-US/winserverpowershell/thread/44128f6f-3263-4263-a9cb-f855d84ee5b7#4bed26db-b865-45ec-afce-2c0c40c661b4
[array]: http://msdn.microsoft.com/en-us/library/system.array.aspx
[arraylist]: http://msdn.microsoft.com/en-us/library/system.collections.arraylist.aspx
[cookbook]: http://www.pavleck.net/powershell-cookbook/apa.html#booleans
[googlebook]: http://books.google.com/books?id=wVYl6UKeb4wC&pg=PA41&lpg=PA41&dq=powershell+rules+for+cast+to+bool&source=bl&ots=lOt-HD8Adv&sig=WO-GvpUuRdGXFkg8RO52pIvZYxc&hl=en&sa=X&ei=MjckT6rOHabMsQLU5vGMAg&ved=0CGoQ6AEwCQ#v=onepage&q=powershell%20rules%20for%20cast%20to%20bool&f=false
[ilist]: http://msdn.microsoft.com/en-us/library/system.collections.ilist.aspx
[reflector]: http://www.reflector.net/
[dotpeek]: http://www.jetbrains.com/decompiler/
[ilspy]: http://wiki.sharpdevelop.net/ilspy.ashx
[justdecompile]: http://www.telerik.com/products/decompiler.aspx