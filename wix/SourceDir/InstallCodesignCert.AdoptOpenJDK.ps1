If (Test-Path -Path C:\Users\jenkins\windows.p12) {
    $client = new-object System.Net.WebClient
    $client.DownloadFile("https://github.com/AdoptOpenJDK/openjdk-installer/raw/master/windows.p12", "C:\Users\jenkins\windows.p12")
}