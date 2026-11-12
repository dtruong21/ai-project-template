# Benchmark — does this stack pay off?

This stack exists for lower run cost, lower memory, and faster logic than the plain Flutter + Firebase one. Those are claims until measured. Measure once the first real feature works, and again before launch.

**Rules:** release builds only (`--release` / `--profile`), a real mid-range Android device (not an emulator, not a flagship), same feature on both sides, 5 runs each, report the median.

## What to compare against

Build the same feature (feedback is enough) from `../flutter/` — Firestore write through a repository — and from this stack. That is the baseline.

## 1. App size

```bash
flutter build apk --release --split-per-abi --analyze-size
flutter build ipa --release --analyze-size
```

Record the arm64 APK size and the iOS download size. Expect this stack to be slightly **larger** from the Rust library, minus the Firestore SDK it drops. If it is not smaller or equal, that is a real cost — write it down.

## 2. App memory

```bash
flutter run --profile
adb shell dumpsys meminfo <your.package.name> | grep -E "TOTAL PSS|Native Heap|Dart"   # Android
```

iOS: Xcode → Debug navigator → Memory, or Instruments → Allocations. Record after cold start (idle 10 s) and after submitting feedback 20 times.

## 3. Cold start

```bash
adb shell am force-stop <your.package.name>
adb shell am start -W -n <your.package.name>/.MainActivity | grep TotalTime
```

`RustLib.init()` adds a library load to startup. If it costs more than ~50 ms, load it lazily instead of in `main()`.

## 4. Logic speed (only if you moved heavy work to Rust)

Validation of a form is too small to measure — skip it. For real work (parsing, crypto, image processing, sync diffing) time the same input in Dart and in Rust with `Stopwatch` around the call, 1,000 iterations, release mode. Rust behind `frb(sync)` pays a bridge cost per call; for tiny functions Dart can win.

## 5. API latency

```bash
# p50 / p95 over 200 requests, from your own network
for i in $(seq 200); do
  curl -s -o /dev/null -w '%{time_total}\n' -X POST "$API_BASE_URL/v1/feedback" \
    -H "Authorization: Bearer $ID_TOKEN" -H 'Content-Type: application/json' \
    -d '{"category":"idea","body":"bench","route":"/","app_version":"1","platform":"bench"}'
done | sort -n | awk '{a[NR]=$1} END {print "p50", a[int(NR*0.5)], "p95", a[int(NR*0.95)]}'
```

Worker CPU time per request: Cloudflare dashboard → Workers → your Worker → Metrics. Known cost in the starter: `auth.rs` fetches Google's signing keys on every request — cache them if p50 is dominated by that fetch.

## 6. Run cost

After a week of real traffic: Cloudflare dashboard → Billing → usage (Workers requests, D1 rows read/written, R2 storage/operations). Compare with the same week's Firebase bill grouped by SKU (Google Cloud console → Billing → Reports). Watch D1 **rows read** — an unindexed query shows up there first.

## 7. Desktop and web size

```bash
flutter build macos --release && du -sh build/macos/Build/Products/Release/*.app
flutter build windows --release        # on Windows: size of build/windows/x64/runner/Release
flutter_rust_bridge_codegen build-web && flutter build web --release
du -sh build/web && ls -l build/web/pkg/*.wasm   # transfer size: check the Network tab, gzip/brotli on
```

Web first load is the number that matters most: the Flutter engine plus the Rust wasm both download before the app starts. Record the wasm size and time-to-interactive on a throttled connection.

## Results

| Metric | flutter (Firebase) | flutter-rust | Date / device |
|---|---|---|---|
| APK size (arm64) | | | |
| Memory after cold start (PSS) | | | |
| Cold start (TotalTime) | | | |
| macOS .app size | | | |
| Web: Rust wasm size / first load | | | |
| Feedback submit p50 / p95 | | | |
| Monthly run cost at current MAU | | | |

If this stack does not win on the metrics that matter for your app, use `../flutter/` — the extra toolchain is only worth paying for a measured gain.
