This document describes the install packages created for each Temurin OpenJDK release and jdk / jre, the default installation locations and other pertinent information such as registry updates and post installation actions such as setting symlinks.

It is intended for use either for reference or as a specification document for developing new installers.

## openjdk8 releases
| Platform       | Variant | JDK / JRE | Type of installable | Default install location (JAVA_HOME)               | Metadata             | Other |
|----------------|---------|-----------| --------------------|----------------------------------------------------|----------------------|-------|
| Windows x64    | hotspot | jdk       | msi                 | C:\Program Files\AdoptOpenJDK\jdk-8.0.192.12       | Windows Registry key(s): HKEY_LOCAL_MACHINE\SOFTWARE\AdoptOpenJDK\JDK\8.0.192.12\MSI\Path | - |
| Windows x64    | hotspot | jre       | msi                 | C:\Program Files\AdoptOpenJDK\jre-8.0.192.12       | Windows Registry key(s): HKEY_LOCAL_MACHINE\SOFTWARE\AdoptOpenJDK\JRE\8.0.192.12\MSI\Path | - |
| Windows x32    | openj9  | jdk       | msi                 | C:\Program Files (x86)\AdoptOpenJDK\jdk-8.0.192.12 | Windows Registry key(s): HKEY_LOCAL_MACHINE\SOFTWARE\AdoptOpenJDK\JDK\8.0.192.12\MSI\Path | - |
| Windows x32    | openj9  | jre       | msi                 | C:\Program Files (x86)\AdoptOpenJDK\jre-8.0.192.12 | Windows Registry key(s): HKEY_LOCAL_MACHINE\SOFTWARE\AdoptOpenJDK\JRE\8.0.192.12\MSI\Path | - |
| Linux x64 RHEL | hotspot | jdk       | rpm                 | /usr/lib/jdk-8.0.192.12                            | ??                    | symlink /usr/bin/java |

