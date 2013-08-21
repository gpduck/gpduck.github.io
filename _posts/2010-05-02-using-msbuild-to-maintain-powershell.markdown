---
layout: post
title: "Using MSBuild to Maintain Powershell Modules"
tags: ["msbuild","powershell","source control"]
author: { link: "https://plus.google.com/111921112014612222144/about", name: Chris Duck }
---
###The Problem###

One of the challenges faced when developing scripts that will be used from other scripts is keeping the library script updated. Frequently the file is copied from the folder it was developed in to the folders containing the scripts that depend on it. This is a good way to make sure that the dependency follows the main script if it is moved, but creates multiple copies of the library script that are unlikely to be updated if a bug is fixed or an improvement made.

###The Goal###

Ideally, there would be a way to link the library script to the dependent scripts, without actually having to keep a copy of it in the folder. This would allow a single place to update all of the scripts and still maintain the dependencies with the main scripts.

###The Solution - MSBuild###

This solution will establish a workspace where all development of scripts occurs and then use MSBuild (included in the .NET framework) to deploy the scripts to a release folder. The build process will copy all of the dependencies of the scripts into their local folders so the folder can then be moved to another computer and all of the dependencies will be packaged together.

This also works well if there is a source control system maintaining the master copy of all the scripts. The workspace can be set as the base folder for the source control system and then only a single copy of each file is included in source control.

###Environment and Directory Layout###

The easiest way to run a build is to add ``msbuild.exe`` to the PATH environment variable and call it from a folder containing a ``.proj`` file. This will invoke the default target in the ``.proj`` file and doesn't require any parameters to be passed to msbuild. ``Msbuild.exe`` is included in the v2.0.50727 and v3.5 framework folders, usually located at ``C:\windows\Microsoft.NET\Framework``. Here is a batch file that can be run easily from explorer to run a build in its current folder:

{% highlight bat %}
@echo off</span><br />
set path=%path%;c:\windows\Microsoft.Net\Framework\v3.5;<br />
msbuild<br />
pause
{% endhighlight %}

Here is some powershell that will locate the path for .NET 3.5 for you:

<div class="psconsole">PS> get-itemproperty "HKLM:\Software\Microsoft\NET Framework Setup\NDP\v3.5").InstallPath</div>

The variable ``$ws`` will be used to represent the workspace throughout this post. This is where the master copy of the scripts are kept (if using a source control system, this would be where files are checked out to). As an example, it could be set as follows:

<div class="psconsole">PS> $ws = c:\users\cduck\documents\scripts</div>

The following folder structure is used within the workspace:

* **$ws\Release**

    This will be the default output folder and is excluded from source control. This folder is designed to be copied to c:\scripts and to have ``c:\scripts\modules`` added to your ``$env:PSModulePath``. It will be automatically created by the MSBuild target.
* **$ws\ThirdPartyLibs**

    This is for 3rd party libraries, like binaries or .NET assemblies and is under source control. There will be a separate folder under here for each library that will be linked to from scripts and modules.
* **$ws\src**

    This is where working copies of scripts and modules are saved and is under source control.

* **$ws\src\Module**

    Each module gets a new folder under ``$ws\src\Modules\&lt;modulename&gt;``

* **$ws\src\Scripts**

    Single scripts can go in this root, or collections of scripts can be put in sub-folders here.

###Configure the Main MSBuild Project File###

The main build process is controlled by a MSBuild project file in the workspace root, ``$ws\msbuild.proj``. This file is configured to search the ``$ws\src\Modules\*`` folders and ``$ws\src\Scripts\*`` folders for any ``msbuild.proj`` files (recursing only one folder deep) and run the default target for each of those files. It also overrides the ``OutputDirectory`` property of each of these build files to force the build output to ``$ws\Release\Modules`` for modules or ``$ws\`` for scripts.

The contents of ``$ws\msbuild.proj`` are:

