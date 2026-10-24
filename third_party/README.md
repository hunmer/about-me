# CI source dependencies

`flutter_live2d-7e829b6.tar.gz` contains the runtime source and bundled native
libraries from `hunmer/flutter_live2d` at commit
`7e829b67a6db220c3a50d857c09aeb69c9b068be`.
The upstream repository is private, so CI restores this snapshot without a
personal access token. Local development keeps using `../flutter_live2d-main`.
The archive includes the upstream `LICENSE` and `NOTICES`.

To refresh from the sibling checkout, replace the revision and archive filename
below, then update `.github/actions/setup-live2d/action.yml`:

```sh
git -C "../flutter_live2d-main" archive --format=tar.gz \
  --output="../Aboutme/third_party/flutter_live2d-7e829b6.tar.gz" \
  "7e829b67a6db220c3a50d857c09aeb69c9b068be" \
  "android" "ios" "lib" "macos" "windows" "assets/web" \
  "LICENSE" "NOTICES" "README.md" "pubspec.yaml"
```
