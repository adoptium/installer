#! /bin/bash

set -eu

libs=()
for file in $(find $1 -type f -executable -or -name '*.so') ; do
    libs+=( $(objdump -p $file | grep NEEDED | tr -s " " | cut -d" " -f3) )
done

unique_libs=( $(printf "%s\n" "${libs[@]}" | sort -u) );

for lib in "${unique_libs[@]}" ; do
    echo "$lib"
done
