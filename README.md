# gha-indie-worker-flutter

Flutter for mobile, desktop, and mobile web. No React. UI lives in `lib/src/`.

The home screen consumes the pinned Dart client and renders its exhaustive
RxDart health state. Refreshes cancel stale request streams; HTTP is isolated
in `HttpHealthRequest`, while widgets depend only on immutable state values.
