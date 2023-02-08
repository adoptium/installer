%global upstream_version 17.0.6+10
# Only [A-Za-z0-9.] allowed in version:
# https://docs.fedoraproject.org/en-US/packaging-guidelines/Versioning/#_upstream_uses_invalid_characters_in_the_version
# also not very intuitive:
#  $ rpmdev-vercmp 17.0.1.0.1___17.0.1.0+12
#  17.0.1.0.0___12 == 17.0.1.0.0+12
%global spec_version 17.0.6.0.0.10
%global spec_release 2
%global priority 1711

%global source_url_base https://github.com/adoptium/temurin17-binaries/releases/download
%global upstream_version_url %(echo %{upstream_version} | sed 's/\+/%%2B/g')
%global upstream_version_no_plus %(echo %{upstream_version} | sed 's/\+/_/g')
%global java_provides openjdk

# Map architecture to the expected value in the download URL; Allow for a
# pre-defined value of vers_arch and use that if it's defined

%ifarch x86_64
%global vers_arch x64
%global vers_arch2 ppc64le
%global vers_arch3 s390x
%global vers_arch4 aarch64
%global vers_arch5 arm
%global src_num 0
%global sha_src_num 1
%endif
%ifarch ppc64le
%global vers_arch x64
%global vers_arch2 ppc64le
%global vers_arch3 s390x
%global vers_arch4 aarch64
%global vers_arch5 arm
%global src_num 2
%global sha_src_num 3
%endif
%ifarch s390x
%global vers_arch x64
%global vers_arch2 ppc64le
%global vers_arch3 s390x
%global vers_arch4 aarch64
%global vers_arch5 arm
%global src_num 4
%global sha_src_num 5
%endif
%ifarch aarch64
%global vers_arch x64
%global vers_arch2 ppc64le
%global vers_arch3 s390x
%global vers_arch4 aarch64
%global vers_arch5 arm
%global src_num 6
%global sha_src_num 7
%endif
%ifarch %{arm}
%global vers_arch x64
%global vers_arch2 ppc64le
%global vers_arch3 s390x
%global vers_arch4 aarch64
%global vers_arch5 arm
%global src_num 8
%global sha_src_num 9
%endif
# Allow for noarch SRPM build
%ifarch noarch
%global src_num 0
%global sha_src_num 1
%endif

Name:        temurin-17-jdk
Version:     %{spec_version}
Release:     %{spec_release}
Summary:     Eclipse Temurin 17 JDK

Group:       java
License:     GPLv2 with exceptions
Vendor:      Eclipse Adoptium
URL:         https://projects.eclipse.org/projects/adoptium
Packager:    Eclipse Adoptium Package Maintainers <temurin-dev@eclipse.org>

AutoReqProv: no
Prefix: /usr/lib/jvm/%{name}

BuildRequires:  tar
BuildRequires:  wget

Requires: /bin/sh
Requires: /usr/sbin/alternatives
Requires: ca-certificates
Requires: dejavu-sans-fonts
Requires: libX11%{?_isa}
Requires: libXext%{?_isa}
Requires: libXi%{?_isa}
Requires: libXrender%{?_isa}
Requires: libXtst%{?_isa}
Requires: alsa-lib%{?_isa}
Requires: glibc%{?_isa}
Requires: zlib%{?_isa}
Requires: fontconfig%{?_isa}
Requires: freetype%{?_isa}

Provides: java
Provides: java-17
Provides: java-17-devel
Provides: java-17-headless
Provides: java-17-%{java_provides}
Provides: java-17-%{java_provides}-devel
Provides: java-17-%{java_provides}-headless
Provides: java-devel
Provides: java-devel-%{java_provides}
Provides: java-headless
Provides: java-%{java_provides}
Provides: java-%{java_provides}-devel
Provides: java-%{java_provides}-headless
Provides: java-sdk
Provides: java-sdk-17
Provides: java-sdk-17-%{java_provides}
Provides: java-sdk-%{java_provides}
Provides: jre
Provides: jre-17
Provides: jre-17-headless
Provides: jre-17-%{java_provides}
Provides: jre-17-%{java_provides}-headless
Provides: jre-headless
Provides: jre-%{java_provides}
Provides: jre-%{java_provides}-headless

