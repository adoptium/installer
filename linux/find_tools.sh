#! /bin/bash

set -eu

for tool_path in $(find $1 -type f -executable) ; do
    tool_dir_path=${tool_path%/*}
    tool_dir=${tool_dir_path##*/}
    echo $tool_dir/${tool_path##*/}
done
