#!/usr/bin/env bash
set -euo pipefail

input_dir="${1:?Usage: sign-apks.sh INPUT_DIRECTORY OUTPUT_DIRECTORY}"
output_dir="${2:?Usage: sign-apks.sh INPUT_DIRECTORY OUTPUT_DIRECTORY}"
: "${ANDROID_HOME:?ANDROID_HOME must point to the Android SDK}"
: "${RUNNER_TEMP:?RUNNER_TEMP must point to a temporary directory}"
: "${TERMUX_APK_VERSION_TAG:?TERMUX_APK_VERSION_TAG must match the built APK names}"
: "${TERMUX_RELEASE_KEYSTORE_FILE:?Missing release keystore file}"
: "${TERMUX_RELEASE_KEYSTORE_PASSWORD:?Missing release keystore password}"
: "${TERMUX_RELEASE_KEY_ALIAS:?Missing release key alias}"

build_tools="$ANDROID_HOME/build-tools/${BUILD_TOOLS_VERSION:-36.0.0}"
prefix="termux-app_$TERMUX_APK_VERSION_TAG"
apk_names=()
for abi in universal arm64-v8a armeabi-v7a x86_64 x86; do
    name="${prefix}_$abi.apk"
    if [[ ! -f "$input_dir/$name" ]]; then
        echo "Missing APK: $input_dir/$name" >&2
        exit 1
    fi
    apk_names+=("$name")
done

temporary_dir="$(mktemp -d "$RUNNER_TEMP/termux-align.XXXXXX")"
trap 'rm -rf "$temporary_dir"' EXIT
mkdir -p "$output_dir"

keytool -exportcert -rfc -storetype PKCS12 \
    -keystore "$TERMUX_RELEASE_KEYSTORE_FILE" \
    -storepass:env TERMUX_RELEASE_KEYSTORE_PASSWORD \
    -alias "$TERMUX_RELEASE_KEY_ALIAS" \
    -file "$output_dir/${prefix}_certificate.pem"

for name in "${apk_names[@]}"; do
    "$build_tools/zipalign" -P 16 4 "$input_dir/$name" "$temporary_dir/$name"
    "$build_tools/apksigner" sign \
        --ks "$TERMUX_RELEASE_KEYSTORE_FILE" --ks-type PKCS12 \
        --ks-key-alias "$TERMUX_RELEASE_KEY_ALIAS" \
        --ks-pass env:TERMUX_RELEASE_KEYSTORE_PASSWORD \
        --min-sdk-version 21 --v1-signing-enabled true \
        --v2-signing-enabled true --v3-signing-enabled true --v4-signing-enabled false \
        --debuggable-apk-permitted false --alignment-preserved true \
        --out "$output_dir/$name" "$temporary_dir/$name"
    "$build_tools/apksigner" verify --verbose --print-certs --min-sdk-version 21 "$output_dir/$name"
    "$build_tools/zipalign" -c -P 16 4 "$output_dir/$name"
done

(
    cd "$output_dir"
    sha256sum "${apk_names[@]}" > "${prefix}_SHA256SUMS"
    sha256sum --check "${prefix}_SHA256SUMS"
)
