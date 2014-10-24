---
layout: post
title: "Checking SSL and TLS Versions With PowerShell"
tags: ["powershell","ssl","tls","security"]
author: { link: "https://plus.google.com/111921112014612222144/about", name: Chris Duck }
---
With all the SSL vulnerabilities that have come out recently, we've decided to disable some of the older protocols at work so we don't have to worry about them. After getting our group policies setup the way we wanted, we needed a way to validate that the protocols we wanted to disable were actually disabled on our servers.

Here is the script that I came up with, it tries to create an SslStream to the server using all the protocols defined in [System.Security.Authentication.SslProtocols](http://msdn.microsoft.com/en-us/library/system.security.authentication.sslprotocols(v=vs.110).aspx) and outputs which were successful.

{% highlight powershell linenos %}
<#
.DESCRIPTION
  Outputs the SSL protocols that the client is able to successfully use to connect to a server.

.NOTES

  Copyright 2014 Chris Duck
  http://blog.whatsupduck.net

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

.PARAMETER ComputerName
  The name of the remote computer to connect to.

.PARAMETER Port
  The remote port to connect to. The default is 443.

.EXAMPLE
  Test-SslProtocols -ComputerName "www.google.com"
  
  ComputerName       : www.google.com
  Port               : 443
  KeyLength          : 2048
  SignatureAlgorithm : rsa-sha1
  Ssl2               : False
  Ssl3               : True
  Tls                : True
  Tls11              : True
  Tls12              : True
#>
function Test-SslProtocols {
  param(
    [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true)]
    $ComputerName,
    
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [int]$Port = 443
  )
  begin {
    $ProtocolNames = [System.Security.Authentication.SslProtocols] | gm -static -MemberType Property | ?{$_.Name -notin @("Default","None")} | %{$_.Name}
  }
  process {
    $ProtocolStatus = [Ordered]@{}
    $ProtocolStatus.Add("ComputerName", $ComputerName)
    $ProtocolStatus.Add("Port", $Port)
    $ProtocolStatus.Add("KeyLength", $null)
    $ProtocolStatus.Add("SignatureAlgorithm", $null)
    
    $ProtocolNames | %{
      $ProtocolName = $_
      $Socket = New-Object System.Net.Sockets.Socket([System.Net.Sockets.SocketType]::Stream, [System.Net.Sockets.ProtocolType]::Tcp)
      $Socket.Connect($ComputerName, $Port)
      try {
        $NetStream = New-Object System.Net.Sockets.NetworkStream($Socket, $true)
        $SslStream = New-Object System.Net.Security.SslStream($NetStream, $true)
        $SslStream.AuthenticateAsClient($ComputerName,  $null, $ProtocolName, $false )
        $RemoteCertificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]$SslStream.RemoteCertificate
        $ProtocolStatus["KeyLength"] = $RemoteCertificate.PublicKey.Key.KeySize
        $ProtocolStatus["SignatureAlgorithm"] = $RemoteCertificate.PublicKey.Key.SignatureAlgorithm.Split("#")[1]
        $ProtocolStatus.Add($ProtocolName, $true)
      } catch  {
        $ProtocolStatus.Add($ProtocolName, $false)
      } finally {
        $SslStream.Close()
      }
    }
    [PSCustomObject]$ProtocolStatus
  }
}
{% endhighlight %}