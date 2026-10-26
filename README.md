# Kang Chess

Offline chess for Android, iOS and Windows. Play bots from about 100 Elo up to
full engine strength, with premoves, flexible clocks, and an unlimited
post-game review. Everything runs on the device with embedded Stockfish 17. No
account and no network are needed.

Design notes and grading math: [ANALYSIS.md](ANALYSIS.md).

## Features

- **15 bots**, from *Pebble* (~100) to *The Grandmaster* (2850) and
  *Max Engine*. Bots below 1320 use our own error model; stronger ones use
  Stockfish's `UCI_Elo` limiter. Each bot has a rating tag and a play style.
- **Clocks**: Blitz 3, Blitz 3+2, Rapid 10, Rapid 15+10, Untimed, or Custom
  with separate player and bot controls (for example, you 5+2 against the
  bot at 1+0).
- **Premoves**: queue up to 10 moves while the bot thinks. Queued moves show
  as ghost moves. The queue clears itself if the bot's move makes the next
  premove illegal, or you can tap an empty square to clear it.
- **Game Review**: a Stockfish search for every position, with Brilliant,
  Great, Best, Excellent, Good, Book, Inaccuracy, Mistake, Miss and Blunder
  grades, accuracy per side, an eval bar, and best-move arrows.
- **Customization**: 6 board themes (Classic Wood, Tournament Green, Modern
  Charcoal, Neon Night, Glass Blue, Sunset Coral), 4 piece sets drawn in
  code, coordinates, legal-move hints, last-move highlight, and board flip.

## Run it

```powershell
flutter pub get
flutter run -d windows        # desktop
flutter run -d <android-id>   # phone (see below)
flutter test                  # unit tests (no engine needed)
flutter test integration_test/engine_soak_test.dart -d windows   # real engine
```

### Installing on an Android phone

The Android toolchain on this machine still needs two fixes (`flutter doctor`):

1. Install **Android SDK Command-line Tools**: Android Studio → SDK Manager →
   SDK Tools.
2. Run `flutter doctor --android-licenses` and accept the licenses.

Then:

```powershell
flutter build apk --release
# Copy build/app/outputs/flutter-apk/app-release.apk to the phone and open it,
# or with USB debugging enabled:
flutter install
```

To update the app, rebuild and install the new APK over the old one. Your
settings are kept. iOS builds need a Mac with Xcode.

## Layout

```
lib/src/core      dartchess helpers (UCI conversion, material), opening book
lib/src/domain    clock, premove queue, move grading, bot profiles (pure Dart)
lib/src/engine    UCI parser, serialized EngineService, Stockfish FFI transport,
                  bot move picker
lib/src/game      GameController: rules, clocks, premoves, bot turns
lib/src/review    per-position analysis and move grading
lib/src/ui        board widget, themes, piece sets, screens
```

## Licensing

Stockfish (`stockfish_chess_engine`) and `dartchess` are GPL-3.0, so this
app is GPL-3.0. If you distribute it, for example through an app store, you
must also publish the source. All piece art and board themes are original to
this project.

## Not yet verified

- Bot ratings below 1320 are estimates. Calibrating them would mean
  bot-vs-bot matches against rated anchors.
- Android and iOS builds have not been run yet: the Android toolchain is
  incomplete on this machine, and iOS needs a Mac.
