---
layout: post
title: "Issues With Configuring Powershell ExecutionPolicy via Group Policy"
tags: ["powershell"]
author: { link: "https://plus.google.com/111921112014612222144/about", name: Chris Duck }
---
When you publish an ExecutionPolicy for Powershell via Group Policy, several issues will crop up.  The first I came across is that it breaks several of the Best Practices Analyzers.  The second is that it breaks some of the [Exchange 2010 installers][kb981474].

You can reproduce this error on 2008 R2 with IIS or the File Services role installed:

1. Make sure your ExecutionPolicy is only defined locally:

    <div class="psconsole">PS> Set-ExecutionPolicy RemoteSigned -Force<br />
    PS> Get-ExecutionPolicy -List<br />
    <br />
    MachinePolicy = Undefined<br />
    UserPolicy = Undefined<br />
    Process = Undefined<br />
    CurrentUser = Undefined<br />
    LocalMachine = RemoteSigned</div>

2. Run the IIS or File Services BPA, this should be successful
3. Set the ExecutionPolicy in your Local Computer Policy:

    Open Local Policy Editor, browse to Local Computer Policy&gt; Computer Configuration&gt; Administrative Templates&gt; Windows Components&gt; Windows Powershell.  Enable "Turn on Script Execution" and set the policy to "Allow local scripts and remote signed scripts".

4. Verify that your ExecutionPolicy is now defined as a Group/Local Policy:

    <div class="psconsole">PS> Get-ExecutionPolicy -List<br />
    <br />
    MachinePolicy = RemoteSigned<br />
    UserPolicy = Undefined<br />
    Process = Undefined<br />
    CurrentUser = Undefined<br />
    LocalMachine = RemoteSigned</div>

5. Run IIS or File Services BPA, this fails with:

     <div class="psconsole">There has been a Best Practice Analyzer engine error for Model ID:'Microsoft/Windows/FileServices' during execution of the Model. (Inner Exception: One or more model documents are invalid: {0} Discovery exception occurred proccessing file '{0}'.

     Windows PowerShell updated your execution policy successfully, but the setting is overridden by a policy defined at a more specific scope.  Due ot the override, your shell will retain its current effective execution policy of "RemoteSigned".</div>

Rather than constantly have to move our Exchange servers in and out of the GPO, I decided to fix our issue by switching over to a Group Policy Preference that sets the same registry key as if you had typed ``Set-ExecutionPolicy RemoteSigned`` at the command prompt.

1. Open Group Policy Management Editor
2. Browse to Computer Configuration&gt; Preferences&gt;Windows Settings&gt; Registry
3. Right click and create a new registry item:

    * Action: ``Update``
    * Hive: ``HKEY_LOCAL_MACHINE``
    * Key Path: ``SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell``
    * Value name: ``ExecutionPolicy``
    * Value type: ``REG_SZ``
    * Value data: ``RemoteSigned``

4. Now create a second registry item that will cover 32-bit Powershell on 64-bit machines:

    * Action: ``Update``
    * Hive: ``HKEY_LOCAL_MACHINE``
    * Key Path: ``SOFTWARE\Wow6432Node\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell``
    * Value name: ``ExecutionPolicy``
    * Value type: ``REG_SZ``
    * Value data: ``RemoteSigned``
    * On the "Common" tab...<br />
    <span>
    <ol>
      <li>Check Item-level targeting</li>
      <li>Press the "Targeting" button</li>
      <li>Create a new "Environment Variable" item</li>
      <li>Name: PROCESSOR_ARCHITECTURE</li>
      <li>Value: AMD64</li>
    </ol>
    </span>

5. Verify that only the local settings are being applied and that the preference will reset the value if a user changes it:

    <div class="psconsole">PS> Set-ExecutionPolicy Undefined -Force<br />
    PS> Get-ExecutionPolicy -List<br />
    <br />
    MachinePolicy = Undefined<br />
    UserPolicy = Undefined<br />
    Process = Undefined<br />
    CurrentUser = Undefined<br />
    LocalMachine = Undefined<br />
    <br />
    PS> gpupdate /force /target:computer<br />
    PS> Get-ExecutionPolicy -List<br />
    <br />
    MachinePolicy = Undefined<br />
    UserPolicy = Undefined<br />
    Process = Undefined<br />
    CurrentUser = Undefined<br />
    LocalMachine = RemoteSigned</div>

Note that this method does require the [Group Policy Preferences Client][kb943729] to be installed on XP/Vista/2003 (it is included in Win7/2008/2008 R2) and be aware that an administrative user can easily override the ExecutionPolicy setting until Group Policy is applied again (although they could also override the Group Policy setting since they are admin, just not as easily).

[kb981474]: http://support.microsoft.com/kb/981474
[kb943729]: http://support.microsoft.com/kb/943729
