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
  $package_type_found = $filename -match "(?<package_type>hotspot|openj9)"
  $package_type = $Matches.package_type
  $platform_found = $filename -match "(?<platform>x86|x64)"
  $platform = $Matches.platform

  Invoke-WebRequest -Uri $url -outfile $filename
  Expand-Archive -Path $filename -DestinationPath ".\$jdk_version\$package_type\$platform"
}

