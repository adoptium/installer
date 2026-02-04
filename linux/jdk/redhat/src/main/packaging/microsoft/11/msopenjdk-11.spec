%global upstream_version 11.0.30+7
# Only [A-Za-z0-9.] allowed in version:
# https://docs.fedoraproject.org/en-US/packaging-guidelines/Versioning/#_upstream_uses_invalid_characters_in_the_version
%global spec_version 11.0.30
%global spec_release 1
%global priority 1111

%global source_url_base https://aka.ms/download-jdk
%global java_provides openjdk

%global local_build_ %{?local_build}%{!?local_build:0}
%global override_arch_ %{?override_arch}%{!?override_arch:0}
# Above var evaluate to the value held in override_arch if defined,
# else evaluates to 0 (meaning: we will build for the actual system architecture)
# Same explanation for local_build_

# Map architecture to the expected value in the download URL; Allow for a
# pre-defined value of vers_arch and use that if it's defined

%global vers_arch x64
%global vers_arch2 aarch64

# Use override_arch_ if defined with correct value, else use system arch
%if "%{local_build_}" == "true"
%global src_num 4
%global sha_src_num 5
%elif "%{override_arch_}" == "aarch64"
%global src_num 2
%global sha_src_num 3
%elif "%{override_arch_}" == "x86_64" || "%{override_arch_}" == "x64"
%global src_num 0
%global sha_src_num 1
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

Name:        msopenjdk-11
Version:     %{spec_version}
Release:     %{spec_release}
Summary:     Microsoft Build of OpenJDK 11

Group:       java
License:     GPLv2 with Classpath Exception
Vendor:      Microsoft
URL:         https://www.microsoft.com/openjdk
Packager:    Microsoft Package Maintainers <openjdk@microsoft.com>

AutoReqProv: no
Prefix: /usr/lib/jvm/%{name}

ExclusiveArch: x86_64 aarch64

BuildRequires:  tar
BuildRequires:  wget

Requires: /bin/sh
Requires: /usr/sbin/alternatives
Requires: ca-certificates
Requires: glibc%{?_isa}
Requires: zlib%{?_isa}

Recommends: dejavu-sans-fonts
Recommends: alsa-lib%{?_isa}
Recommends: libX11%{?_isa}
Recommends: libXext%{?_isa}
Recommends: libXi%{?_isa}
Recommends: libXrender%{?_isa}
Recommends: libXtst%{?_isa}
Recommends: fontconfig%{?_isa}
Recommends: freetype%{?_isa}
Recommends: libasound%{?_isa}

Provides: java
Provides: java-11
Provides: java-11-devel
Provides: java-11-%{java_provides}
Provides: java-11-%{java_provides}-devel
Provides: java-devel
Provides: java-%{java_provides}
Provides: java-%{java_provides}-devel
Provides: java-sdk-11
Provides: java-sdk-11-%{java_provides}
Provides: jre
Provides: jre-11
Provides: jre-11-%{java_provides}
Provides: jre-%{java_provides}

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

# Set the compression format to xz to be compatible with more Red Hat flavours. Newer versions of Fedora use zstd which
# is not available on CentOS 7, for example. https://github.com/rpm-software-management/rpm/blob/master/macros.in#L353
# lists the available options.
%define _source_payload w7.xzdio
%define _binary_payload w7.xzdio

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

# Strip bundled Freetype and use OS package instead.
rm -f "%{buildroot}%{prefix}/lib/libfreetype.so"

# Ensure systemd-tmpfiles-clean does not remove pid files
# https://bugzilla.redhat.com/show_bug.cgi?id=1704608
%{__mkdir} -p %{buildroot}/usr/lib/tmpfiles.d
echo 'x /tmp/hsperfdata_*' > "%{buildroot}/usr/lib/tmpfiles.d/%{name}.conf"
echo 'x /tmp/.java_pid*' >> "%{buildroot}/usr/lib/tmpfiles.d/%{name}.conf"

