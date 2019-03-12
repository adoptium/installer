[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12; 
$urls = @(
  'https://github.com/AdoptOpenJDK/openjdk8-binaries/releases/download/jdk8u181-b13/OpenJDK8U-jdk_x64_windows_hotspot_8u181b13.zip',
  'https://github.com/AdoptOpenJDK/openjdk8-binaries/releases/download/jdk8u181-b13/OpenJDK8U-jre_x64_windows_hotspot_8u181b13.zip',
  'https://github.com/AdoptOpenJDK/openjdk8-binaries/releases/download/jdk8u181-b13/OpenJDK8U-jdk_x86-32_windows_hotspot_8u181b13.zip',
  'https://github.com/AdoptOpenJDK/openjdk8-binaries/releases/download/jdk8u181-b13/OpenJDK8U-jre_x86-32_windows_hotspot_8u181b13.zip',
  'https://github.com/AdoptOpenJDK/openjdk8-binaries/releases/download/jdk8u192-b12/OpenJDK8U-jdk_x64_windows_openj9_8u192b12.zip'
  'https://github.com/AdoptOpenJDK/openjdk8-binaries/releases/download/jdk8u192-b12/OpenJDK8U-jre_x64_windows_openj9_8u192b12.zip',
  'https://github.com/AdoptOpenJDK/openjdk8-binaries/releases/download/jdk8u192-b12/OpenJDK8U-jdk_x86-32_windows_openj9_8u192b12.zip',
  'https://github.com/AdoptOpenJDK/openjdk8-binaries/releases/download/jdk8u192-b12/OpenJDK8U-jre_x86-32_windows_openj9_8u192b12.zip'
)
ForEach ($url in $urls) {
  $filename = [System.IO.Path]::GetFileName($url)

  $jdk_version_found = $filename -match "(?<jdk>OpenJDK\d+)"
  $jdk_version = $Matches.jdk
  $package_type_found = $filename -match "(?<package_type>hotspot|openj9)"
  $package_type = $Matches.package_type
  $platform_found = $filename -match "(?<platform>x86-32|x64)"
  $platform = $Matches.platform

  Invoke-WebRequest -Uri $url -outfile $filename
  Expand-Archive -Force -Path $filename -DestinationPath ".\$jdk_version\$package_type\$platform"
  Get-ChildItem -Directory ".\$jdk_version\$package_type\$platform" | where {$_ -match ".*_.*"} | ForEach {
    $SourcePath = [System.IO.Path]::GetDirectoryName($_.FullName)
    #echo "SourcePath: " $SourcePath
    #echo "fullname: "$_.FullName
    #echo "Name: " $_.Name
    if ( $_.Name -Match "(.*)_(.*)-jre$" ) {
        $NewName = $_.Name -replace "(.*)_(.*)$",'$1-jre'
    } elseif ( $_.Name -Match "(.*)_(.*)$" ) {
        $NewName = $_.Name -replace "(.*)_(.*)$",'$1'
    }
    
    #echo "NewName: " $NewName
    $Destination = Join-Path -Path $SourcePath -ChildPath $NewName
    #echo "Destination: "$Destination
    
    echo Moving $_.FullName to $Destination
    if (Test-Path $Destination) { Remove-Item $Destination -Recurse; }
    Move-Item -Path $_.FullName -Destination $Destination -Force
    }
}
