#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

module=example.com/tdb-go-grpc
files=()
options=()
for source in proto/service/tdb/crud/v1/*.proto proto/service/tdb/shared/v1/*.proto; do
    file=${source#proto/}
    package="$module/gen/$(dirname "$file")"
    files+=("$file")
    # Override go_package from the exported contracts for this client module.
    options+=("--go_opt=M$file=$package" "--go-grpc_opt=M$file=$package")
done

protoc --proto_path=proto \
    --go_out=. --go_opt="module=$module" \
    --go-grpc_out=. --go-grpc_opt="module=$module" \
    "${options[@]}" "${files[@]}"
