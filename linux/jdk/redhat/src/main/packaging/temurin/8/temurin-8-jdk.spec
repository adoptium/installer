%global upstream_version 8u362-b09
# Only [A-Za-z0-9.] allowed in version:
# https://docs.fedoraproject.org/en-US/packaging-guidelines/Versioning/#_upstream_uses_invalid_characters_in_the_version
# also not very intuitive:
#  $ rpmdev-vercmp 8.0.312.0.1___8 8.0.312.0.0+7
#  8.0.312.0.0___7 == 8.0.312.0.0+7
%global spec_version 8.0.362.0.0.9
%global spec_release 1
%global priority 1081

%global source_url_base https://github.com/adoptium/temurin8-binaries/releases/download
%global upstream_version_no_dash %(echo %{upstream_version} | sed 's/-//g')
%global java_provides openjdk

# Map architecture to the expected value in the download URL; Allow for a
# pre-defined value of vers_arch and use that if it's defined

%ifarch x86_64
%global vers_arch x64
%global vers_arch2 ppc64le
%global vers_arch3 aarch64
%global vers_arch4 arm
%global src_num 0
%global sha_src_num 1
%endif
%ifarch ppc64le
%global vers_arch x64
%global vers_arch2 ppc64le
%global vers_arch3 aarch64
%global vers_arch4 arm
%global src_num 2
%global sha_src_num 3
%endif
%ifarch aarch64
%global vers_arch x64
%global vers_arch2 ppc64le
%global vers_arch3 aarch64
%global vers_arch4 arm
%global src_num 4
%global sha_src_num 5
%endif
%ifarch %{arm}
%global vers_arch x64
%global vers_arch2 ppc64le
%global vers_arch3 aarch64
%global vers_arch4 arm
%global src_num 6
%global sha_src_num 7
# jdk8 arm32 has different top directory name https://github.com/adoptium/temurin-build/issues/2795
%global upstream_version 8u362-b09-aarch32-20230119
%endif
# Allow for noarch SRPM build
%ifarch noarch
%global src_num 0
%global sha_src_num 1
%endif

Name:        temurin-8-jdk
Version:     %{spec_version}
Release:     %{spec_release}
Summary:     Eclipse Temurin 8 JDK

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
%ifarch %{arm}
Requires: libatomic
%endif
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
Provides: java-1.8.0
Provides: java-1.8.0-devel
Provides: java-1.8.0-headless
Provides: java-1.8.0-%{java_provides}
Provides: java-1.8.0-%{java_provides}-devel
Provides: java-1.8.0-%{java_provides}-headless
Provides: java-devel
Provides: java-devel-%{java_provides}
Provides: java-headless
Provides: java-%{java_provides}
Provides: java-%{java_provides}-devel
Provides: java-%{java_provides}-headless
Provides: java-sdk
Provides: java-sdk-1.8.0
Provides: java-sdk-1.8.0-%{java_provides}
Provides: java-sdk-%{java_provides}
Provides: jre
Provides: jre-1.8.0
Provides: jre-1.8.0-headless
Provides: jre-1.8.0-%{java_provides}
Provides: jre-1.8.0-%{java_provides}-headless
Provides: jre-headless
Provides: jre-%{java_provides}
Provides: jre-%{java_provides}-headless

# First architecture (x86_64)
Source0: %{source_url_base}/jdk%{upstream_version}/OpenJDK8U-jdk_%{vers_arch}_linux_hotspot_%{upstream_version_no_dash}.tar.gz
Source1: %{source_url_base}/jdk%{upstream_version}/OpenJDK8U-jdk_%{vers_arch}_linux_hotspot_%{upstream_version_no_dash}.tar.gz.sha256.txt
# Second architecture (ppc64le)
Source2: %{source_url_base}/jdk%{upstream_version}/OpenJDK8U-jdk_%{vers_arch2}_linux_hotspot_%{upstream_version_no_dash}.tar.gz
Source3: %{source_url_base}/jdk%{upstream_version}/OpenJDK8U-jdk_%{vers_arch2}_linux_hotspot_%{upstream_version_no_dash}.tar.gz.sha256.txt
# Third architecture (aarch64)
Source4: %{source_url_base}/jdk%{upstream_version}/OpenJDK8U-jdk_%{vers_arch3}_linux_hotspot_%{upstream_version_no_dash}.tar.gz
Source5: %{source_url_base}/jdk%{upstream_version}/OpenJDK8U-jdk_%{vers_arch3}_linux_hotspot_%{upstream_version_no_dash}.tar.gz.sha256.txt
# Fourth architecture (arm32)
Source6: %{source_url_base}/jdk%{upstream_version}/OpenJDK8U-jdk_%{vers_arch4}_linux_hotspot_%{upstream_version_no_dash}.tar.gz
Source7: %{source_url_base}/jdk%{upstream_version}/OpenJDK8U-jdk_%{vers_arch4}_linux_hotspot_%{upstream_version_no_dash}.tar.gz.sha256.txt

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

