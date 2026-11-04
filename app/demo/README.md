# Demo build

`.github/workflows/demo.yml` builds **Realbrain demo**: the real V5 screens on the sample archive in
`lib/preview/sample.dart`, with no Firebase, sign-in or backend. It installs next to the real app
(package `com.reelbrain.reelbrain.demo`, no share targets) and every control works on the sample
data, which resets when the app restarts.

The workflow adds `demo/img/` to the app's assets only for that build; the shipped app never
contains these photos. They are resized from the
[flutter_gallery_assets](https://pub.dev/packages/flutter_gallery_assets) package
(BSD-3-Clause, see `img/LICENSE`).

Build it locally the same way:

```bash
REALBRAIN_DEMO=1 flutter build apk --release --split-per-abi -t lib/preview/main_preview.dart --dart-define=RB_DEMO=true
```

(with `demo/img/` listed under `flutter: assets:` in `pubspec.yaml` and a `google-services.json`
for the `.demo` package; the workflow does both).
