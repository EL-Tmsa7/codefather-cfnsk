# Codefather: Night of the Serial Killer

A Mafia game prototype with a Dart simulation engine and a Flutter app that runs bot matches and displays the public event log.

- `core/` contains the game engine, judge, bots, simulations, and tests.
- `app/` contains the Flutter demo and uses the engine from `core/`.

## Run the Android demo

Start an Android emulator, then run these commands from `app/`:

```powershell
flutter pub get
flutter run
```

## Test the game engine

Run these commands from `core/`:

```powershell
dart pub get
dart test
```
