;------------------------------------------------------------------------------
;  This Inno Setup script file is used to configure the installation process
;  for the specified application. It defines the setup parameters, files to be
;  installed, registry modifications, shortcuts, and other installation tasks.
;  Modify this file to customize the installer behavior and options.
;------------------------------------------------------------------------------

; Define useful variables based off inputs
#define ProductFolder ProductCategory + "-" + ExeProductVersion + "-" + JVM

#define OutputDir "output"
#define IniFile '{app}\install_tasks.ini'


; Include external files after definitions so those definitions can be used in the included files
#include "translations\default.iss"
#include "inno_scripts\install_handler.iss"
#include "inno_scripts\uninstall_handler.iss"
#include "inno_scripts\boolean_checks.iss"

[Setup]
; For more info, see https://jrsoftware.org/ishelp/index.php?topic=setupsection

;; Inno settings
SignTool=signCli
Uninstallable=yes
Compression=lzma
SolidCompression=yes
WizardStyle=modern
; Ensure correct install dirs by setting the architectures that are 64-bit
ArchitecturesInstallIn64BitMode=x64compatible arm64
; Notify Windows Explorer that the environment variables have changed
ChangesEnvironment=yes
; Debug
; SetupLogging=yes

;; App info
AppId={#AppId}
AppName={#AppName}
AppVerName={#AppName}
AppVersion={#ExeProductVersion}
AppPublisher={#Vendor}
AppPublisherURL={#AppPublisherURL}
AppSupportURL={#AppSupportURL}
AppUpdatesURL={#AppUpdatesURL}

;; Dirs and logos
OutputDir={#OutputDir}
OutputBaseFilename={#OutputFileName}
; SourceDir={#SourceDir}
; Setting default installDir based on the install mode
DefaultDirName={code:GetDefaultDir}
; Enable the user to select the installation directory every time
UsePreviousAppDir=no
UninstallFilesDir={app}\uninstall
LicenseFile={#LicenseFile}
SetupIconFile={#VendorBrandingLogo}
; Add these lines to change the banner images
WizardImageFile={#VendorBrandingDialog}
WizardSmallImageFile={#VendorBrandingSmallIcon}

;; Dialog settings
DisableDirPage=no
AlwaysShowDirOnReadyPage=yes
DirExistsWarning=auto
; Disables folder selection for start menu entry
DisableProgramGroupPage=yes
DisableWelcomePage=no
UsedUserAreasWarning=no
; Enable the user to select the installation language
ShowLanguageDialog=yes

;; Privileges settings
; Add these lines to enable installation scope selection
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog
; Enable the user to select the installation mode every time (no means that upgrades will use the same mode as the previous install)
UsePreviousPrivileges=no

[Tasks]
; For more info, see https://jrsoftware.org/ishelp/index.php?topic=taskssection
Name: "pathMod";      Description: "{cm:PathModDesc}";                          GroupDescription: "{cm:PathModTitle}";  
; AssocFileExtension is an Inno Setup provided translation provides this message into every language: &Associate %1 with the %2 file extension
Name: "jarfileMod";   Description: "{cm:AssocFileExtension,{#AppName},.jar}";   GroupDescription: "{cm:FileAssocTitle}";
Name: "javaHomeMod";  Description: "{cm:JavaHomeModDesc}";                      GroupDescription: "{cm:JavaHomeModTitle}";  Flags: unchecked;
; HKLM keys can only be created/modified in Admin Install Mode
Name: "javasoftMod";  Description: "{cm:JavaSoftModDesc,{#AppName}}";           GroupDescription: "{cm:RegKeysTitle}";      Flags: unchecked;   Check: IsAdminInstallMode;

[Files]
; For more info, see https://jrsoftware.org/ishelp/index.php?topic=filessection
; Source: "<SOURCE_FILES>\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs sortfilesbyextension sortfilesbyname
Source: "{#SourceFiles}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs sortfilesbyextension sortfilesbyname

[InstallDelete]
; For more info, see https://jrsoftware.org/ishelp/index.php?topic=installdeletesection
Type: filesandordirs; Name: "{app}"
Type: files; Name: "{app}\install_tasks.ini"

[UninstallDelete]
; For more info, see https://jrsoftware.org/ishelp/index.php?topic=uninstalldeletesection
; This section is needed since uninstall misses the install_tasks.ini file
Type: files; Name: "{app}\install_tasks.ini"

[Registry]
; For more info, see https://jrsoftware.org/ishelp/index.php?topic=registrysection
; All registry key info translated from current wix/msi installer scripts

; HKLM = HKEY_LOCAL_MACHINE
; HKA:
;   On per machine install = HKLM = HKEY_LOCAL_MACHINE
;   On per user install    = HKCU = HKEY_CURRENT_USER

; Always created
Root: HKA; Subkey: "SOFTWARE\{#Vendor}\{#ProductCategory}\"; \
    ValueType: none; \
    Flags: uninsdeletekeyifempty;
Root: HKA; Subkey: "SOFTWARE\{#Vendor}\{#ProductCategory}\{#ExeProductVersion}"; \
    ValueType: none; \
    Flags: uninsdeletekey;
Root: HKA; Subkey: "SOFTWARE\{#Vendor}\{#ProductCategory}\{#ExeProductVersion}\{#JVM}\EXE"; \
    ValueType: string; ValueName: "Path"; ValueData: "{app}"; \
    Flags: uninsdeletekey;
Root: HKA; Subkey: "SOFTWARE\{#Vendor}\{#ProductCategory}\{#ExeProductVersion}\{#JVM}\EXE"; \
    ValueType: dword;  ValueName: "Main"; ValueData: "1"; \
    Flags: uninsdeletekey;

; pathMod: Add Environment Path keys if the user requests them
Root: HKA; Subkey: "SOFTWARE\{#Vendor}\{#ProductCategory}\{#ExeProductVersion}\{#JVM}\EXE"; \
    ValueType: dword; ValueName: "EnvironmentPath"; ValueData: "1"; \
    Flags: uninsdeletekey; Check: WasTaskSelected('pathMod');
Root: HKA; Subkey: "SOFTWARE\{#Vendor}\{#ProductCategory}\{#ExeProductVersion}\{#JVM}\EXE"; \
    ValueType: dword; ValueName: "EnvironmentPathSetForSystem"; ValueData: "1"; \
    Flags: uninsdeletekey; Check: IsAdminInstallMode and WasTaskSelected('pathMod');
Root: HKA; Subkey: "SOFTWARE\{#Vendor}\{#ProductCategory}\{#ExeProductVersion}\{#JVM}\EXE"; \
    ValueType: dword; ValueName: "EnvironmentPathSetForUser";   ValueData: "1"; \
    Flags: uninsdeletekey; Check: not IsAdminInstallMode and WasTaskSelected('pathMod');

; jarfileMod: Add .jar file association keys if the user requests them
; Note: HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.jar\OpenWithProgids is 
;       automatically created by Windows when running jar file for the first time
Root: HKA; Subkey: "SOFTWARE\Classes\.jar"; \
    ValueType: string; ValueName: ""; ValueData: "{#Vendor}.jarfile"; \
    Flags: uninsdeletevalue uninsdeletekeyifempty; Check: WasTaskSelected('jarfileMod');
Root: HKA; Subkey: "SOFTWARE\Classes\.jar"; \
    ValueType: string; ValueName: "Content Type"; ValueData: "application/java-archive"; \
    Flags: uninsdeletevalue uninsdeletekeyifempty; Check: WasTaskSelected('jarfileMod');
; Creating null keys this way to make sure that they are removed as expected during uninstallation
Root: HKA; Subkey: "SOFTWARE\Classes\{#Vendor}.jarfile";            ValueType: none; Flags: uninsdeletekeyifempty; Check: WasTaskSelected('jarfileMod');
Root: HKA; Subkey: "SOFTWARE\Classes\{#Vendor}.jarfile\shell";      ValueType: none; Flags: uninsdeletekeyifempty; Check: WasTaskSelected('jarfileMod');
Root: HKA; Subkey: "SOFTWARE\Classes\{#Vendor}.jarfile\shell\open"; ValueType: none; Flags: uninsdeletekeyifempty; Check: WasTaskSelected('jarfileMod');
; Two doublequotes (") are used in the ValueName to escape the quotes properly. Example value written to key: "C:\Program Files\Adoptium\jdk-17.0.15.6-hotspot\bin\javaw.exe" -jar "%1" %*
Root: HKA; Subkey: "SOFTWARE\Classes\{#Vendor}.jarfile\shell\open\command"; \
    ValueType: string; ValueName: ""; ValueData: """{app}\bin\javaw.exe"" -jar ""%1"" %*"; \
    Flags: uninsdeletevalue uninsdeletekeyifempty; Check: WasTaskSelected('jarfileMod');
; TODO: Add HKA keys for JDK8 on x64 (if IcedTeaWeb is bundled) to process .jnlp files (similar to the .jar file handling above).
; OR: decide that EXEs will no longer support JDK8 and remove this TODO

; javaHomeMod: Add JavaHome keys if the user requests them
Root: HKA; Subkey: "SOFTWARE\{#Vendor}\{#ProductCategory}\{#ExeProductVersion}\{#JVM}\EXE"; \
    ValueType: dword; ValueName: "JavaHome"; ValueData: "1"; \
    Flags: uninsdeletekey; Check: WasTaskSelected('javaHomeMod');
Root: HKA; Subkey: "SOFTWARE\{#Vendor}\{#ProductCategory}\{#ExeProductVersion}\{#JVM}\EXE"; \
    ValueType: dword; ValueName: "JavaHomeSetForSystem"; ValueData: "1"; \
    Flags: uninsdeletekey; Check: IsAdminInstallMode and WasTaskSelected('javaHomeMod');
Root: HKA; Subkey: "SOFTWARE\{#Vendor}\{#ProductCategory}\{#ExeProductVersion}\{#JVM}\EXE"; \
    ValueType: dword; ValueName: "JavaHomeSetForUser"; ValueData: "1"; \
    Flags: uninsdeletekey; Check: not IsAdminInstallMode and WasTaskSelected('javaHomeMod');
; Add JAVA_HOME env var for system-level environment variables (admin install)
Root: HKLM; Subkey: "SYSTEM\CurrentControlSet\Control\Session Manager\Environment"; \
    ValueType: string; ValueName: "JAVA_HOME"; ValueData: "{app}"; \
    Flags: uninsdeletevalue; Check: IsAdminInstallMode and WasTaskSelected('javaHomeMod');
; Add JAVA_HOME env var for user-level environment variables (user install)
Root: HKCU; Subkey: "Environment"; \
    ValueType: string; ValueName: "JAVA_HOME"; ValueData: "{app}"; \
    Flags: uninsdeletevalue; Check: not IsAdminInstallMode and WasTaskSelected('javaHomeMod');

; javasoftMod: Add JavaSoft Keys if the user requests them
Root: HKLM; Subkey: "SOFTWARE\JavaSoft\{#ProductCategory}"; \
    ValueType: string; ValueName: "CurrentVersion"; ValueData: "{#ProductMajorVersion}"; \
    Flags: uninsdeletevalue; Check: (ShouldUpdateJavaVersion and not IsUninstaller and WasTaskSelected('javasoftMod')) or (IsUninstaller and WasTaskSelected('javasoftMod'));
Root: HKLM; Subkey: "SOFTWARE\JavaSoft\{#ProductCategory}\{#ProductMajorVersion}"; \
    ValueType: string; ValueName: "JavaHome"; ValueData: "{app}"; \
    Flags: uninsdeletevalue uninsdeletekeyifempty; Check: WasTaskSelected('javasoftMod');
Root: HKLM; Subkey: "SOFTWARE\JavaSoft\{#ProductCategory}\{#ExeProductVersion}"; \
    ValueType: string; ValueName: "JavaHome"; ValueData: "{app}"; \
    Flags: uninsdeletekey; Check: WasTaskSelected('javasoftMod');
; The RuntimeLib key is only used by JREs, not JDKs
#if ProductCategory == "JRE"
Root: HKLM; Subkey: "SOFTWARE\JavaSoft\{#ProductCategory}\{#ProductMajorVersion}"; \
    ValueType: string; ValueName: "RuntimeLib"; ValueData: "{app}\bin\server\jvm.dll"; \
    Flags: uninsdeletevalue uninsdeletekeyifempty; Check: WasTaskSelected('javasoftMod');
Root: HKLM; Subkey: "SOFTWARE\JavaSoft\{#ProductCategory}\{#ExeProductVersion}"; \
    ValueType: string; ValueName: "RuntimeLib"; ValueData: "{app}\bin\server\jvm.dll"; \
    Flags: uninsdeletekey; Check: WasTaskSelected('javasoftMod');
#endif
; TODO: Add HKLM key for JDK8 on x64 (if IcedTeaWeb is bundled) below
; OR: decide that EXEs will no longer support JDK8 and remove this TODO
; Root: HKLM; Subkey: "SOFTWARE\Classes\MIME\Database\Content Type\application/x-java-jnlp-file"; ValueType: string; ValueName: "Extension"; ValueData: ".jnlp"; Flags: uninsdeletevalue;