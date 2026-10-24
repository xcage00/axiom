# Axiom

Axiom is a Flutter messaging app backed by Supabase, with optional audio/video calling through a separate WebSocket signaling service.

## Requirements

- Flutter stable and Dart version allowed by `pubspec.yaml`
- A Supabase project with the schema and policies described in [production readiness](docs/production-readiness.md)
- Node.js 18 or later to run the optional signaling server
- Android Studio / Android SDK for Android builds; Xcode on macOS for iOS builds

## Configure and run

Provide the existing Supabase project URL and **publishable/anon client key** at build time. These values configure the public client and do not replace Row Level Security. Never put a service-role key in the app or signaling process.

```sh
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_OR_ANON_KEY
```

PowerShell accepts the same Flutter flags on one line:

```powershell
flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_OR_ANON_KEY
```

Calling additionally requires a deployed signaling URL and build-time configuration:

```sh
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_OR_ANON_KEY \
  --dart-define=AXIOM_SIGNALING_URL=wss://calls.example.com
```

An unset or invalid calling URL disables the call connection with an in-app message. Release builds accept `wss://` only. A debug build can use `ws://` on a trusted development network. `localhost` refers to the device itself; use a reachable development host for physical devices.

## Signaling service

From the repository root:

```sh
npm install
SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_OR_ANON_KEY \
npm start
```

In PowerShell, set the environment values before starting the service:

```powershell
$env:SUPABASE_URL = 'https://YOUR_PROJECT.supabase.co'
$env:SUPABASE_ANON_KEY = 'YOUR_PUBLISHABLE_OR_ANON_KEY'
npm start
```

The signaling process validates the access token with Supabase Auth and checks call membership through the caller's Supabase permissions before joining a room. Put it behind a TLS-terminating reverse proxy and expose only `wss://` to production clients. Configure proxy timeouts for long-lived WebSocket connections, connection/rate limits, monitoring, and a process supervisor. The app's database RLS remains the authority; the signaling check is an additional gate, not a replacement.

## Quality checks

```sh
dart format lib test
flutter analyze
flutter test
flutter build apk
```

Run checks on the same Flutter SDK used for release. This repository's existing codebase currently reports analyzer lint findings; see the latest task report before treating it as release-ready.

## Before production

Review [the launch checklist](docs/production-readiness.md), including Supabase RLS and Storage policies, real-device call connectivity, privacy disclosures, and release signing. No live database policies are changed by this repository setup.
