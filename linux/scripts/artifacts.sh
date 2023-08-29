#!/bin/bash

TYPE=("jdk" "jre" "src")
VERS=("$@") # Accept the VERS array as arguments
DIST=("apk" "deb" "rpm")
DEBDISTS=("bookworm" "bullseye" "buster" "kinetic" "jammy" "focal" "bionic")
RPMDISTS=("centos/7" "rocky/8" "rhel/7" "opensuse/15.3")

if [ $# -eq 0 ]; then
    echo "Please provide the VERS array as arguments"
    exit 1
fi

for EACHTYPE in "${TYPE[@]}"; do
    for EACHVERS in "${VERS[@]}"; do
        for EACHDIST in "${DIST[@]}"; do
            ## Limit APK To Only x86_64
            if [ "$EACHDIST" = "apk" ]; then
                ARCH=("x86_64")
            else
                ARCH=("x86_64" "armv7hl" "armv7l" "aarch64" "ppc64le" "s390x")
            fi
            for EACHARCH in "${ARCH[@]}"; do
                if [ "$EACHDIST" = "deb" ]; then
                    for EACHDEB in "${DEBDISTS[@]}"; do
                        echo TYPE = $EACHTYPE, $EACHVERS, $EACHDIST, $EACHARCH, $EACHDEB
                    done
                fi

                if [ "$EACHDIST" = "rpm" ]; then
                    for EACHRPM in "${RPMDISTS[@]}"; do
                        echo TYPE = $EACHTYPE, $EACHVERS, $EACHDIST, $EACHARCH, $EACHRPM
                    done
                fi

                if [ "$EACHDIST" = "apk" ]; then
                    echo TYPE = $EACHTYPE, $EACHVERS, $EACHDIST, $EACHARCH
                fi
            done
        done
    done
done
