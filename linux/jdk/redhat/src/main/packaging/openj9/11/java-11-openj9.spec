%global upstream_version 11.0.10+9
# Only [A-Za-z0-9.] allowed in version:
# https://docs.fedoraproject.org/en-US/packaging-guidelines/Versioning/#_upstream_uses_invalid_characters_in_the_version
# also not very intuitive:
#  $ rpmdev-vercmp 11.0.10.0.1___9 11.0.10.0.0+9
#  11.0.10.0.0___9 == 11.0.10.0.0+9
%global spec_version 11.0.10.0.0.9
%global spec_release 1
%global priority 1111

%global source_url_base https://github.com/AdoptOpenJDK/openjdk11-binaries/releases/download
%global upstream_version_url %(echo %{upstream_version} | sed 's/\+/%%2B/g')
%global upstream_version_no_plus %(echo %{upstream_version} | sed 's/\+/_/g')
%global java_provides openj9
%global openj9_version 0.24.0
%global openj9_url_version _openj9-%{openj9_version}
%global jvm_type openj9

# Map architecture to the expected value in the download URL; Allow for a
# pre-defined value of vers_arch and use that if it's defined
#  x86_64 => x64
#  i668 = x86
%ifarch x86_64
%global vers_arch x64
%global vers_arch2 ppc64le
%global vers_arch3 s390x
%global src_num 0
%global sha_src_num 1
%endif
%ifarch ppc64le
%global vers_arch x64
%global vers_arch2 ppc64le
%global vers_arch3 s390x
%global src_num 2
%global sha_src_num 3
%endif
%ifarch s390x
%global vers_arch x64
%global vers_arch2 ppc64le
%global vers_arch3 s390x
%global src_num 4
%global sha_src_num 5
%endif
# Allow for noarch SRPM build
%ifarch noarch
%global src_num 0
%global sha_src_num 1
%endif

Name:        java-11-openj9
Version:     %{spec_version}
Release:     %{spec_release}%{?dist}
Summary:     OpenJ9 11 JDK

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

# First architecture (x86_64)
Source0: %{source_url_base}/jdk-%{upstream_version_url}%{openj9_url_version}/OpenJDK11u-jdk_%{vers_arch}_linux_%{jvm_type}_%{upstream_version_no_plus}%{openj9_url_version}.tar.gz
Source1: %{source_url_base}/jdk-%{upstream_version_url}%{openj9_url_version}/OpenJDK11u-jdk_%{vers_arch}_linux_%{jvm_type}_%{upstream_version_no_plus}%{openj9_url_version}.tar.gz.sha256.txt
# Second architecture (ppc64le)
Source2: %{source_url_base}/jdk-%{upstream_version_url}%{openj9_url_version}/OpenJDK11u-jdk_%{vers_arch2}_linux_%{jvm_type}_%{upstream_version_no_plus}%{openj9_url_version}.tar.gz
Source3: %{source_url_base}/jdk-%{upstream_version_url}%{openj9_url_version}/OpenJDK11u-jdk_%{vers_arch2}_linux_%{jvm_type}_%{upstream_version_no_plus}%{openj9_url_version}.tar.gz.sha256.txt
# Third architecture (s390x)
Source4: %{source_url_base}/jdk-%{upstream_version_url}%{openj9_url_version}/OpenJDK11u-jdk_%{vers_arch3}_linux_%{jvm_type}_%{upstream_version_no_plus}%{openj9_url_version}.tar.gz
Source5: %{source_url_base}/jdk-%{upstream_version_url}%{openj9_url_version}/OpenJDK11u-jdk_%{vers_arch3}_linux_%{jvm_type}_%{upstream_version_no_plus}%{openj9_url_version}.tar.gz.sha256.txt

# For the benefit of the SRPM only
Source100: https://github.com/ibmruntimes/openj9-openjdk-jdk11/archive/jdk-%{upstream_version_url}.tar.gz
Source101: https://github.com/eclipse/openj9/archive/openj9-%{openj9_version}/openj9-openj9-%{openj9_version}.tar.gz
Source102: https://github.com/eclipse/openj9-omr/archive/openj9-%{openj9_version}/openj9-omr-openj9-%{openj9_version}.tar.gz

# Set the compression format to xz to be compatible with more Red Hat flavours. Newer versions of Fedora use zstd which
# is not available on CentOS 7, for example. https://github.com/rpm-software-management/rpm/blob/master/macros.in#L353
# lists the available options.
%define _source_payload w7.xzdio
%define _binary_payload w7.xzdio

# Avoid build failures on some distros due to missing build-id in binaries.
%global debug_package %{nil}
%global __brp_strip %{nil}

%description
OpenJ9 JDK is an OpenJDK-based development environment to create
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
cp -r * %{buildroot}%{prefix}

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

%pretrans
# noop

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

%changelog
* Sun Jan 31 2021 Eclipse Adoptium Package Maintainers <temurin-dev@eclipse.org> 11.0.10.0.0.9-1.adopt0
- OpenJ9 11.0.10+9 release.
