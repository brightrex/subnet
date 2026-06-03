# Publishing Subnet on GitHub

This guide prepares the repository so users can download Subnet from GitHub Releases.

## 1. Create the GitHub Repository

On GitHub, create a new repository:

```text
Repository name: subnet
Description: Hidden local social network for shared WiFi networks.
Visibility: Public
```

Recommended URL:

```text
https://github.com/brightrex/subnet
```

## 2. Push the Flutter Project

Run these commands from the project folder:

```bash
git init
git add .
git commit -m "Initial release"
git branch -M main
git remote add origin https://github.com/brightrex/subnet.git
git push -u origin main
```

## 3. Create the First Release

On GitHub:

1. Open the repository.
2. Click **Releases**.
3. Click **Create a new release**.
4. Use this tag:

```text
v1.0.0
```

5. Use this title:

```text
Subnet v1.0.0
```

6. Paste the contents of:

```text
docs/release-notes/v1.0.0.md
```

## 4. Upload the APK

Upload this file to the release assets area:

```text
release_assets/Subnet-v1.0.0.apk
```

After publishing, users can download the latest APK from:

```text
https://github.com/brightrex/subnet/releases/latest
```

## 5. Versioning

Use semantic version tags:

```text
v1.0.0
v1.0.1
v1.1.0
v1.2.0
v2.0.0
```

Do not overwrite old release APKs. Create a new tag and new release for every public build.

## 6. Automatic Builds

This repo includes:

```text
.github/workflows/flutter.yml
```

When pushed to GitHub, it will:

- Install Flutter
- Run `flutter pub get`
- Run `flutter analyze`
- Run `flutter test`
- Build a release APK
- Upload the APK as a workflow artifact

When you push a version tag like `v1.0.1`, the workflow can also attach the APK
to a GitHub Release.

## 7. Public Release Checklist

Before sharing publicly, test:

- Two Android phones
- Same WiFi network
- Space creation
- Space discovery from another phone
- Messaging both ways
- Ghost Mode toggle
- Report action
- WiFi permissions
- Network disconnect/reconnect

LAN apps depend heavily on router settings. Some real-world networks block multicast or peer-to-peer device traffic.
