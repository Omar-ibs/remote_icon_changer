## 0.1.0

* First version: switch between app icons bundled in the app, from the user's
  choice or a remote config (remote wins), on iOS and Android.
* Remote config is checked on start and on resume, throttled by `checkEvery`,
  and the last known assignment is kept through network failures.
* Android applies the change when the app goes to the background.
