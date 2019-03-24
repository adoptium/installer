#!/bin/sh

set -eu

jdk_base_dir={{ prefix }}/{{ jdkDirectoryName }}
tools="{{ toolsAsLine }}"

if [ "$1" = "remove" ] || [ "$1" = "deconfigure" ] ; then
    for tool in $tools ; do
        for tool_path in "$jdk_base_dir/bin/$tool" "$jdk_base_dir/lib/$tool" ; do
            if [ ! -e "$tool_path" ] ; then
                continue
            fi

            update-alternatives --remove "$tool" "$tool_path"
        done
    done
fi
