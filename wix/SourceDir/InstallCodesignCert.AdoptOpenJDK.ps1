If (Test-Path -Path C:\Users\jenkins\windows.p12) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    wget 'https://github.com/AdoptOpenJDK/openjdk-installer/raw/master/windows.p12' -o 'C:\Users\jenkins\windows.p12'
}