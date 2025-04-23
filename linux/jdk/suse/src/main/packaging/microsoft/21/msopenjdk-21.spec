%global upstream_version 21.0.6+7
# Only [A-Za-z0-9.] allowed in version:
# https://docs.fedoraproject.org/en-US/packaging-guidelines/Versioning/#_upstream_uses_invalid_characters_in_the_version
# also not very intuitive:
#  $ rpmdev-vercmp 21.0.0.0.0___21.0.0.0.0+1
#  21.0.0.0.0___1 == 21.0.0.0.0+35
%global spec_version 21.0.6
%global spec_release 1
%global priority 1211

%global source_url_base https://aka.ms/download-jdk
%global java_provides openjdk

%global local_build_ %{?local_build}%{!?local_build:0}
# Above var evaluates to the value held in local_build if defined,
# else evaluates to 0 (meaning: we will build using binaries from web)

# Map architecture to the expected value in the download URL; Allow for a
# pre-defined value of vers_arch and use that if it's defined

%global vers_arch x64
%global vers_arch2 aarch64

%if "%{local_build_}" == "true"
%global src_num 4
%global sha_src_num 5
%else
%ifarch x86_64
%global src_num 0
%global sha_src_num 1
%endif
%ifarch aarch64
%global src_num 2
%global sha_src_num 3
%endif
%endif

Name:        msopenjdk-21
Version:     %{spec_version}
Release:     %{spec_release}
Summary:     Microsoft Build of OpenJDK 21

Group:       java
License:     GPLv2 with Classpath Exception
Vendor:      Microsoft
URL:         https://www.microsoft.com/openjdk
Packager:    Microsoft Package Maintainers <openjdk@microsoft.com>

AutoReqProv: no
Prefix: %{_libdir}/jvm/%{name}

ExclusiveArch: x86_64 aarch64

BuildRequires:  tar
BuildRequires:  wget

Requires: /bin/sh
Requires: /usr/sbin/alternatives
Requires: ca-certificates
Requires: dejavu-fonts
Requires: libX11-6%{?_isa}
Requires: libXext6%{?_isa}
Requires: libXi6%{?_isa}
Requires: libXrender1%{?_isa}
Requires: libXtst6%{?_isa}
Requires: libasound2%{?_isa}
Requires: glibc%{?_isa}
Requires: libz1%{?_isa}
Requires: fontconfig%{?_isa}
Requires: libfreetype6%{?_isa}

Provides: java
Provides: java-21
Provides: java-21-devel
Provides: java-21-headless
Provides: java-21-%{java_provides}
Provides: java-21-%{java_provides}-devel
Provides: java-21-%{java_provides}-headless
Provides: java-devel
Provides: java-devel-%{java_provides}
Provides: java-headless
Provides: java-%{java_provides}
Provides: java-%{java_provides}-devel
Provides: java-%{java_provides}-headless
Provides: java-sdk
Provides: java-sdk-21
Provides: java-sdk-21-%{java_provides}
Provides: java-sdk-%{java_provides}

# First architecture (x64)
Source0: %{source_url_base}/microsoft-jdk-%{spec_version}-linux-%{vers_arch}.tar.gz
Source1: %{source_url_base}/microsoft-jdk-%{spec_version}-linux-%{vers_arch}.tar.gz.sha256sum.txt

# Second architecture (aarch64)
Source2: %{source_url_base}/microsoft-jdk-%{spec_version}-linux-%{vers_arch2}.tar.gz
Source3: %{source_url_base}/microsoft-jdk-%{spec_version}-linux-%{vers_arch2}.tar.gz.sha256sum.txt

%if "%{local_build_}" == "true"
Source4: local_build_jdk1.tar.gz
Source5: local_build_jdk1.tar.gz.sha256.txt
%endif

# Avoid build failures on some distros due to missing build-id in binaries.
%global debug_package %{nil}
%global __brp_strip %{nil}

