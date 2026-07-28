#!/bin/zsh

set -eu

if [[ $# -ne 3 ]]; then
    print -u2 "Usage: $0 /path/to/app expected-build-number expected-app-filename"
    exit 64
fi

app_path=$1
expected_build=$2
expected_app_name=$3
plist_path="$app_path/Contents/Info.plist"

if [[ ! -f "$plist_path" ]]; then
    print -u2 "Release verification failed: Info.plist was not found."
    exit 1
fi

read_plist_value() {
    /usr/libexec/PlistBuddy -c "Print :$1" "$plist_path" 2>/dev/null || true
}

api_key=$(read_plist_value LastFMAPIKey)
shared_secret=$(read_plist_value LastFMSharedSecret)
build_number=$(read_plist_value CFBundleVersion)

if [[ -z "$api_key" || -z "$shared_secret" ]]; then
    print -u2 "Release verification failed: Last.fm configuration is missing."
    exit 1
fi

actual_app_name=${app_path:t}

if [[ "$actual_app_name" != "$expected_app_name" ]]; then
    print -u2 "Release verification failed: expected app filename $expected_app_name, found $actual_app_name."
    exit 1
fi

if [[ "$build_number" != "$expected_build" ]]; then
    print -u2 "Release verification failed: expected build $expected_build, found $build_number."
    exit 1
fi

print "Release verification passed: $actual_app_name is build $build_number and contains Last.fm configuration."
