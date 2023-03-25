# xrpl-text-to-speech

An example application for consuming the example Dhali text-2-speech asset directly from the Dhali marketplace.

## Pre-requisites

* Install [Flutter](https://docs.flutter.dev/get-started/install)
```bash
$ flutter --version
Flutter 3.9.0-1.0.pre.161 • channel master • https://github.com/flutter/flutter.git
Framework • revision f9ad42a32d (9 days ago) • 2023-03-11 03:32:04 +0000
Engine • revision e9ca7b2c45
Tools • Dart 3.0.0 (build 3.0.0-313.0.dev) • DevTools 2.22.2
```
* A web-cam enabled device.

## Running

* Start the app:
```
flutter run
```
* Activate your wallet using a BIP-39 compatible collection of words (see, [here](https://iancoleman.io/bip39/))
    - All subsequent re-activications will add more test XRP to the same account.
    - You can view your account on the XRPL testnet [here](https://testnet.xrpl.org/)
* Take a photo with the app
    - if the Dhali asset is being cold started, this may take a ~10 seconds and timeout. A retry should then work.