%post
if [ $1 -ge 1 ] ; then
    update-alternatives --install %{_bindir}/java java %{prefix}/bin/java %{priority} \
                        --slave %{_bindir}/jfr jfr %{prefix}/bin/jfr \
                        --slave %{_bindir}/jjs jjs %{prefix}/bin/jjs \
                        --slave %{_bindir}/jrunscript jrunscript %{prefix}/bin/jrunscript \
                        --slave %{_bindir}/keytool keytool %{prefix}/bin/keytool \
                        --slave %{_bindir}/pack200 pack200 %{prefix}/bin/pack200 \
                        --slave %{_bindir}/rmid rmid %{prefix}/bin/rmid \
                        --slave %{_bindir}/rmiregistry rmiregistry %{prefix}/bin/rmiregistry \
                        --slave %{_bindir}/unpack200 unpack200 %{prefix}/bin/unpack200 \
                        --slave %{_bindir}/jexec jexec %{prefix}/lib/jexec \
                        --slave %{_bindir}/jspawnhelper jspawnhelper %{prefix}/lib/jspawnhelper \
                        --slave  %{_mandir}/man1/java.1 java.1 %{prefix}/man/man1/java.1 \
                        --slave  %{_mandir}/man1/jjs.1 jjs.1 %{prefix}/man/man1/jjs.1 \
                        --slave  %{_mandir}/man1/jrunscript.1 jrunscript.1 %{prefix}/man/man1/jrunscript.1 \
                        --slave  %{_mandir}/man1/keytool.1 keytool.1 %{prefix}/man/man1/keytool.1 \
                        --slave  %{_mandir}/man1/pack200.1 pack200.1 %{prefix}/man/man1/pack200.1 \
                        --slave  %{_mandir}/man1/rmid.1 rmid.1 %{prefix}/man/man1/rmid.1 \
                        --slave  %{_mandir}/man1/rmiregistry.1 rmiregistry.1 %{prefix}/man/man1/rmiregistry.1 \
                        --slave  %{_mandir}/man1/unpack200.1 unpack200.1 %{prefix}/man/man1/unpack200.1

    update-alternatives --install %{_bindir}/javac javac %{prefix}/bin/javac %{priority} \
                        --slave %{_bindir}/jaotc jaotc %{prefix}/bin/jaotc \
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
                        --slave %{_bindir}/jps jps %{prefix}/bin/jps \
                        --slave %{_bindir}/jshell jshell %{prefix}/bin/jshell \
                        --slave %{_bindir}/jstack jstack %{prefix}/bin/jstack \
                        --slave %{_bindir}/jstat jstat %{prefix}/bin/jstat \
                        --slave %{_bindir}/jstatd jstatd %{prefix}/bin/jstatd \
                        --slave %{_bindir}/rmic rmic %{prefix}/bin/rmic \
                        --slave %{_bindir}/serialver serialver %{prefix}/bin/serialver \
                        --slave  %{_mandir}/man1/jar.1 jar.1 %{prefix}/man/man1/jar.1 \
                        --slave  %{_mandir}/man1/jarsigner.1 jarsigner.1 %{prefix}/man/man1/jarsigner.1 \
                        --slave  %{_mandir}/man1/javac.1 javac.1 %{prefix}/man/man1/javac.1 \
                        --slave  %{_mandir}/man1/javadoc.1 javadoc.1 %{prefix}/man/man1/javadoc.1 \
                        --slave  %{_mandir}/man1/javap.1 javap.1 %{prefix}/man/man1/javap.1 \
                        --slave  %{_mandir}/man1/jcmd.1 jcmd.1 %{prefix}/man/man1/jcmd.1 \
                        --slave  %{_mandir}/man1/jconsole.1 jconsole.1 %{prefix}/man/man1/jconsole.1 \
                        --slave  %{_mandir}/man1/jdb.1 jdb.1 %{prefix}/man/man1/jdb.1 \
                        --slave  %{_mandir}/man1/jdeps.1 jdeps.1 %{prefix}/man/man1/jdeps.1 \
                        --slave  %{_mandir}/man1/jinfo.1 jinfo.1 %{prefix}/man/man1/jinfo.1 \
                        --slave  %{_mandir}/man1/jmap.1 jmap.1 %{prefix}/man/man1/jmap.1 \
                        --slave  %{_mandir}/man1/jps.1 jps.1 %{prefix}/man/man1/jps.1 \
                        --slave  %{_mandir}/man1/jstack.1 jstack.1 %{prefix}/man/man1/jstack.1 \
                        --slave  %{_mandir}/man1/jstat.1 jstat.1 %{prefix}/man/man1/jstat.1 \
                        --slave  %{_mandir}/man1/jstatd.1 jstatd.1 %{prefix}/man/man1/jstatd.1 \
                        --slave  %{_mandir}/man1/rmic.1 rmic.1 %{prefix}/man/man1/rmic.1 \
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
# Make below specific 
%changelog
* Wed Jan 14 2026 Microsoft Package Maintainers <openjdk@microsoft.com> 11.0.30-1
- Microsoft 11.0.30+7 initial release.
* Tue Oct 14 2025 Microsoft Package Maintainers <openjdk@microsoft.com> 11.0.29-1
- Microsoft 11.0.29+7 initial release.
* Tue Jul 08 2025 Microsoft Package Maintainers <openjdk@microsoft.com> 11.0.28-1
- Microsoft 11.0.28+6 initial release.
* Thu Apr 10 2025 Microsoft Package Maintainers <openjdk@microsoft.com> 11.0.27-1
- Microsoft 11.0.27+6 initial release.
* Tue Jan 14 2025 Microsoft Package Maintainers <openjdk@microsoft.com> 11.0.26-1
- Microsoft 11.0.26+4 initial release.
* Fri Oct 11 2024 Microsoft Package Maintainers <openjdk@microsoft.com> 11.0.25-1
- Microsoft 11.0.25+9 initial release.
* Fri Jul 19 2024 Microsoft Package Maintainers <openjdk@microsoft.com> 11.0.24-1
- Microsoft 11.0.24+8 initial release.
* Thu Apr 11 2024 Microsoft Package Maintainers <openjdk@microsoft.com> 11.0.23-1
- Microsoft 11.0.23+9 initial release.
* Thu Jan 11 2024 Microsoft Package Maintainers <openjdk@microsoft.com> 11.0.22-1
- Microsoft 11.0.22+7 initial release.
* Wed Oct 11 2023 Microsoft Package Maintainers <openjdk@microsoft.com> 11.0.21-1
- Microsoft 11.0.21+9 initial release.
* Wed Aug 23 2023 Microsoft Package Maintainers <openjdk@microsoft.com> 11.0.20.1-1
- Microsoft 11.0.20.1+1 initial release.
* Fri Jul 07 2023 Microsoft Package Maintainers <openjdk@microsoft.com> 11.0.20-1
- Microsoft 11.0.20+8 initial release.
* Tue Apr 18 2023 Microsoft Package Maintainers <openjdk@microsoft.com> 11.0.19-1
- Microsoft 11.0.19+7 initial release.
* Mon Apr 3 2023 Microsoft Package Maintainers <openjdk@microsoft.com> 11.0.18-1
- Microsoft 11.0.18+10 initial release.