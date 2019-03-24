#!/bin/sh

set -eu

priority={{ priority }}
jdk_base_dir={{ prefix }}/{{ jdkDirectoryName }}
tools="{{ toolsAsLine }}"

case "$1" in
configure)
    for tool in $tools ; do
        for tool_path in "$jdk_base_dir/bin/$tool" "$jdk_base_dir/lib/$tool" ; do
            if [ ! -e "$tool_path" ]; then
                continue
            fi

            slave=""
            tool_man_path="$jdk_base_dir/man/man1/$tool.1"
            if [ -e "$tool_man_path" ]; then
                slave="--slave /usr/share/man/man1/$tool.1 $tool.1 $tool_man_path"
            fi

            update-alternatives \
                --install \
                "/usr/bin/$tool" \
                "$tool" \
                "$tool_path" \
                "$priority" \
                $slave
        done
    done
;;
esac