%setup -n jdk%{upstream_version} -T -b %{src_num}

%build
# noop

%install
mkdir -p %{buildroot}%{prefix}
cd %{buildroot}%{prefix}
tar --strip-components=1 -C "%{buildroot}%{prefix}" -xf %{expand:%{SOURCE%{src_num}}}

# Strip bundled Freetype and use OS package instead.
rm -f "%{buildroot}%{prefix}/lib/libfreetype.so"

# Use cacerts included in OS
rm -f "%{buildroot}%{prefix}/jre/lib/security/cacerts"
pushd "%{buildroot}%{prefix}/jre/lib/security"
ln -s /etc/pki/java/cacerts "%{buildroot}%{prefix}/jre/lib/security/cacerts"
popd

# Ensure systemd-tmpfiles-clean does not remove pid files
# https://bugzilla.redhat.com/show_bug.cgi?id=1704608
%{__mkdir} -p %{buildroot}/usr/lib/tmpfiles.d
echo 'x /tmp/hsperfdata_*' > "%{buildroot}/usr/lib/tmpfiles.d/%{name}.conf"
echo 'x /tmp/.java_pid*' >> "%{buildroot}/usr/lib/tmpfiles.d/%{name}.conf"

%post
if [ $1 -ge 1 ] ; then
    update-alternatives --install %{_bindir}/java java %{prefix}/bin/java %{priority} \
                        --slave %{_bindir}/jjs jjs %{prefix}/bin/jjs \
                        --slave %{_bindir}/jrunscript jrunscript %{prefix}/bin/jrunscript \
                        --slave %{_bindir}/keytool keytool %{prefix}/bin/keytool \
                        --slave %{_bindir}/orbd orbd %{prefix}/bin/orbd \
                        --slave %{_bindir}/pack200 pack200 %{prefix}/bin/pack200 \
                        --slave %{_bindir}/policytool policytool %{prefix}/bin/policytool \
                        --slave %{_bindir}/rmid rmid %{prefix}/bin/rmid \
                        --slave %{_bindir}/rmiregistry rmiregistry %{prefix}/bin/rmiregistry \
                        --slave %{_bindir}/servertool servertool %{prefix}/bin/servertool \
                        --slave %{_bindir}/tnameserv tnameserv %{prefix}/bin/tnameserv \
                        --slave %{_bindir}/unpack200 unpack200 %{prefix}/bin/unpack200 \
                        --slave %{_bindir}/jexec jexec %{prefix}/lib/jexec \
                        --slave %{_mandir}/man1/java.1 java.1 %{prefix}/man/man1/java.1 \
                        --slave %{_mandir}/man1/jjs.1 jjs.1 %{prefix}/man/man1/jjs.1 \
                        --slave %{_mandir}/man1/jrunscript.1 jrunscript.1 %{prefix}/man/man1/jrunscript.1 \
                        --slave %{_mandir}/man1/keytool.1 keytool.1 %{prefix}/man/man1/keytool.1 \
                        --slave %{_mandir}/man1/orbd.1 orbd.1 %{prefix}/man/man1/orbd.1 \
                        --slave %{_mandir}/man1/pack200.1 pack200.1 %{prefix}/man/man1/pack200.1 \
                        --slave %{_mandir}/man1/policytool.1 policytool.1 %{prefix}/man/man1/policytool.1 \
                        --slave %{_mandir}/man1/rmid.1 rmid.1 %{prefix}/man/man1/rmid.1 \
                        --slave %{_mandir}/man1/rmiregistry.1 rmiregistry.1 %{prefix}/man/man1/rmiregistry.1 \
                        --slave %{_mandir}/man1/servertool.1 servertool.1 %{prefix}/man/man1/servertool.1 \
                        --slave %{_mandir}/man1/tnameserv.1 tnameserv.1 %{prefix}/man/man1/tnameserv.1 \
                        --slave %{_mandir}/man1/unpack200.1 unpack200.1 %{prefix}/man/man1/unpack200.1

    update-alternatives --install %{_bindir}/javac javac %{prefix}/bin/javac 1081 \
                        --slave %{_bindir}/appletviewer appletviewer %{prefix}/bin/appletviewer \
                        --slave %{_bindir}/clhsdb clhsdb %{prefix}/bin/clhsdb \
                        --slave %{_bindir}/extcheck extcheck %{prefix}/bin/extcheck \
                        --slave %{_bindir}/hsdb hsdb %{prefix}/bin/hsdb \
                        --slave %{_bindir}/idlj idlj %{prefix}/bin/idlj \
                        --slave %{_bindir}/jar jar %{prefix}/bin/jar \
                        --slave %{_bindir}/jarsigner jarsigner %{prefix}/bin/jarsigner \
                        --slave %{_bindir}/javadoc javadoc %{prefix}/bin/javadoc \
                        --slave %{_bindir}/javah javah %{prefix}/bin/javah \
                        --slave %{_bindir}/javap javap %{prefix}/bin/javap \
                        --slave %{_bindir}/jcmd jcmd %{prefix}/bin/jcmd \
                        --slave %{_bindir}/jconsole jconsole %{prefix}/bin/jconsole \
                        --slave %{_bindir}/jdb jdb %{prefix}/bin/jdb \
                        --slave %{_bindir}/jdeps jdeps %{prefix}/bin/jdeps \
                        --slave %{_bindir}/jfr jfr %{prefix}/bin/jfr \
                        --slave %{_bindir}/jhat jhat %{prefix}/bin/jhat \
                        --slave %{_bindir}/jinfo jinfo %{prefix}/bin/jinfo \
                        --slave %{_bindir}/jmap jmap %{prefix}/bin/jmap \
                        --slave %{_bindir}/jps jps %{prefix}/bin/jps \
                        --slave %{_bindir}/jsadebugd jsadebugd %{prefix}/bin/jsadebugd \
                        --slave %{_bindir}/jstack jstack %{prefix}/bin/jstack \
                        --slave %{_bindir}/jstat jstat %{prefix}/bin/jstat \
                        --slave %{_bindir}/jstatd jstatd %{prefix}/bin/jstatd \
                        --slave %{_bindir}/native2ascii native2ascii %{prefix}/bin/native2ascii \
                        --slave %{_bindir}/rmic rmic %{prefix}/bin/rmic \
                        --slave %{_bindir}/schemagen schemagen %{prefix}/bin/schemagen \
                        --slave %{_bindir}/serialver serialver %{prefix}/bin/serialver \
                        --slave %{_bindir}/wsgen wsgen %{prefix}/bin/wsgen \
                        --slave %{_bindir}/wsimport wsimport %{prefix}/bin/wsimport \
                        --slave %{_bindir}/xjc xjc %{prefix}/bin/xjc \
                        --slave %{_mandir}/man1/appletviewer.1 appletviewer.1 %{prefix}/man/man1/appletviewer.1 \
                        --slave %{_mandir}/man1/clhsdb.1 clhsdb.1 %{prefix}/man/man1/clhsdb.1 \
                        --slave %{_mandir}/man1/extcheck.1 extcheck.1 %{prefix}/man/man1/extcheck.1 \
                        --slave %{_mandir}/man1/hsdb.1 hsdb.1 %{prefix}/man/man1/hsdb.1 \
                        --slave %{_mandir}/man1/idlj.1 idlj.1 %{prefix}/man/man1/idlj.1 \
                        --slave %{_mandir}/man1/jar.1 jar.1 %{prefix}/man/man1/jar.1 \
                        --slave %{_mandir}/man1/jarsigner.1 jarsigner.1 %{prefix}/man/man1/jarsigner.1 \
                        --slave %{_mandir}/man1/javac.1 javac.1 %{prefix}/man/man1/javac.1 \
                        --slave %{_mandir}/man1/javadoc.1 javadoc.1 %{prefix}/man/man1/javadoc.1 \
                        --slave %{_mandir}/man1/javah.1 javah.1 %{prefix}/man/man1/javah.1 \
                        --slave %{_mandir}/man1/javap.1 javap.1 %{prefix}/man/man1/javap.1 \
                        --slave %{_mandir}/man1/jcmd.1 jcmd.1 %{prefix}/man/man1/jcmd.1 \
                        --slave %{_mandir}/man1/jconsole.1 jconsole.1 %{prefix}/man/man1/jconsole.1 \
                        --slave %{_mandir}/man1/jdb.1 jdb.1 %{prefix}/man/man1/jdb.1 \
                        --slave %{_mandir}/man1/jdeps.1 jdeps.1 %{prefix}/man/man1/jdeps.1 \
                        --slave %{_mandir}/man1/jhat.1 jhat.1 %{prefix}/man/man1/jhat.1 \
                        --slave %{_mandir}/man1/jinfo.1 jinfo.1 %{prefix}/man/man1/jinfo.1 \
                        --slave %{_mandir}/man1/jmap.1 jmap.1 %{prefix}/man/man1/jmap.1 \
                        --slave %{_mandir}/man1/jps.1 jps.1 %{prefix}/man/man1/jps.1 \
                        --slave %{_mandir}/man1/jsadebugd.1 jsadebugd.1 %{prefix}/man/man1/jsadebugd.1 \
                        --slave %{_mandir}/man1/jstack.1 jstack.1 %{prefix}/man/man1/jstack.1 \
                        --slave %{_mandir}/man1/jstat.1 jstat.1 %{prefix}/man/man1/jstat.1 \
                        --slave %{_mandir}/man1/jstatd.1 jstatd.1 %{prefix}/man/man1/jstatd.1 \
                        --slave %{_mandir}/man1/native2ascii.1 native2ascii.1 %{prefix}/man/man1/native2ascii.1 \
                        --slave %{_mandir}/man1/rmic.1 rmic.1 %{prefix}/man/man1/rmic.1 \
                        --slave %{_mandir}/man1/schemagen.1 schemagen.1 %{prefix}/man/man1/schemagen.1 \
                        --slave %{_mandir}/man1/serialver.1 serialver.1 %{prefix}/man/man1/serialver.1 \
                        --slave %{_mandir}/man1/wsgen.1 wsgen.1 %{prefix}/man/man1/wsgen.1 \
                        --slave %{_mandir}/man1/wsimport.1 wsimport.1 %{prefix}/man/man1/wsimport.1 \
                        --slave %{_mandir}/man1/xjc.1 xjc.1 %{prefix}/man/man1/xjc.1
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
# tag::changelog-current[]
* Wed Jan 18 2023 Eclipse Adoptium Package Maintainers <temurin-dev@eclipse.org> 8.0.362.0.0.9.adopt0
- Eclipse Temurin 8.0.362-b09 release.
# end::changelog-current[]
* Thu Nov 03 2022 Eclipse Adoptium Package Maintainers <temurin-dev@eclipse.org> 8.0.352.0.0.8.adopt0
- Eclipse Temurin 8.0.352-b08 release.
* Thu Aug 08 2022 Eclipse Adoptium Package Maintainers <temurin-dev@eclipse.org> 8.0.345.0.0.1.adopt0
- Eclipse Temurin 8.0.345-b01 release.
* Thu May 05 2022 Eclipse Adoptium Package Maintainers <temurin-dev@eclipse.org> 8.0.332.0.0.9.adopt0
- Eclipse Temurin 8.0.332-b09 release.
* Thu Feb 03 2022 Eclipse Adoptium Package Maintainers <temurin-dev@eclipse.org> 8.0.322.0.0.6-1.adopt0
- Eclipse Temurin 8.0.322-b06 release.
* Tue Aug 31 2021 Eclipse Adoptium Package Maintainers <temurin-dev@eclipse.org> 8.0.302.0.0.8-1.adopt0
- Eclipse Temurin 8.0.302-b08 release.