%description
Microsoft Build of OpenJDK is a development environment to create
applications and components using the programming language Java.

%prep
pushd "%{_sourcedir}"
sha256sum -c "%{expand:%{SOURCE%{sha_src_num}}}"
popd

%setup -n jdk-%{upstream_version} -T -b %{src_num}

%build
# noop

%install
mkdir -p %{buildroot}%{prefix}
cd %{buildroot}%{prefix}
tar --strip-components=1 -C "%{buildroot}%{prefix}" -xf %{expand:%{SOURCE%{src_num}}}

# Use cacerts included in OS
rm -f "%{buildroot}%{prefix}/lib/security/cacerts"
pushd "%{buildroot}%{prefix}/lib/security"
ln -s /var/lib/ca-certificates/java-cacerts "%{buildroot}%{prefix}/lib/security/cacerts"
popd

%pretrans
# noop

%post
if [ $1 -ge 1 ] ; then
    update-alternatives --install %{_bindir}/java java %{prefix}/bin/java %{priority} \
                        --slave %{_bindir}/keytool keytool %{prefix}/bin/keytool \
                        --slave %{_bindir}/rmiregistry rmiregistry %{prefix}/bin/rmiregistry \
                        --slave %{_bindir}/jexec jexec %{prefix}/lib/jexec \
                        --slave %{_bindir}/jspawnhelper jspawnhelper %{prefix}/lib/jspawnhelper \
                        --slave  %{_mandir}/man1/java.1 java.1 %{prefix}/man/man1/java.1 \
                        --slave  %{_mandir}/man1/keytool.1 keytool.1 %{prefix}/man/man1/keytool.1 \
                        --slave  %{_mandir}/man1/rmiregistry.1 rmiregistry.1 %{prefix}/man/man1/rmiregistry.1 \

    update-alternatives --install %{_bindir}/javac javac %{prefix}/bin/javac %{priority} \
                        --slave %{_bindir}/jar jar %{prefix}/bin/jar \
                        --slave %{_bindir}/jarsigner jarsigner %{prefix}/bin/jarsigner \
                        --slave %{_bindir}/javadoc javadoc %{prefix}/bin/javadoc \
                        --slave %{_bindir}/javap javap %{prefix}/bin/javap \
                        --slave %{_bindir}/jcmd jcmd %{prefix}/bin/jcmd \
                        --slave %{_bindir}/jconsole jconsole %{prefix}/bin/jconsole \
                        --slave %{_bindir}/jdb jdb %{prefix}/bin/jdb \
                        --slave %{_bindir}/jdeprscan jdeprscan %{prefix}/bin/jdeprscan \
                        --slave %{_bindir}/jdeps jdeps %{prefix}/bin/jdeps \
                        --slave %{_bindir}/jfr jfr %{prefix}/bin/jfr \
                        --slave %{_bindir}/jhsdb jhsdb %{prefix}/bin/jhsdb \
                        --slave %{_bindir}/jimage jimage %{prefix}/bin/jimage \
                        --slave %{_bindir}/jinfo jinfo %{prefix}/bin/jinfo \
                        --slave %{_bindir}/jlink jlink %{prefix}/bin/jlink \
                        --slave %{_bindir}/jmap jmap %{prefix}/bin/jmap \
                        --slave %{_bindir}/jmod jmod %{prefix}/bin/jmod \
                        --slave %{_bindir}/jpackage jpackage %{prefix}/bin/jpackage \
                        --slave %{_bindir}/jps jps %{prefix}/bin/jps \
                        --slave %{_bindir}/jrunscript jrunscript %{prefix}/bin/jrunscript \
                        --slave %{_bindir}/jshell jshell %{prefix}/bin/jshell \
                        --slave %{_bindir}/jstack jstack %{prefix}/bin/jstack \
                        --slave %{_bindir}/jstat jstat %{prefix}/bin/jstat \
                        --slave %{_bindir}/jstatd jstatd %{prefix}/bin/jstatd \
                        --slave %{_bindir}/jwebserver jwebserver %{prefix}/bin/jwebserver \
                        --slave %{_bindir}/serialver serialver %{prefix}/bin/serialver \
                        --slave  %{_mandir}/man1/jar.1 jar.1 %{prefix}/man/man1/jar.1 \
                        --slave  %{_mandir}/man1/jarsigner.1 jarsigner.1 %{prefix}/man/man1/jarsigner.1 \
                        --slave  %{_mandir}/man1/javac.1 javac.1 %{prefix}/man/man1/javac.1 \
                        --slave  %{_mandir}/man1/javadoc.1 javadoc.1 %{prefix}/man/man1/javadoc.1 \
                        --slave  %{_mandir}/man1/javap.1 javap.1 %{prefix}/man/man1/javap.1 \
                        --slave  %{_mandir}/man1/jcmd.1 jcmd.1 %{prefix}/man/man1/jcmd.1 \
                        --slave  %{_mandir}/man1/jconsole.1 jconsole.1 %{prefix}/man/man1/jconsole.1 \
                        --slave  %{_mandir}/man1/jdb.1 jdb.1 %{prefix}/man/man1/jdb.1 \
                        --slave  %{_mandir}/man1/jdeprscan.1 jdeprscan.1 %{prefix}/man/man1/jdeprscan.1 \
                        --slave  %{_mandir}/man1/jdeps.1 jdeps.1 %{prefix}/man/man1/jdeps.1 \
                        --slave  %{_mandir}/man1/jfr.1 jfr.1 %{prefix}/man/man1/jfr.1 \
                        --slave  %{_mandir}/man1/jhsdb.1 jhsdb.1 %{prefix}/man/man1/jhsdb.1 \
                        --slave  %{_mandir}/man1/jinfo.1 jinfo.1 %{prefix}/man/man1/jinfo.1 \
                        --slave  %{_mandir}/man1/jlink.1 jlink.1 %{prefix}/man/man1/jlink.1 \
                        --slave  %{_mandir}/man1/jmap.1 jmap.1 %{prefix}/man/man1/jmap.1 \
                        --slave  %{_mandir}/man1/jmod.1 jmod.1 %{prefix}/man/man1/jmod.1 \
                        --slave  %{_mandir}/man1/jpackage.1 jpackage.1 %{prefix}/man/man1/jpackage.1 \
                        --slave  %{_mandir}/man1/jps.1 jps.1 %{prefix}/man/man1/jps.1 \
                        --slave  %{_mandir}/man1/jrunscript.1 jrunscript.1 %{prefix}/man/man1/jrunscript.1 \
                        --slave  %{_mandir}/man1/jshell.1 jshell.1 %{prefix}/man/man1/jshell.1 \
                        --slave  %{_mandir}/man1/jstack.1 jstack.1 %{prefix}/man/man1/jstack.1 \
                        --slave  %{_mandir}/man1/jstat.1 jstat.1 %{prefix}/man/man1/jstat.1 \
                        --slave  %{_mandir}/man1/jstatd.1 jstatd.1 %{prefix}/man/man1/jstatd.1 \
                        --slave  %{_mandir}/man1/jwebserver.1 jwebserver.1 %{prefix}/man/man1/jwebserver.1 \
                        --slave  %{_mandir}/man1/serialver.1 serialver.1 %{prefix}/man/man1/serialver.1
fi

%preun
if [ $1 -eq 0 ]; then
    update-alternatives --remove java %{prefix}/bin/java
    update-alternatives --remove javac %{prefix}/bin/javac
fi

%files
%defattr(-,root,root)
%{prefix}

%changelog
* Thu Jan 09 2025 Microsoft Package Maintainers <openjdk@microsoft.com> 21.0.6-1
- Microsoft 21.0.6+7 initial release.