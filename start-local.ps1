param([int]$Port=8894,[switch]$NoBrowser)
$ErrorActionPreference='Stop'
$webRoot=[IO.Path]::GetFullPath($PSScriptRoot)
$listener=$null
for($candidate=$Port;$candidate -lt ($Port+20);$candidate++){
 try{$listener=[Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,$candidate);$listener.Start();$serverPort=$candidate;break}catch{$listener=$null}
}
if($null -eq $listener){throw 'SHADOWPLAY could not start a local listener.'}
$baseUrl='http://127.0.0.1:'+$serverPort
Write-Output ('SHADOWPLAY '+$baseUrl)
if(-not $NoBrowser){Start-Process $baseUrl}
$mime=@{'.html'='text/html; charset=utf-8';'.js'='text/javascript; charset=utf-8';'.css'='text/css; charset=utf-8';'.svg'='image/svg+xml';'.png'='image/png';'.wasm'='application/wasm';'.gz'='application/gzip';'.json'='application/json'}
$running=$true
try{
 while($running){
  $client=$listener.AcceptTcpClient();$client.ReceiveTimeout=3000;$client.SendTimeout=10000
  try{
   $stream=$client.GetStream();$reader=[IO.StreamReader]::new($stream,[Text.Encoding]::ASCII,$false,8192,$true)
   $first=$reader.ReadLine();if([string]::IsNullOrWhiteSpace($first)){continue}
   $parts=$first.Split(' ');if($parts.Length -lt 2){continue}
   $headers=@{};$n=0
   while($true){$line=$reader.ReadLine();if([string]::IsNullOrEmpty($line)){break};$n+=$line.Length;if($n -gt 16384){throw 'Request too large'};$pair=$line -split ':',2;if($pair.Length -eq 2){$headers[$pair[0].ToLowerInvariant()]=$pair[1].Trim()}}
   $verb=$parts[0];$target=($parts[1] -split '\?')[0];$status='200 OK';$contentType='text/plain; charset=utf-8';$body=[byte[]]@()
   if($target -eq '/__quit' -and $verb -eq 'POST'){
    if($headers.ContainsKey('origin') -and $headers['origin'] -ne $baseUrl){$status='403 Forbidden'}else{$body=[Text.Encoding]::UTF8.GetBytes('stopped');$running=$false}
   }elseif($verb -ne 'GET' -and $verb -ne 'HEAD'){$status='405 Method Not Allowed'}else{
    $rel=[Uri]::UnescapeDataString($target).TrimStart('/').Replace('/',[IO.Path]::DirectorySeparatorChar)
    if([string]::IsNullOrEmpty($rel)){$rel='index.html'}
    $file=[IO.Path]::GetFullPath([IO.Path]::Combine($webRoot,$rel))
    if(-not $file.StartsWith($webRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){$status='403 Forbidden'}elseif(-not [IO.File]::Exists($file)){$status='404 Not Found'}else{$body=[IO.File]::ReadAllBytes($file);$extension=[IO.Path]::GetExtension($file);if($mime.ContainsKey($extension)){$contentType=$mime[$extension]}else{$contentType='application/octet-stream'}}
   }
   $header="HTTP/1.1 $status`r`nContent-Type: $contentType`r`nContent-Length: $($body.Length)`r`nConnection: close`r`nCache-Control: no-cache`r`nX-Content-Type-Options: nosniff`r`n`r`n"
   $bytes=[Text.Encoding]::ASCII.GetBytes($header);$stream.Write($bytes,0,$bytes.Length)
   if($verb -ne 'HEAD' -and $body.Length -gt 0){$stream.Write($body,0,$body.Length)}
   $stream.Flush()
  }catch{if($NoBrowser){Write-Output $_.Exception.ToString()}}finally{$client.Dispose()}
 }
}finally{$listener.Stop()}
