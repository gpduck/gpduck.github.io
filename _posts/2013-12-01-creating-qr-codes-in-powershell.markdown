---
layout: post
title: "Creating QR Codes in PowerShell"
tags: ["powershell","qrcode","barcode"]
author: { link: "https://plus.google.com/111921112014612222144/about", name: Chris Duck }
---
I wrote a module as a wrapper around the .Net port of Google's [ZXing library](http://zxingnet.codeplex.com/) to allow me to create QR codes in PowerShell. It hasn't been used a ton, but I figured it was finally time for me to share it with the rest of the world so I published it out on my [GitHub](http://github.com/gpduck/QrCodes).

You can download the zip file from the main page and extract it into your modules folder.  The main QR code functionality is provided by the two commands ``ConvertTo-QRCode`` and ``Format-QRCode``.  The convert function takes your input and outputs an object representing the QR code.  This object is not that useful on it's own, but when piped to ``Format-QRCode`` it will display the QR code on the screen using the box drawing characters.

![QRCode Exmple](/images/2013-12-01_QRCode.png)

The example above should scan using the [Barcode Scanner App](https://play.google.com/store/apps/details?id=com.google.zxing.client.android&hl=en) on Android and should decode to the address of this blog.

I've also included a few related functions to save barcodes as image files as well as to create a VCard string (presumably for encoding to a QR code).  These functions can be used like this:

<div class="psconsole">PS C:\&gt; New-VCard -FormattedName "Chris Duck" -Url "http://blog.whatsupduck.net"<br />
BEGIN:VCARD<br />
VERSION:4.0<br />
FN:Chris Duck<br />
URL:http://blog.whatsupduck.net<br />
END:VCARD<br />
<br />
PS C:\&gt; Out-BarcodeImage -Content (New-VCard -FormattedName "Chris Duck" -Url "http://blog.whatsupduck.net") -BarcodeFormat Qr_Code -ImageFormat PNG -Path c:\barcode.png
</div>