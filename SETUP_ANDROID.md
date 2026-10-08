# Release setup

The Android project, permissions and signing are prepared automatically by
GitHub Actions (see `tool/prepare_android.py`). Nothing has to be edited by hand.

Only one thing is needed once: a signing key stored as GitHub secrets.

## 1. Create the signing key (once)

Run in any folder (keytool comes with Android Studio / the JDK):

```
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias pockettally
```

Back up `upload-keystore.jks` and its passwords somewhere private.
Never commit them. Every release must be signed with this same key,
otherwise in-app updates will not install over the old version.

## 2. Add GitHub secrets

Repo -> Settings -> Secrets and variables -> Actions -> New repository secret:

| Secret | Value |
| --- | --- |
| `KEYSTORE_BASE64` | the keystore file as base64 |
| `KEYSTORE_PASSWORD` | the keystore password |
| `KEY_PASSWORD` | the key password (same as above if you pressed Enter) |
| `KEY_ALIAS` | `pockettally` |

On Windows PowerShell, copy the base64 text with:

```
[Convert]::ToBase64String([IO.File]::ReadAllBytes("upload-keystore.jks")) | Set-Clipboard
```

## 3. Release

```
git tag v0.1.0
git push origin v0.1.0
```

GitHub Actions builds the signed APK and attaches it to a GitHub release.
Each new release needs a higher version in `pubspec.yaml` and a matching tag.
