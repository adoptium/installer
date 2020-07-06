if [ $1 -ge 1 ] ; then
    update-alternatives --install /usr/bin/java java {{ prefix }}/{{ jdkDirectoryName }}/bin/java 1161 \
                        --slave /usr/bin/jaotc jaotc {{ prefix }}/{{ jdkDirectoryName }}/bin/jaotc \
                        --slave /usr/bin/jfr jfr {{ prefix }}/{{ jdkDirectoryName }}/bin/jfr \
                        --slave /usr/bin/jjs jjs {{ prefix }}/{{ jdkDirectoryName }}/bin/jjs \
                        --slave /usr/bin/jrunscript jrunscript {{ prefix }}/{{ jdkDirectoryName }}/bin/jrunscript \
                        --slave /usr/bin/keytool keytool {{ prefix }}/{{ jdkDirectoryName }}/bin/keytool \
                        --slave /usr/bin/rmid rmid {{ prefix }}/{{ jdkDirectoryName }}/bin/rmid \
                        --slave /usr/bin/rmiregistry rmiregistry {{ prefix }}/{{ jdkDirectoryName }}/bin/rmiregistry \
                        --slave /usr/bin/jexec jexec {{ prefix }}/{{ jdkDirectoryName }}/lib/jexec \
                        --slave /usr/bin/jspawnhelper jspawnhelper {{ prefix }}/{{ jdkDirectoryName }}/lib/jspawnhelper \
                        --slave /usr/share/man/man1/java.1 java.1 {{ prefix }}/{{ jdkDirectoryName }}/man/man1/java.1 \
                        --slave /usr/share/man/man1/jjs.1 jjs.1 {{ prefix }}/{{ jdkDirectoryName }}/man/man1/jjs.1 \
                        --slave /usr/share/man/man1/jrunscript.1 jrunscript.1 {{ prefix }}/{{ jdkDirectoryName }}/man/man1/jrunscript.1 \
                        --slave /usr/share/man/man1/keytool.1 keytool.1 {{ prefix }}/{{ jdkDirectoryName }}/man/man1/keytool.1 \
                        --slave /usr/share/man/man1/rmid.1 rmid.1 {{ prefix }}/{{ jdkDirectoryName }}/man/man1/rmid.1 \
                        --slave /usr/share/man/man1/rmiregistry.1 rmiregistry.1 {{ prefix }}/{{ jdkDirectoryName }}/man/man1/rmiregistry.1
fi
