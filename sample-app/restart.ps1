Start-Service WAS -ErrorAction SilentlyContinue
Start-Service W3SVC -ErrorAction SilentlyContinue
& "$env:windir\System32\inetsrv\appcmd.exe" recycle apppool /apppool.name:"DefaultAppPool" | Out-Null
exit 0
