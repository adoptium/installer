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
                # Exclude specific architectures based on conditions
                ARCH=("x86_64" "aarch64" "ppc64le")
                if [ "$EACHDIST" = "deb" ]; then
                    if [ "$EACHVERS" != "8.0.382.0.0.5-1" ]; then
                        ARCH+=("armv7l")
                    fi
                    for EACHDEB in "${DEBDISTS[@]}"; do
                        echo TYPE = $EACHTYPE, $EACHVERS, $EACHDIST, $EACHARCH, $EACHDEB
                    done
                fi

                if [ "$EACHDIST" = "rpm" ]; then
                    if [ "$EACHVERS" != "8.0.382.0.0.5-1" ]; then
                        ARCH+=("armv7hl")
                    fi
                    for EACHRPM in "${RPMDISTS[@]}"; do
                        echo TYPE = $EACHTYPE, $EACHVERS, $EACHDIST, $EACHARCH, $EACHRPM
                    done
                fi
            fi

            for EACHARCH in "${ARCH[@]}"; do
                if [ "$EACHDIST" = "apk" ]; then
                    echo TYPE = $EACHTYPE, $EACHVERS, $EACHDIST, $EACHARCH
                fi
            done
        done
    done
done
