#!/bin/zsh

set -eu

if [[ $# -ne 2 ]]; then
    print -u2 "Usage: $0 /path/to/9128live_menubar_app.app expected-build-number"
    exit 64
fi

app_path=$1
expected_build=$2
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

if [[ "$build_number" != "$expected_build" ]]; then
    print -u2 "Release verification failed: expected build $expected_build, found $build_number."
    exit 1
fi

print "Release verification passed: build $build_number contains Last.fm configuration."
