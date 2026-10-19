
# Merge all code files under lib folder to a single txt file for using it in AI tools
find lib -name "*.dart" -type f -exec cat {} + > all_current_code.txt
find chat -name "*.dart" -type f -exec cat {} + > all_chat_code.txt

----
# Build the web app
flutter build web --wasm --base-href "/bar_app/" --dart-define-from-file=env/prod.json
# Deploy to gh-pages branch

- copy web folder to somewhere

## first time
git checkout --orphan github-page 

## future
git checkout github-page 

- delete all content
- paste content from recently copied web folder

git add .
git commit -m "Deploy to GitHub Pages"
git push origin github-page --force
git checkout main

----


find android \
\( -name "*.kts" -o -name "*.gradle" -o -name "*.properties" -o -name "*.xml" -o -name "*.java" -o -name "*.kt" \) \
-type f \
-not -path "*/build/*" \
-not -path "*/.gradle/*" \
-not -path "*/.kotlin/*" \
-exec sh -c '
for file do
  echo "\n===================="
  echo "FILE: $file"
  echo "===================="
  cat "$file"
done
' sh {} + > android_all_current_code.txt

# Flutter clean
flutter clean; flutter pub get;cd ios; pod install; pod update; cd ..;

## ios clean overall
flutter clean
rm -rf build
rm -rf .dart_tool
rm -rf ios/Pods
rm -rf ios/Podfile.lock
rm -rf ~/Library/Developer/Xcode/DerivedData
flutter pub get
cd ios
pod install
cd ..
flutter precache --ios

# Deploy Commands

## Environment files
Place these in `env/` folder (gitignored):
  env/.env.staging
  env/.env.prod

Both must contain: ENV, BASE_URL, API_KEY, SUPABASE_URL, SUPABASE_ANONKEY

---

## Flutter only (no Shorebird)

```bash
# Debug run
flutter run --dart-define=ENV=staging
flutter run --dart-define=ENV=prod

# Build APK
flutter build apk --release --dart-define=ENV=staging
flutter build apk --release --dart-define=ENV=prod

# Build App Bundle
flutter build appbundle --release --dart-define=ENV=staging
flutter build appbundle --release --dart-define=ENV=prod

# Build iOS
flutter build ipa --dart-define=ENV=staging
flutter build ipa --dart-define=ENV=prod
```

---

## Shorebird — Release (full store build)

Use when: new plugins, native changes, version bump, first deploy.

```bash
# Android — Staging
shorebird release android \
  --flavor staging \
  --flutter-version=3.41.6 \
  -- --dart-define=ENV=staging

# Android — Prod
shorebird release android \
  --flavor prod \
  --flutter-version=3.41.6 \
  -- --dart-define=ENV=prod

# iOS — Staging
shorebird release ios \
  --flavor staging \
  --flutter-version=3.41.6 \
  -- --dart-define=ENV=staging

# iOS — Prod
shorebird release ios \
  --flavor prod \
  --flutter-version=3.41.6 \
  -- --dart-define=ENV=prod

# open ios archive folder (from root)
open build/ios/archive
```



After release: upload the generated .aab / .ipa to Play Store / App Store as usual.

---

## Shorebird — Patch (OTA, no store review)

Use when: Dart-only changes (bug fixes, UI, logic, API calls).

Always patch staging first, verify, then patch prod.

```bash
# Android — Staging
shorebird patch android \
  --flavor staging \
  -- --dart-define=ENV=staging

# iOS — Staging
shorebird patch ios \
  --flavor staging \
  -- --dart-define=ENV=staging

shorebird patch --platforms=ios --flavor=prod --release-version=1.1.17+57 -- --dart-define=ENV=prod
shorebird patch --platforms=ios --flavor=staging --release-version=1.1.13+53 -- --dart-define=ENV=staging
shorebird patch --platforms=android --flavor=prod --release-version=1.11.17+52 -- --dart-define=ENV=prod
shorebird patch --platforms=android --flavor=staging --release-version=1.0.11+27 -- --dart-define=ENV=staging

# open ios archive folder (from root)
open build/ios/archive

# ✅ Test on staging devices, then:


# Android — Prod
shorebird patch android \
  --flavor prod \
  -- --dart-define=ENV=prod

# iOS — Prod
shorebird patch ios \
  --flavor prod \
  -- --dart-define=ENV=prod
```

---

## What can / cannot be patched

| ✅ Patchable (dart-only)         | ❌ Needs new release            |
|----------------------------------|--------------------------------|
| Bug fixes, UI changes            | New Flutter plugins            |
| Business logic, API calls        | Native Android/iOS code        |
| State management, navigation     | Flutter version upgrade        |
| Dart package updates (pure-dart) | .env value changes (baked in)  |
| AppController, auth logic        | App icon, splash, permissions  |

> ⚠️  ENV values (SUPABASE_URL, API_KEY, etc.) are loaded from asset
>     files baked into the binary at release time. Changing them
>     requires a new `shorebird release` + store upload.