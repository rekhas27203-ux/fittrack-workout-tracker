# FitTrack — Fitness & Workout Tracker (Android)

A dark-mode, gym-friendly workout tracker with **video-guided sets** and a **countdown timer that is synchronised with the tutorial video**: press Start once, the timer and the YouTube video begin together, the video loops if it is shorter than the set, and playback stops the moment the timer reaches `00:00`.

Installable APK: **[`dist/FitTrack.apk`](dist/FitTrack.apk)** (signed with a debug key, `minSdk 21`, `targetSdk 34`).

---

## What it does

| Screen | Behaviour |
|---|---|
| **Exercise selection** | 26 exercises across Chest, Back, Legs, Arms, Core, Cardio and Full Body, with category chips and a live search bar. |
| **Configuration** | Sets, Reps, Duration per set, Rest between sets and an optional pinned YouTube video ID. **Save to My Workout Plan**. |
| **My Workout Plan** | Every saved exercise with its sets × reps × duration, plus start and delete actions. Stored in `localStorage`, so it survives app restarts and works offline. |
| **Active workout player** | Embedded YouTube tutorial (IFrame Player API), a large ring countdown, set counter, rest countdown, and automatic video pause at `00:00`. |
| **Settings** | YouTube Data API v3 key, stored only on the device. |

Everything is a single self-contained HTML/JS/CSS file (`app/src/main/assets/index.html`) rendered inside a WebView, wrapped in a tiny native shell (`MainActivity.java`, no third-party libraries).

## Copyright-safe video

When a workout has no pinned video, the app queries the **YouTube Data API v3** with
`type=video`, `videoEmbeddable=true`, `videoLicense=creativeCommon` and `safeSearch=strict`,
then embeds the first result through the IFrame Player API. Found IDs are cached per exercise,
so the API is called once per exercise. Playback control (play / pause / loop / seek) goes through
the IFrame Player API, never through scraping.

## Where to put the YouTube API key

Pick either option:

1. **In the app (no rebuild):** open **Settings → YouTube Data API v3 key**, paste the key, tap **Save**. It is kept in `localStorage` on the device.
2. **Baked into the build:** open `app/src/main/assets/index.html` and set the constant at the top of the script:

   ```js
   const DEFAULT_API_KEY = "AIza...your key here...";
   ```

Get a key from **Google Cloud Console → APIs & Services → enable "YouTube Data API v3" → Credentials → Create API key**. Restrict it to the YouTube Data API for safety. Without a key the app still runs; the player shows a *Search on YouTube* button instead of an inline video.

## Build it yourself

**Android Studio / Gradle**

```bash
# open the folder in Android Studio and press Run, or:
gradle assembleDebug
# APK at app/build/outputs/apk/debug/app-debug.apk
```

**Command line only (no Gradle, no dependency downloads)**

```bash
JAVA_HOME=/path/to/jdk17 ANDROID_HOME=/path/to/android-sdk ./scripts/build_apk.sh
# APK at dist/FitTrack.apk
```

The CLI script uses `aapt2`, `javac`, `d8`, `zipalign` and `apksigner` from the SDK build-tools, and signs with a generated debug keystore.

## Install on a phone

1. Copy `dist/FitTrack.apk` to the device (or download it from this repository).
2. Open it and allow **Install unknown apps** for your file manager / browser when prompted.
3. Launch **FitTrack**.

The APK is debug-signed, which is fine for personal use. For Play Store distribution, generate a release keystore and build a release variant.

## Project structure

```
app/
  build.gradle
  src/main/
    AndroidManifest.xml
    java/com/rekha/fitnesstracker/MainActivity.java   # WebView shell, fullscreen video, back handling
    assets/index.html                                 # the whole UI + timer + YouTube logic
    res/values/{strings,styles}.xml
    res/mipmap-*/ic_launcher.png                      # launcher icons
dist/FitTrack.apk                                     # ready-to-install build
scripts/build_apk.sh                                  # SDK-only build (no Gradle)
```

## How the timer stays in sync with the video

- `Start` calls `player.playVideo()` and records `endAt = Date.now() + remaining * 1000`.
- A 200 ms tick recomputes the remaining seconds from the clock (drift-free), repaints the ring and the `mm:ss` label.
- `onStateChange` → `ENDED` seeks back to `0` and replays while the timer is still running, so a short clip loops for a long set.
- At `00:00` the tick calls `player.pauseVideo()` immediately, then advances to rest or to the next set.

## Tech notes

- Page origin: the HTML is loaded with `loadDataWithBaseURL("https://appassets.androidplatform.net/", …)` so the WebView exposes a real HTTPS origin — required by the YouTube IFrame API.
- `setMediaPlaybackRequiresUserGesture(false)` lets the video start from the timer's Start button.
- `FLAG_KEEP_SCREEN_ON` keeps the screen awake during a workout.
- No analytics, no ads, no network calls except YouTube.
