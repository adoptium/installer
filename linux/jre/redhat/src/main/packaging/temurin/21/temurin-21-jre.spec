%global upstream_version 21.0.9+10
# Only [A-Za-z0-9.] allowed in version:
# https://docs.fedoraproject.org/en-US/packaging-guidelines/Versioning/#_upstream_uses_invalid_characters_in_the_version
# also not very intuitive:
#  $ rpmdev-vercmp 21.0.0.0.0___21.0.0.0.0+1
#  20.0.0.0.0___1 == 21.0.0.0.0+35
%global spec_version 21.0.9.0.0.10
%global spec_release 1
%global priority 2100

# if rpmbuild  will be executed as `rpmbuild -bb ...spec --without headful ...` then headless package will be generated
%bcond_without headful

%global source_url_base https://github.com/adoptium/temurin21-binaries/releases/download
%global upstream_version_url %(echo %{upstream_version} | sed 's/\+/%%2B/g')
%global upstream_version_no_plus %(echo %{upstream_version} | sed 's/\+/_/g')
%global java_provides openjre

# Map architecture to the expected value in the download URL; Allow for a
# pre-defined value of vers_arch and use that if it's defined

%ifarch x86_64
%global vers_arch x64
%global vers_arch2 ppc64le
%global vers_arch3 aarch64
%global vers_arch4 s390x
%global vers_arch5 riscv64
%global src_num 0
%global sha_src_num 1
%endif
%ifarch ppc64le
%global vers_arch x64
%global vers_arch2 ppc64le
%global vers_arch3 aarch64
%global vers_arch4 s390x
%global vers_arch5 riscv64
%global src_num 2
%global sha_src_num 3
%endif
%ifarch aarch64
%global vers_arch x64
%global vers_arch2 ppc64le
%global vers_arch3 aarch64
%global vers_arch4 s390x
%global vers_arch5 riscv64
%global src_num 4
%global sha_src_num 5
%endif
%ifarch s390x
%global vers_arch x64
%global vers_arch2 ppc64le
%global vers_arch3 aarch64
%global vers_arch4 s390x
%global vers_arch5 riscv64
%global src_num 6
%global sha_src_num 7
%endif
%ifarch riscv64
%global vers_arch x64
%global vers_arch2 ppc64le
%global vers_arch3 aarch64
%global vers_arch4 s390x
%global vers_arch5 riscv64
%global src_num 8
%global sha_src_num 9
%endif
# Allow for noarch SRPM build
%ifarch noarch
%global src_num 0
%global sha_src_num 1
%endif

%if %{with headful}
Name:        temurin-21-jre
%else
Name:        temurin-21-jre-headless
%endif
Version:     %{spec_version}
Release:     %{spec_release}
Summary:     Eclipse Temurin 21 JRE

Group:       java
License:     GPLv2 with exceptions
Vendor:      Eclipse Adoptium
URL:         https://projects.eclipse.org/projects/adoptium
Packager:    Eclipse Adoptium Package Maintainers <temurin-dev@eclipse.org>

AutoReqProv: no
Prefix: /usr/lib/jvm/%{name}

ExclusiveArch: x86_64 ppc64le aarch64 s390x riscv64

BuildRequires:  tar
BuildRequires:  wget

Requires: /bin/sh
Requires: /usr/sbin/alternatives
Requires: ca-certificates
%if %{with headful}
Requires: dejavu-sans-fonts
Requires: libX11%{?_isa}
Requires: libXext%{?_isa}
Requires: libXi%{?_isa}
Requires: libXrender%{?_isa}
Requires: libXtst%{?_isa}
Requires: alsa-lib%{?_isa}
Requires: fontconfig%{?_isa}
%endif
Requires: glibc%{?_isa}
Requires: zlib%{?_isa}

%if %{with headful}
Provides: jre
Provides: jre-21
Provides: jre-21-%{java_provides}
Provides: jre-%{java_provides}
%else
Provides: jre-21-headless
Provides: jre-21-%{java_provides}-headless
Provides: jre-headless
Provides: jre-%{java_provides}-headless
%endif