# First architecture (x86_64)
Source0: %{source_url_base}/jdk-%{upstream_version_url}/OpenJDK17U-jdk_%{vers_arch}_linux_hotspot_%{upstream_version_no_plus}.tar.gz
Source1: %{source_url_base}/jdk-%{upstream_version_url}/OpenJDK17U-jdk_%{vers_arch}_linux_hotspot_%{upstream_version_no_plus}.tar.gz.sha256.txt
# Second architecture (ppc64le)
Source2: %{source_url_base}/jdk-%{upstream_version_url}/OpenJDK17U-jdk_%{vers_arch2}_linux_hotspot_%{upstream_version_no_plus}.tar.gz
Source3: %{source_url_base}/jdk-%{upstream_version_url}/OpenJDK17U-jdk_%{vers_arch2}_linux_hotspot_%{upstream_version_no_plus}.tar.gz.sha256.txt
# Third architecture (s390x)
Source4: %{source_url_base}/jdk-%{upstream_version_url}/OpenJDK17U-jdk_%{vers_arch3}_linux_hotspot_%{upstream_version_no_plus}.tar.gz
Source5: %{source_url_base}/jdk-%{upstream_version_url}/OpenJDK17U-jdk_%{vers_arch3}_linux_hotspot_%{upstream_version_no_plus}.tar.gz.sha256.txt
# Fourth architecture (aarch64)
Source6: %{source_url_base}/jdk-%{upstream_version_url}/OpenJDK17U-jdk_%{vers_arch4}_linux_hotspot_%{upstream_version_no_plus}.tar.gz
Source7: %{source_url_base}/jdk-%{upstream_version_url}/OpenJDK17U-jdk_%{vers_arch4}_linux_hotspot_%{upstream_version_no_plus}.tar.gz.sha256.txt
# Fifth architecture (arm32)
Source8: %{source_url_base}/jdk-%{upstream_version_url}/OpenJDK17U-jdk_%{vers_arch5}_linux_hotspot_%{upstream_version_no_plus}.tar.gz
Source9: %{source_url_base}/jdk-%{upstream_version_url}/OpenJDK17U-jdk_%{vers_arch5}_linux_hotspot_%{upstream_version_no_plus}.tar.gz.sha256.txt

# Set the compression format to xz to be compatible with more Red Hat flavours. Newer versions of Fedora use zstd which
# is not available on CentOS 7, for example. https://github.com/rpm-software-management/rpm/blob/master/macros.in#L353
# lists the available options.
%define _source_payload w7.xzdio
%define _binary_payload w7.xzdio

# Avoid build failures on some distros due to missing build-id in binaries.
%global debug_package %{nil}
%global __brp_strip %{nil}

%description
Eclipse Temurin JDK is an OpenJDK-based development environment to create
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

# Strip bundled Freetype and use OS package instead.
rm -f "%{buildroot}%{prefix}/lib/libfreetype.so"

# Use cacerts included in OS
rm -f "%{buildroot}%{prefix}/lib/security/cacerts"
pushd "%{buildroot}%{prefix}/lib/security"
ln -s /etc/pki/java/cacerts "%{buildroot}%{prefix}/lib/security/cacerts"
popd

# Ensure systemd-tmpfiles-clean does not remove pid files
# https://bugzilla.redhat.com/show_bug.cgi?id=1704608
%{__mkdir} -p %{buildroot}/usr/lib/tmpfiles.d
echo 'x /tmp/hsperfdata_*' > "%{buildroot}/usr/lib/tmpfiles.d/%{name}.conf"
echo 'x /tmp/.java_pid*' >> "%{buildroot}/usr/lib/tmpfiles.d/%{name}.conf"