{% highlight xml %}
<Project DefaultTargets="Build" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <PropertyGroup>
    <OutputDirectory>$(MSBuildProjectDirectory)\Release</OutputDirectory>
    <ModuleOutputDirectory>$(OutputDirectory)\Modules</ModuleOutputDirectory>
    <ScriptOutputDirectory>$(OutputDirectory)</ScriptOutputDirectory>
  </PropertyGroup>

  <ItemGroup>
    <ModuleBuilds Include="src\Modules\*\msbuild.proj" />
    <ScriptBuilds Include="src\Scripts\*\msbuild.proj" />
    <ScriptFiles Include="src\Scripts\**\*.*" />
  </ItemGroup>

  <Target Name="ModuleBuild">
    <MSBuild
      Projects="@(ModuleBuilds)"
      Properties="OutputDirectory=$(ModuleOutputDirectory)"
    />
  </Target>

  <Target Name="ScriptBuild">
    <Copy
      SourceFiles="@(ScriptFiles)"
      DestinationFiles="@(ScriptFiles->'$(ScriptOutputDirectory)\%(RecursiveDir)%(Filename)%(Extension)')"
    />
    <MSBuild
      Projects="@(ScriptBuilds)"
      Properties="OutputDirectory=$(ScriptOutputDirectory)\%(RecursiveDir)"
    />
  </Target>

  <Target Name="Build">
    <CallTarget Targets="ModuleBuild;ScriptBuild" />
  </Target>

  <Target Name="Clean">
    <RemoveDir
      Directories="$(OutputDirectory)"
    />
  </Target>
</Project>
{% endhighlight %}

This file can be invoked by calling ``msbuild.exe`` with your current directory set to your workspace (``$ws``), or by creating a file ``$ws\build.cmd`` with the contents from above in it and double clicking on it.

This build file defines a base output directory as "a folder called 'Release' that is a sub-folder of the parent folder of the build file" and saves it in the ``OutputDirectory`` parameter. This can be overridden on the command line using ``msbuild.exe /p:OutputDirectory=c:\scripts``. It also defines the parameters 'ModuleOutputDirectory' as a 'Modules' sub-folder of the main output directory and 'ScriptOutputDirectory' as the same folder as the main output directory.

This source folder structure:

<blockquote>
<span class="code">$ws\src\Scripts\script1.ps1</span><br />
<span class="code">$ws\src\Scripts\Nested\nestedScript1.ps1</span><br />
<span class="code">$ws\src\Modules\Module1\Module1.psm1</span>
</blockquote>

Will be output as follows:

<blockquote>
<span class="code">$ws\Release\script1.ps1</span><br />
<span class="code">$ws\Release\Nested\nestedScript1.ps1</span><br />
<span class="code">$ws\Release\Modules\Module1\Module1.psm1</span>
</blockquote>

As you can see, this allows the contents of ``$ws\Release`` to be directly copied to ``c:\scripts``, or you can use the command line parameter above to set the output to ``c:\scripts`` directly.

###Including a Custom MSBuild Project for a Module or Script Folder###

The whole point of this exercise is to allow a script or third party assembly/executable to be included in a module or script folder without having to create multiple copies of it in the source control system, but so far all we have is a way to recreate the directory structure of the ``$ws\src\scripts`` folder. The magic of using MSBuild to accomplish this is in chaining project definitions contained in each module or script sub-folder to the main build definition.

To add ``pscp.exe`` from ``$ws\ThirdPartyLibs\PuTTY`` to the scripts contained in ``$ws\src\Scripts\Linux``, create the following ``msbuild.proj`` in ``$ws\src\Scripts\Linux``:

{% highlight xml %}
<Project DefaultTargets="Build" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <ItemGroup>
    <tplibs Include="..\..\..\ThirdPartyLibs\PuTTY\pscp.exe" />
  </ItemGroup>

  <Target Name="Build">
    <Copy
      SourceFiles="@(tplibs)"
      DestinationFolder="$(OutputDirectory)"
    />
  </Target>
</Project>
{% endhighlight %}

