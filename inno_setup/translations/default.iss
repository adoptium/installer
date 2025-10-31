; This file contains translations for all text in the resulting EXE installer.
; [Languages]: contains the list of languages we support. Inno Setup uses the compiler to translate default installer text.
; [CustomMessages]: contains the list of translations for the custom tasks that the user can select during installation.

[Languages]
Name: "English"; MessagesFile: "compiler:Default.isl"
Name: "German"; MessagesFile: "compiler:Languages\German.isl"
Name: "Spanish"; MessagesFile: "compiler:Languages\Spanish.isl"
Name: "French"; MessagesFile: "compiler:Languages\French.isl"
Name: "Japanese"; MessagesFile: "compiler:Languages\Japanese.isl"

#ifdef INCLUDE_UNOFFICIAL_TRANSLATIONS

; Note: ChineseTW and ChineseCN still need translations for certain progress-bar screen messages
Name: "ChineseTW"; MessagesFile: "compiler:Languages\Unofficial\ChineseTraditional.isl"
Name: "ChineseCN"; MessagesFile: "compiler:Languages\Unofficial\ChineseSimplified.isl"

#endif

[CustomMessages]
; Notes:
; 1) All translations in the initial PR were pulled directly from the wix MSI installer translation files (Jul 2025)
; 2) Any missing translations will default to English
; 3) When testing translations, the `Yes` and `No` buttons will always be in the language of the user's machine (regardless of the selected language in the installer)
; 4) All commented out translations were made by copilot and need to be verified before using/uncommenting
; 5) Translation entries allow us to have input arguments. They are specified as %1, %2, etc.

; For a list of default custom messages (Translated by Inno Setup), see: https://jrsoftware.org/ishelp/index.php?topic=custommessagessection
; Example: we are using AssocFileExtension from this list

; Custom task descriptions - English (default)
FeatureEnvironmentDesc=Modify PATH environment variable by prepending the JDK installation directory to the beginning of PATH.
FeatureJavaHomeDesc=Sets or overrides JAVA_HOME environment variable with the JDK installation directory.
JavaSoftModDesc=Overwrites Oracle's reg key HKLM\Software\JavaSoft. After uninstallation of %1, Oracle Java needs to be reinstalled to re-create these registry keys.
FeatureEnvironmentTitle=Modify PATH variable
FeatureJavaHomeTitle=Set or override JAVA_HOME variable
FeatureJarFileRunWithTitle=Associate .jar
RegKeysTitle=JavaSoft (Oracle) registry keys

German.FeatureEnvironmentDesc=In die PATH-Umgebungsvariable einfügen.
German.FeatureJavaHomeDesc=Als JAVA_HOME-Umgebungsvariable verwenden.
; German.JavaSoftModDesc=Überschreibt Oracles Registrierungsschlüssel HKLM\Software\JavaSoft. Nach der Deinstallation von %1 muss Oracle Java neu installiert werden, um diese Registrierungsschlüssel wiederherzustellen.
German.FeatureEnvironmentTitle=Zum PATH hinzufügen
German.FeatureJavaHomeTitle=JAVA_HOME-Variable konfigurieren
; German.FeatureJarFileRunWithTitle=.jar-Datei verknüpfen
; German.RegKeysTitle=JavaSoft (Oracle) Registrierungsschlüssel

Spanish.FeatureEnvironmentDesc=Añadir a la variable de entorno PATH.
Spanish.FeatureJavaHomeDesc=Establecer la variable de entorno JAVA_HOME.
Spanish.JavaSoftModDesc=Sobrescribir las claves de registro HKLM\Software\JavaSoft (Oracle). Si se desinstala %1, la ejecución de Oracle Java desde la ruta "C:\Program Files (x86)\Common Files\Oracle\Java\javapath" no funcionará. Será necesario reinstalarlo.
Spanish.FeatureEnvironmentTitle=Añadir al PATH
Spanish.FeatureJavaHomeTitle=Establecer la variable JAVA_HOME
Spanish.FeatureJarFileRunWithTitle=Asociar .jar
Spanish.RegKeysTitle=Claves de registro JavaSoft (Oracle)

French.FeatureEnvironmentDesc=Ajouter à la variable d'environnement PATH.
French.FeatureJavaHomeDesc=Définir la variable d'environnement JAVA_HOME.
French.JavaSoftModDesc=Écrase les clés de registre HKLM\Software\JavaSoft (Oracle). Après la désinstallation d'%1, Oracle Java lancé depuis le PATH "C:\Program Files (x86)\Common Files\Oracle\Java\javapath" ne fonctionne plus. Réinstaller Oracle Java si besoin
French.FeatureEnvironmentTitle=Ajouter au PATH
French.FeatureJavaHomeTitle=Définir la variable JAVA_HOME
French.FeatureJarFileRunWithTitle=Associer les .jar
French.RegKeysTitle=Clés de registre JavaSoft (Oracle)

; Japanese.FeatureEnvironmentDesc=JDKインストールディレクトリをPATHの先頭に追加してPATH環境変数を変更します。
; Japanese.FeatureJavaHomeDesc=JDKインストールディレクトリでJAVA_HOME環境変数を設定または上書きします。
; Japanese.JavaSoftModDesc=OracleのレジストリキーHKLM\Software\JavaSoftを上書きします。%1のアンインストール後、これらのレジストリキーを再作成するにはOracle Javaの再インストールが必要です。
; Japanese.FeatureEnvironmentTitle=PATH変数を変更
; Japanese.FeatureJavaHomeTitle=JAVA_HOME変数を設定または上書き
; Japanese.FeatureJarFileRunWithTitle=.jarを関連付け
; Japanese.RegKeysTitle=JavaSoft (Oracle) レジストリキー

#ifdef INCLUDE_UNOFFICIAL_TRANSLATIONS

ChineseCN.FeatureEnvironmentDesc=通过将 JDK 安装路径添加到 PATH 值开头来修改 PATH 环境变量值.
ChineseCN.FeatureJavaHomeDesc=使用 JDK 安装路径来设置或重写 JAVA_HOME 环境变量值.
; ChineseCN.JavaSoftModDesc=覆盖 Oracle 的注册表项 HKLM\Software\JavaSoft。卸载 %1 后，需要重新安装 Oracle Java 以重新创建这些注册表项。
ChineseCN.FeatureEnvironmentTitle=修改 PATH 变量值.
ChineseCN.FeatureJavaHomeTitle=设置或重写 JAVA_HOME 变量.
; ChineseCN.FeatureJarFileRunWithTitle=关联 .jar
; ChineseCN.RegKeysTitle=JavaSoft (Oracle) 注册表项

ChineseTW.FeatureEnvironmentDesc=將 JDK 安裝路徑新增至 PATH 值開頭來修改 PATH 環境變數值.
ChineseTW.FeatureJavaHomeDesc=使用 JDK 安裝路徑來設定或重寫 JAVA_HOME 環境變數值.
; ChineseTW.JavaSoftModDesc=覆寫 Oracle 的登錄機碼 HKLM\Software\JavaSoft。解除安裝 %1 後，需要重新安裝 Oracle Java 以重新建立這些登錄機碼。
ChineseTW.FeatureEnvironmentTitle=修改 PATH 變數值
ChineseTW.FeatureJavaHomeTitle=設定或重寫 JAVA_HOME 變量
; ChineseTW.FeatureJarFileRunWithTitle=關聯 .jar
; ChineseTW.RegKeysTitle=JavaSoft (Oracle) 登錄機碼

#endif