%post
if [ $1 -ge 1 ] ; then
    update-alternatives --install %{_bindir}/java java %{prefix}/bin/java %{priority} \
                        --slave %{_bindir}/jfr jfr %{prefix}/bin/jfr \
                        --slave %{_bindir}/jrunscript jrunscript %{prefix}/bin/jrunscript \
                        --slave %{_bindir}/keytool keytool %{prefix}/bin/keytool \
                        --slave %{_bindir}/rmiregistry rmiregistry %{prefix}/bin/rmiregistry \
                        --slave %{_bindir}/jexec jexec %{prefix}/lib/jexec \
                        --slave %{_bindir}/jspawnhelper jspawnhelper %{prefix}/lib/jspawnhelper \
                        --slave  %{_mandir}/man1/java.1 java.1 %{prefix}/man/man1/java.1 \
                        --slave  %{_mandir}/man1/jfr.1 jfr.1 %{prefix}/man/man1/jfr.1 \
                        --slave  %{_mandir}/man1/jrunscript.1 jrunscript.1 %{prefix}/man/man1/jrunscript.1 \
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
                        --slave %{_bindir}/jhsdb jhsdb %{prefix}/bin/jhsdb \
                        --slave %{_bindir}/jimage jimage %{prefix}/bin/jimage \
                        --slave %{_bindir}/jinfo jinfo %{prefix}/bin/jinfo \
                        --slave %{_bindir}/jlink jlink %{prefix}/bin/jlink \
                        --slave %{_bindir}/jmap jmap %{prefix}/bin/jmap \
                        --slave %{_bindir}/jmod jmod %{prefix}/bin/jmod \
                        --slave %{_bindir}/jpackage jpackage %{prefix}/bin/jpackage \
                        --slave %{_bindir}/jps jps %{prefix}/bin/jps \
                        --slave %{_bindir}/jshell jshell %{prefix}/bin/jshell \
                        --slave %{_bindir}/jstack jstack %{prefix}/bin/jstack \
                        --slave %{_bindir}/jstat jstat %{prefix}/bin/jstat \
                        --slave %{_bindir}/jstatd jstatd %{prefix}/bin/jstatd \
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
                        --slave  %{_mandir}/man1/jhsdb.1 jhsdb.1 %{prefix}/man/man1/jhsdb.1 \
                        --slave  %{_mandir}/man1/jinfo.1 jinfo.1 %{prefix}/man/man1/jinfo.1 \
                        --slave  %{_mandir}/man1/jlink.1 jlink.1 %{prefix}/man/man1/jlink.1 \
                        --slave  %{_mandir}/man1/jmap.1 jmap.1 %{prefix}/man/man1/jmap.1 \
                        --slave  %{_mandir}/man1/jmod.1 jmod.1 %{prefix}/man/man1/jmod.1 \
                        --slave  %{_mandir}/man1/jpackage.1 jpackage.1 %{prefix}/man/man1/jpackage.1 \
                        --slave  %{_mandir}/man1/jps.1 jps.1 %{prefix}/man/man1/jps.1 \
                        --slave  %{_mandir}/man1/jshell.1 jshell.1 %{prefix}/man/man1/jshell.1 \
                        --slave  %{_mandir}/man1/jstack.1 jstack.1 %{prefix}/man/man1/jstack.1 \
                        --slave  %{_mandir}/man1/jstat.1 jstat.1 %{prefix}/man/man1/jstat.1 \
                        --slave  %{_mandir}/man1/jstatd.1 jstatd.1 %{prefix}/man/man1/jstatd.1 \
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
/usr/lib/tmpfiles.d/%{name}.conf

%changelog
* Wed Jan 18 2023 Eclipse Adoptium Package Maintainers <temurin-dev@eclipse.org> 17.0.6.0.0.10.adopt0
- Eclipse Temurin 17.0.6+10 release.
* Thu Oct 25 2022 Eclipse Adoptium Package Maintainers <temurin-dev@eclipse.org> 17.0.5.0.0.8.adopt0
- Eclipse Temurin 17.0.5+8 release.
* Tue Aug 23 2022 Eclipse Adoptium Package Maintainers <temurin-dev@eclipse.org> 17.0.4.1.0.1.adopt0
- Eclipse Temurin 17.0.4.1+8 release.
* Wed Jul 27 2022 Eclipse Adoptium Package Maintainers <temurin-dev@eclipse.org> 17.0.4.0.0.8.adopt0
- Eclipse Temurin 17.0.4+8 release.
* Wed Apr 27 2022 Eclipse Adoptium Package Maintainers <temurin-dev@eclipse.org> 17.0.3.0.0.7.adopt0
- Eclipse Temurin 17.0.3+7 release.
* Tue Feb 1 2022 Eclipse Adoptium Package Maintainers <temurin-dev@eclipse.org> 17.0.2.0.0.8-1.adopt0
- Eclipse Temurin 17.0.2+8 release. 
* Fri Aug 13 2021 Eclipse Adoptium Package Maintainers <temurin-dev@eclipse.org> 17.0.0.0.0.35-1.adopt0
- Eclipse Temurin 17.0.0+35 release.
