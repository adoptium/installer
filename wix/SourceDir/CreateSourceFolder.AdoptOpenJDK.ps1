Get-ChildItem -Path .\ -Filter *.zip -Recurse -File -Name| ForEach-Object {
  $filename = [System.IO.Path]::GetFileName($_)
	$jdk_version_found = $filename -match "(?<jdk>OpenJDK\d+)"
  $jdk_version = $Matches.jdk
  $package_type_found = $filename -match "(?<package_type>hotspot|openj9)"
  $package_type = $Matches.package_type
  $platform_found = $filename -match "(?<platform>x86|x64)"
  $platform = $Matches.platform
Expand-Archive -Path $filename -DestinationPath ".\$jdk_version\$package_type\$platform"
}