# First architecture (x86_64)
Source0: %{source_url_base}/jdk-%{upstream_version_url}/OpenJDK21U-jre_%{vers_arch}_linux_hotspot_%{upstream_version_no_plus}.tar.gz
Source1: %{source_url_base}/jdk-%{upstream_version_url}/OpenJDK21U-jre_%{vers_arch}_linux_hotspot_%{upstream_version_no_plus}.tar.gz.sha256.txt
# Second architecture (ppc64le)
Source2: %{source_url_base}/jdk-%{upstream_version_url}/OpenJDK21U-jre_%{vers_arch2}_linux_hotspot_%{upstream_version_no_plus}.tar.gz
Source3: %{source_url_base}/jdk-%{upstream_version_url}/OpenJDK21U-jre_%{vers_arch2}_linux_hotspot_%{upstream_version_no_plus}.tar.gz.sha256.txt
# Third architecture (aarch64)
Source4: %{source_url_base}/jdk-%{upstream_version_url}/OpenJDK21U-jre_%{vers_arch3}_linux_hotspot_%{upstream_version_no_plus}.tar.gz
Source5: %{source_url_base}/jdk-%{upstream_version_url}/OpenJDK21U-jre_%{vers_arch3}_linux_hotspot_%{upstream_version_no_plus}.tar.gz.sha256.txt
# Fourth architecture (s390x)
Source6: %{source_url_base}/jdk-%{upstream_version_url}/OpenJDK21U-jre_%{vers_arch4}_linux_hotspot_%{upstream_version_no_plus}.tar.gz
Source7: %{source_url_base}/jdk-%{upstream_version_url}/OpenJDK21U-jre_%{vers_arch4}_linux_hotspot_%{upstream_version_no_plus}.tar.gz.sha256.txt
# Fifth architecture (riscv64)
Source8: %{source_url_base}/jdk-%{upstream_version_url}/OpenJDK21U-jre_%{vers_arch5}_linux_hotspot_%{upstream_version_no_plus}.tar.gz
Source9: %{source_url_base}/jdk-%{upstream_version_url}/OpenJDK21U-jre_%{vers_arch5}_linux_hotspot_%{upstream_version_no_plus}.tar.gz.sha256.txt

# Set the compression format to xz to be compatible with more Red Hat flavours. Newer versions of Fedora use zstd which
# is not available on CentOS 7, for example. https://github.com/rpm-software-management/rpm/blob/master/macros.in#L353
# lists the available options.
%define _source_payload w7.xzdio
%define _binary_payload w7.xzdio

# Avoid build failures on some distros due to missing build-id in binaries.
%global debug_package %{nil}
%global __brp_strip %{nil}

%description
Eclipse Temurin JRE is an OpenJDK-based runtime environment to execute
applications and components using the programming language Java.

%prep
pushd "%{_sourcedir}"
sha256sum -c "%{expand:%{SOURCE%{sha_src_num}}}"
popd

%setup -n jdk-%{upstream_version}-jre -T -b %{src_num}

%build
# noop

%install
mkdir -p %{buildroot}%{prefix}
cd %{buildroot}%{prefix}
tar --strip-components=1 -C "%{buildroot}%{prefix}" -xf %{expand:%{SOURCE%{src_num}}}

# Use cacerts included in OS
rm -f "%{buildroot}%{prefix}/lib/security/cacerts"
pushd "%{buildroot}%{prefix}/lib/security"
ln -s /etc/pki/java/cacerts "%{buildroot}%{prefix}/lib/security/cacerts"
popd

%if %{with headful}
echo "this is headful version, nothing will be removed"
%else
echo "this is headless version, headful libraries will be removed"
pushd "%{buildroot}%{prefix}/lib"
 rm -v libsplashscreen.so libawt_xawt.so libjawt.so
popd
%endif

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
                        --slave %{_bindir}/jwebserver jwebserver %{prefix}/bin/jwebserver \
                        --slave %{_bindir}/keytool keytool %{prefix}/bin/keytool \
                        --slave %{_bindir}/rmiregistry rmiregistry %{prefix}/bin/rmiregistry
fi

%preun
if [ $1 -eq 0 ]; then
    update-alternatives --remove java %{prefix}/bin/java
fi

%files
%defattr(-,root,root)
%{prefix}
/usr/lib/tmpfiles.d/%{name}.conf

%changelog
* Wed Oct 16 2024 Eclipse Adoptium Package Maintainers <temurin-dev@eclipse.org> 21.0.5.0.0.11-1
- Eclipse Temurin 21.0.5+11 release.
* Wed Jul 17 2024 Eclipse Adoptium Package Maintainers <temurin-dev@eclipse.org> 21.0.4.0.0.7-1
- Eclipse Temurin 21.0.4+7 release.
* Wed Apr 17 2024 Eclipse Adoptium Package Maintainers <temurin-dev@eclipse.org> 21.0.3.0.0.9-1
- Eclipse Temurin 21.0.3+9 release.
* Wed Feb 28 2024 Eclipse Adoptium Package Maintainers <temurin-dev@eclipse.org> 21.0.2.0.0.13-3
- Eclipse Temurin 21.0.2+13 release.
* Wed Feb 21 2024 Eclipse Adoptium Package Maintainers <temurin-dev@eclipse.org> 21.0.2.0.0.13-2
- Eclipse Temurin 21.0.2+13 release.
* Tue Jan 23 2024 Eclipse Adoptium Package Maintainers <temurin-dev@eclipse.org> 21.0.2.0.0.13-1
- Eclipse Temurin 21.0.2+13 release.
* Tue Oct 24 2023 Eclipse Adoptium Package Maintainers <temurin-dev@eclipse.org> 21.0.1.0.0.12-1
- Eclipse Temurin 21.0.1+12 release.
* Wed Sep 20 2023 Eclipse Adoptium Package Maintainers <temurin-dev@eclipse.org> 21.0.0.0.0.35-1
- Eclipse Temurin 21.0.0+35 release 0.