Since the entire contents of ``$ws\src\Scripts`` will be copied to the output folder by the main ``msbuild.proj`` file (``$ws\msbuild.proj``), all that is needed in the ``$ws\src\Scripts\Linux\msbuild.proj`` file is any dependency that needs to be added from outside of this folder. This could even include scripts from other folders if you have some utility scripts that are used by other scripts. If there are no outside dependencies, a ``msbuild.proj`` file does not need to be created.

Here is another example that copies ``$ws\src\Scripts\new-share.ps1`` and ``$ws\src\Scripts\DNS\set-cname.ps1`` to ``$ws\src\Scripts\IIS`` so that a script located there (maybe ``new-iissite.ps1``) can use them to create a share and add a new CNAME record to DNS for the site:

{% highlight xml %}
<Project DefaultTargets="Build" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <ItemGroup>
    <tplibs Include="..\new-share.ps1;..\DNS\set-cname.ps1" />
  </ItemGroup>

  <Target Name="Build">
    <Copy
      SourceFiles="@(tplibs)"
      DestinationFolder="$(OutputDirectory)"
    />
  </Target>
</Project>
{% endhighlight %}

Now there is only one copy of ``new-share.ps1`` and ``set-cname.ps1`` in the source control system, but they are copied to the ``IIS`` folder to fulfill dependencies for the ``new-iissite.ps1`` file in that folder.

Modules will use a similar technique, but the msbuild.proj files have been crafted slightly differently to allow a module to be built independently. The script version of the msbuild.proj file could be modified to work like modules or vice-versa if so desired.

Here is the contents of ``$ws\src\Modules\Linux\msbuild.proj`` that will be used to copy the module and add ``$ws\ThirdPartyLibs\PuTTY\pscp.exe`` to this module:

{% highlight xml %}
<Project DefaultTargets="Build" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <PropertyGroup>
    <ModuleName>Linux</ModuleName>
    <OutputDirectory>..\..\..\Release\Modules</OutputDirectory>
  </PropertyGroup>

  <ItemGroup>
    <tplibs Include="..\..\..\ThirdPartyLibraries\PuTTY\pscp.exe" />
    <ModuleFiles Include="**\*.*" Exclude="**\msbuild.proj" />
  </ItemGroup>

  <Target Name="Build">
    <Copy
      SourceFiles="@(tplibs)"
      DestinationFolder="$(OutputDirectory)\$(ModuleName)"
    />
    <Copy
      SourceFiles="@(ModuleFiles)"
      DestinationFolder="$(ModuleFiles->'$(OutputDirectory)\$(ModuleName)\%(RecursiveDir)%(Filename)%(Extension)')"
    />
  </Target>

  <Target Name="Clean">
    <RemoveDir
      Directories="$(OutputDirectory)\$(ModuleName)"
    />
  </Target>
</Project>
{% endhighlight %}

Placing the recursive file copy task in the module's ``msbuild.proj`` file and including a default ``OutputDirectory`` property allows the module to be built alone. The ``msbuild.proj`` file that was used in a script folder above only copied dependencies. The module version could be used in a script folder, allowing that script folder to be built on its own, but then the full build process would be doing double file copies.

###Summary###

This post shows two examples of how to configure a simple MSBuild project to enable a single master copy of scripts to be maintained and then meshed together to build folders with local copies of any dependencies for each script. MSBuild is a very robust build system and these examples can be extended to do much more.

###Additional Resources###

The following links were helpful to me in learning the necessary MSBuild syntax to write these build scripts.

1. [MSBuild Command Line Reference](http://msdn.microsoft.com/en-us/library/ms164311.aspx)
2. [MSBuild Project File Schema Reference](<http://msdn.microsoft.com/en-us/library/5dy88c2e(VS.90).aspx>)
3. [MSBuild Task Reference](<http://msdn.microsoft.com/en-us/library/7z253716(VS.90).aspx>)
4. [MSBuild Reserved Properties Reference](<http://msdn.microsoft.com/en-us/library/ms164309(VS.90).aspx>)
5. [MSBuild Basics Tutorial](http://brennan.offwhite.net/blog/2006/11/29/msbuild-basics-1of7/)