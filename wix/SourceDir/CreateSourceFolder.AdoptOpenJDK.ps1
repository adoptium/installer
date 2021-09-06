# Set-PSDebug -Trace 1
Write-Output "Executing CreateSourceFolder.AdoptOpenJDK"

Get-ChildItem -Path .\ -Filter *.zip -File -Name| ForEach-Object {
  
  $filename = [System.IO.Path]::GetFileName($_)
  Write-Output "Processing filename : $filename"

  # validate that the zip file is OpenJDK with an optional major version number
  $openjdk_filename_regex = "^OpenJDK(?<major>\d*)"
  $openjdk_found = $filename -match $openjdk_filename_regex
  if (!$openjdk_found) {
    Write-Output "filename : $filename doesn't match regex $openjdk_filename_regex"
    exit 2
  }

  $openjdk_basedir="OpenJDK"
  if ([string]::IsNullOrEmpty($matches.major)) {
    # put unnumbered OpenJDK filename into OpenJDK-Latest directory
    # see Build.OpenJDK_generic.cmd who's going to look at it
    $major=$openjdk_basedir + "-Latest"
  } else {
    $major=$openjdk_basedir + $Matches.major
  }

  $jvm_regex = "(?<jvm>hotspot|openj9|dragonwell)"
  $jvm_found = $filename -match $jvm_regex
  if (!$jvm_found) {
    Write-Output "filename : $filename doesn't match regex $jvm_regex"
    exit 2
  }
  $jvm = $Matches.jvm

  # Windows Architecture supported
  $platform_regex = "(?<platform>x86-32|x64|aarch64)"
  $platform_found = $filename -match $platform_regex
  if (!$platform_found) {
    Write-Output "filename : $filename doesn't match regex $platform_regex"
    exit 2
  }
  $platform = $Matches.platform

  # Wix toolset expects this to be called arm64
  if ($platform -eq "aarch64") {
    $platform="arm64"
  }

  # extract now
  $unzip_dest = ".\$major\$jvm\$platform"
  Write-Output "Extracting $filename to $unzip_dest"
  Expand-Archive -Force -Path $filename -DestinationPath $unzip_dest

  # do some cleanup in path
  Write-Output "Cleaning up $unzip_dest"

  Get-ChildItem -Directory $unzip_dest | ForEach-Object {
    $SourcePath = [System.IO.Path]::GetDirectoryName($_.FullName)
    Write-Output "SourcePath: " $SourcePath
    Write-Output "fullname: "$_.FullName
    Write-Output "Name: " $_.Name
  }

  Get-ChildItem -Directory $unzip_dest | Where-Object {$_ -match ".*_.*"} | ForEach-Object {
    $SourcePath = [System.IO.Path]::GetDirectoryName($_.FullName)
    Write-Output "SourcePath: " $SourcePath
    Write-Output "fullname: "$_.FullName
    Write-Output "Name: " $_.Name

    if ( $_.Name -Match "(.*)_(.*)-jre$" ) {
        $NewName = $_.Name -replace "(.*)_(.*)$",'$1-jre'
    } elseif ( $_.Name -Match "(.*)_(.*)$" ) {
        $NewName = $_.Name -replace "(.*)_(.*)$",'$1'
    }
    
    Write-Output "NewName: " $NewName
    $Destination = Join-Path -Path $SourcePath -ChildPath $NewName
    Write-Output "Destination: "$Destination
    
    Write-Output Moving $_.FullName to $Destination
    if (Test-Path $Destination) { Remove-Item $Destination -Recurse; }
    Move-Item -Path $_.FullName -Destination $Destination -Force
    }
}
