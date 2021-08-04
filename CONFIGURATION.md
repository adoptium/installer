# Configuration

This document describes the install packages created for each Eclipse Temurin release and JDK / JRE. The default installation locations and other pertinent information such as registry updates and post installation actions such as setting symlinks.

It is intended for use either for reference or as a specification document for developing new installers.

## openjdk8 releases

| Platform       | Variant | JDK / JRE | Type of installer | Default install location (JAVA_HOME)               | Metadata             | Other |
|----------------|---------|-----------| --------------------|----------------------------------------------------|----------------------|-------|
| Windows x64    | hotspot | jdk       | msi                 | C:\Program Files\Eclipse Foundation\jdk-8.0.192.12       | Windows Registry key(s): HKEY_LOCAL_MACHINE\SOFTWARE\Eclipse Foundation\JDK\8.0.192.12\MSI\Path | - |
| Windows x64    | hotspot | jre       | msi                 | C:\Program Files\Eclipse Foundation\jre-8.0.192.12       | Windows Registry key(s): HKEY_LOCAL_MACHINE\SOFTWARE\Eclipse Foundation\JRE\8.0.192.12\MSI\Path | - |
| Windows x32    | hotspot  | jdk       | msi                 | C:\Program Files (x86)\Eclipse Foundation\jdk-8.0.192.12 | Windows Registry key(s): HKEY_LOCAL_MACHINE\SOFTWARE\Eclipse Foundation\JDK\8.0.192.12\MSI\Path | - |
| Windows x32    | hotspot  | jre       | msi                 | C:\Program Files (x86)\Eclipse Foundation\jre-8.0.192.12 | Windows Registry key(s): HKEY_LOCAL_MACHINE\SOFTWARE\Eclipse Foundation\JRE\8.0.192.12\MSI\Path | - |
| Linux x64 RHEL | hotspot | jdk       | rpm                 | /usr/lib/jdk-8.0.192.12                            | ??                    | symlink /usr/bin/java |
