<h1 align="center">
  <code>monetization</code>
</h1>
<h3 align="center">
  A wrapper around the <a href="https://webmonetization.org/">Web Monetization API</a>.
</h3>

<p align="center">
    <a href="https://pub.dev/packages/monetization">
        <img src="https://img.shields.io/pub/v/monetization?style=for-the-badge" title="Pub Version" />
    </a>
    &nbsp;
    <a href="./LICENSE">
        <img src="https://img.shields.io/badge/license-MIT-green.svg?style=for-the-badge" title="License" />
    </a>
</p>

Offer extra content and features for users who stream micro-payments — including premium features, additional content, or digital goods.

<h3 align="center">
  <a href="https://pub.dev/documentation/monetization/latest/monetization/Monetization-class.html">API Reference</a>
</h3>

## Usage

A simple usage example that initializes the monetization to a specific payment pointer:

```dart
import 'package:monetization/monetization.dart';

main() {
  var monetization = Monetization('\$pay.tomasarias.me');
}
```

You can subscribe to Web Monetization events using a `Stream`:

```dart
monetization.onPending.listen((event) {
  // Prepare to serve the monetized content
});

monetization.onStart.listen((event) {
  // Show monetized content
});

monetization.onProgress.listen((event) {
  // Do something on each micro-payment
});

monetization.onStop.listen((event) {
  // Hide monetized content
});
```


You could also write custom logic to check if a user is paying without subscribing to the streams:

```dart
Future<void> checkIfPaying() async {
  if (monetization.isMonetized) {
    // Prefer custom logic over this
    await Future.delayed(Duration(seconds: 3));
    if (monetization.isPaying) {
      // Do something...
    }
  } // Doesn't support monetization
}
```

### Probabilistic revenue sharing

Sometimes you want to share revenue across different people, to do this pass a `Map` with the payment pointers and
weights to the `Monetization.probabilistic` constructor.

This will choose one of the pointers for the entire session.

```dart
final pointers = {
  'pay.tomasarias.me/usd': 0.5,
  'pay.tomasarias.me/xrp': 0.2,
  'pay.tomasarias.me/ars': 0.3
};

var monetization = Monetization.probabilistic(pointers);
```

This will result on a 50% chance of choosing the first pointer, 20% chance of choosing the second and 30% chance of
choosing the third one.

For more information on probabilistic revenue sharing, read [this article](https://coil.com/p/sharafian/Probabilistic-Revenue-Sharing/8aQDSPsw)
by Ben Sharafian.

### Dinamically enable/disable monetization

```dart
var monetization = Monetization('\$pay.tomasarias.me'); // Monetization enabled on initialization
monetization.disable(); // Stops the monetization
monetization.enable();  // Start the monetization again with the same pointer
```

### Get the revenue from the current session

```dart
monetization.getTotal(); // 884389
monetization.getTotal(formatted: true); // 0.000884389
monetization.assetCode;  // 'XRP'
monetization.assetScale; // 9
```

## Features and bugs

Please file feature requests and bugs at the [issue tracker](https://github.com/KNawm/monetization/issues).
