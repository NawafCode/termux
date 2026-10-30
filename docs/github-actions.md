# GitHub Actions

## Build and tests

`Build`, `Unit tests`, and `Validate Gradle Wrapper` run on pushes and pull
requests. They can also be started from the Actions tab with **Run workflow**.
The Build workflow produces test-key-signed Debug APKs for development.

## Dependency submission

Enable **Dependency graph** under repository **Settings → Advanced Security**.
GitHub rejects dependency snapshots while this repository setting is disabled;
changing the Gradle action or suppressing its failure does not enable it.
After enabling it, rerun **Automatic Dependency Submission**. Its token already
has the required `contents: write` permission.

## Signed releases

**Build and Publish Signed APKs** builds Release APKs for both `apt-android-7`
and `apt-android-5`, with four architecture-specific APKs and one universal APK
per variant. It verifies signatures and ZIP alignment and creates SHA-256
checksums and public certificates before uploading anything.

Configure these repository Actions secrets:

| Secret | Value |
| --- | --- |
| `TERMUX_RELEASE_KEYSTORE_BASE64` | Base64-encoded PKCS12 release keystore |
| `TERMUX_RELEASE_KEYSTORE_PASSWORD` | Keystore password; the private key uses the same password |
| `TERMUX_RELEASE_KEY_ALIAS` | Alias inside the keystore |

Use the existing private release key so that updates keep the same signature.
For the local NawafCode signing files, an authenticated GitHub CLI can set the
secrets without printing their contents:

```sh
base64 -w 0 .signing/nawafcode-termux-release.p12 | gh secret set TERMUX_RELEASE_KEYSTORE_BASE64 --repo NawafCode/termux
gh secret set TERMUX_RELEASE_KEYSTORE_PASSWORD --repo NawafCode/termux < .signing/keystore-password
printf '%s' nawafcode-termux | gh secret set TERMUX_RELEASE_KEY_ALIAS --repo NawafCode/termux
```

Publishing a GitHub release starts the workflow for that release's tag. Use a
semantic-version tag such as `v0.118.0-nawaf.1`; the leading `v` is removed for
the APK's version name. The version code remains the value in `app/build.gradle`.
Reruns replace assets with the same names and preserve the release and tag.

For a verification build, start `release.yml` manually on a selected branch.
Manual runs save signed APKs as workflow artifacts without publishing a release.
The private keystore is decoded only during signing and removed when that step
exits. Only APKs, checksums, and public certificates are uploaded.

## JitPack libraries

The JitPack workflow requests all three library modules from the current GitHub
repository, keeping the exact release tag, including its `v` prefix. HTTP errors
fail the workflow instead of being reported as successful builds. Manual runs
accept a tag or commit; the default is the selected branch's commit.

`jitpack.yml` publishes only the library modules using Java 17. The same tasks
can be checked locally with an Android SDK and the configured NDK installed:

```sh
./gradlew :terminal-emulator:publishToMavenLocal :terminal-view:publishToMavenLocal :termux-shared:publishToMavenLocal
```
