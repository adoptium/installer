[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12; 
$urls = @(
  'https://github.com/AdoptOpenJDK/openjdk11-binaries/releases/download/jdk-11%2B28/OpenJDK11-jdk_x64_windows_hotspot_11_28.zip',
  'https://github.com/AdoptOpenJDK/openjdk11-binaries/releases/download/jdk-11%2B28/OpenJDK11-jdk_x64_windows_openj9_11_28.zip',
  'https://github.com/AdoptOpenJDK/openjdk11-binaries/releases/download/jdk-11%2B28/OpenJDK11-jre_x64_windows_hotspot_11_28.zip',
  'https://github.com/AdoptOpenJDK/openjdk11-binaries/releases/download/jdk-11%2B28/OpenJDK11-jre_x64_windows_openj9_11_28.zip'
)
ForEach ($url in $urls) {
  $filename = [System.IO.Path]::GetFileName($url)

  $jdk_version_found = $filename -match "(?<jdk>OpenJDK\d+)"
  $jdk_version = $Matches.jdk
  $package_type_found = $filename -match "(?<package_type>hotspot|openj9|dragonwell)"
  $package_type = $Matches.package_type
  $platform_found = $filename -match "(?<platform>x86-32|x64)"
  $platform = $Matches.platform

  Invoke-WebRequest -Uri $url -outfile $filename
  Expand-Archive -Force -Path $filename -DestinationPath ".\$jdk_version\$package_type\$platform"
  
  Get-ChildItem -Directory ".\$jdk_version\$package_type\$platform" | Where-Object {$_ -match ".*_.*"} | ForEach-Object {
    $SourcePath = [System.IO.Path]::GetDirectoryName($_.FullName)

    if ( $_.Name -Match "(.*)_(.*)-jre$" ) {
        $NewName = $_.Name -replace "(.*)_(.*)$",'$1-jre'
    } elseif ( $_.Name -Match "(.*)_(.*)$" ) {
        $NewName = $_.Name -replace "(.*)_(.*)$",'$1'
    }
    
    $Destination = Join-Path -Path $SourcePath -ChildPath $NewName
    
    Write-Object Moving $_.FullName to $Destination
    if (Test-Path $Destination) { Remove-Item $Destination -Recurse; }
    Move-Item -Path $_.FullName -Destination $Destination -Force
  }
}
