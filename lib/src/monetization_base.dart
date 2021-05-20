import 'dart:convert' show base64Encode, jsonEncode, jsonDecode, utf8;
import 'dart:html'
    show CustomEvent, EventStreamProvider, EventTarget, MetaElement, document;
import 'dart:math' as math show pow, Random;
import 'package:http/http.dart' as http;
import 'interop.dart' as js;

class Monetization {
  // Monetization DOM object
  EventTarget _monetization;
  // Current payment pointer stored in memory
  String _paymentPointer;
  String _assetCode;
  int _assetScale;
  String _state;
  double _total;
  // Monetization events
  Stream<CustomEvent> _onPending;
  Stream<CustomEvent> _onStart;
  Stream<CustomEvent> _onStop;
  Stream<CustomEvent> _onProgress;
  // Vanilla-related
  String _vanillaAuth;
  double _vanillaRate;
  double _vanillaTotal;
  http.Client _vanillaClient;
  http.Client _receiptVerifier;
  bool get _vanilla => _vanillaAuth != null;

  /// Returns whether the meta tag is set to receive payments.
  bool get enabled => _getMetaTag() != null;

  /// Returns whether the user supports Web Monetization.
  bool get isMonetized => state != 'undefined';

  /// Returns whether the user is streaming payments.
  bool get isPaying {
    if (_vanilla) {
      // Is paying if the rate from the last payment proof is greater than 0.
      return _vanillaRate > 0;
    }

    return state == 'started';
  }

  /// Returns the current payment pointer.
  ///
  /// To check if a meta tag with this pointer is set use [enabled].
  String get pointer => _paymentPointer;

  /// Returns the code identifying the asset's unit.
  ///
  /// For example: 'USD' or 'XRP'.
  String get assetCode => _assetCode;

  /// Returns the number of places past the decimal for the amount.
  ///
  /// For example, if you have USD with an [assetScale] of 2, then the minimum
  /// divisible unit is cents.
  int get assetScale => _assetScale;

  /// Returns the monetization state provided by the browser.
  ///
  /// **`undefined`**:
  /// Monetization is not supported for this user.
  ///
  /// **`pending`**:
  /// Streaming has been initiated, yet first non zero packet is
  /// "pending". It will normally transition from this `state` to `started`,
  /// yet not always.
  ///
  /// **`started`**:
  /// Streaming has received a non zero packet and is still active.
  ///
  /// **`stopped`**:
  /// Streaming is inactive. This could mean a variety of things:
  /// - May not have started yet
  /// - May be paused (potentially will be resumed)
  /// - Has finished completely (and awaits another request)
  /// - The payment request was denied by user intervention
  String get state => _state ?? 'undefined';

  /// Stream that tracks 'monetizationpending' events.
  ///
  /// This event fires when Web Monetization is enabled.
  Stream<Map> onPending;

  /// Stream that tracks 'monetizationstart' events.
  ///
  /// This event fires when Web Monetization has started actively paying.
  Stream<Map> onStart;

  /// Stream that tracks 'monetizationstop' events.
  ///
  /// This event fires when Web Monetization has stopped.
  Stream<Map> onStop;

  /// Stream that tracks 'monetizationprogress' events.
  ///
  /// This event fires when Web Monetization has streamed a payment.
  Stream<Map> onProgress;

  /// Returns whether to log events to the console.
  bool debug;

  /// Returns whether the receipt verifier service is enabled.
  bool receipts;

  /// Initialize Web Monetization supplying a [paymentPointer].
  factory Monetization(String paymentPointer, {receipts = true}, {debug = false}) {
    return Monetization._(paymentPointer, receipts, debug);
  }

  Monetization._(String paymentPointer, this.receipts, this.debug, [String auth]) {
    if (js.supportsMonetization) {
      _vanillaAuth = auth;
      _vanillaRate = 0;
      _setPaymentPointer(paymentPointer);
      _monetization = js.monetization;
      _state = js.state;
      _addMetaTag();
      _addEventHandlers();
    }
  }

  /// Initialize Web Monetization supplying a Map of payment pointers with their
  /// respective weights.
  ///
  /// For example:
  /// ```
  /// var pointers = { r'$pay.tomasarias.me/usd': 0.5,
  ///                  r'$pay.tomasarias.me/xrp': 0.2,
  ///                  r'$pay.tomasarias.me/ars': 0.3 };
  /// ```
  ///
  /// For more information,
  /// see <https://coil.com/p/sharafian/Probabilistic-Revenue-Sharing/8aQDSPsw>
  factory Monetization.probabilistic(Map<String, double> paymentPointers,
      {receipts = true}, {debug = false}) {
    var shares = [];

    for (MapEntry e in paymentPointers.entries) {
      final pointer = e.key;
      final weight = e.value;

      if (_validatePaymentPointer(pointer)) {
        shares.add([pointer, weight, ""]);
      } else {
        throw ArgumentError.value(paymentPointers, 'paymentPointers', 'The pointer: $pointer is not a valid payment pointer.');
      }
    }

    final base64Url = base64UrlEncode(utf8.encode(jsonEncode(shares)))

    return Monetization._('\$webmonetization.org/api/revshare/pay/$base64Url', debug);
  }

  /// Initialize Web Monetization using Vanilla.
  ///
  /// For more information,
  /// see <https://vanilla.so>
  factory Monetization.vanilla(String clientId, String clientSecret, {receipts = false}, {debug = false}) {
    final auth = base64Encode(utf8.encode('$clientId:$clientSecret'));

    return Monetization._('\$wm.vanilla.so/pay/$clientId', false, receipts, auth);
  }

  /// Enable Web Monetization.
  void enable() {
    _addMetaTag();
  }

  /// Disable Web Monetization.
  void disable() {
    _removeMetaTag();
  }

  /// Returns the amount received by the current [pointer] on this session.
  ///
  /// Keep in mind that this number resets every time that `onStart` fires.
  ///
  /// Pass `formatted: false` if you want the "raw" total (without accounting for the scale of the asset).
  double getTotal({bool formatted = true}) {
    if (formatted) {
      return double.parse(
          (_total * math.pow(10, -_assetScale)).toStringAsFixed(_assetScale));
    }

    return _total;
  }

  /// Returns the current payment rate per second from Vanilla's proof of
  /// payment on "raw" format (disregarding the asset scale).
  double getVanillaRate() => _vanillaRate;

  /// Returns the total amount received from Vanilla's proof of payment in "raw"
  /// format (disregarding the asset scale).
  ///
  /// This total SHOULD be the same that you get from `getTotal(formatted: false)`
  /// but sometimes there will be a small discrepancy.
  ///
  /// Keep in mind this total is only from the last requestId and will reset
  /// if the requestId changes.
  double getVanillaTotal() => _vanillaTotal;

  bool _validatePaymentPointer(string paymentPointer) => Uri.tryParse()?.isAbsolute ?? false;

  void _setPaymentPointer(String paymentPointer) {
    if (paymentPointer.startsWith('\$') || paymentPointer.startsWith('https://')) {
      if (receipts) {
        final pointer = Uri.encodeComponent(paymentPointer);
        _paymentPointer = '\$webmonetization.org/api/receipts/$pointer';
      } else {
        _paymentPointer = paymentPointer;
      }
    } else {
      throw ArgumentError.value(paymentPointer, 'paymentPointer',
          'The payment pointer must start with "\$" or "https://"');
    }
  }

  MetaElement _getMetaTag() {
    return document.head.querySelector('meta[name="monetization"]');
  }

  void _addMetaTag() {
    if (_getMetaTag() == null) {
      final metaTag = MetaElement();
      metaTag.name = 'monetization';
      metaTag.content = _paymentPointer;
      document.head.append(metaTag);
    } else {
      _updateMetaTag(_paymentPointer);
    }
  }

  void _updateMetaTag(String paymentPointer) {
    final metaTag = _getMetaTag();

    if (metaTag != null) {
      metaTag.setAttribute('content', paymentPointer);
    }
  }

  void _removeMetaTag() {
    final metaTag = _getMetaTag();

    if (metaTag != null) {
      metaTag.remove();
    }
  }

  Future<String> _proof(String requestId, {receipt = null}) async {
    if (_vanilla) {
      Map<String, dynamic> proof;
      final query = '''
      {
        proof(requestId: "$requestId") {
          rate
          total
        }
      }
      ''';

      final headers = {
        'Content-type': 'application/json',
        'Authorization': 'Basic $_vanillaAuth'
      };
      try {
        final response = await _vanillaClient.post(
            'https://wm.vanilla.so/graphql',
            body: jsonEncode({'query': query}),
            headers: headers);

        proof = jsonDecode(response.body);
        _vanillaRate = proof['data']['proof']['rate'];
        _vanillaTotal = proof['data']['proof']['total'];

        return proof.toString();
      } catch (e, s) {
        if (debug) {
          js.log('Error getting payment proof:\n$e\n$s');
        }
      }
    } else if (receipts && receipt != null) {
      final headers = {
        'Content-type': 'application/json'
      };

      try {
        final response = await _receiptVerifier.post(
            'https://webmonetization.org/api/receipts/verify',
            body: jsonEncode(receipt),
            headers: headers);

        proof = jsonDecode(response.body);

        return proof.toString();
      } catch (e, s) {
        if (debug) {
          js.log('Error getting payment proof:\n$e\n$s');
        }
      }
    }

    return null;
  }

  Future<void> _monetizationPending(CustomEvent event) async {
    _state = js.state;
    _debug(event);
  }

  Future<void> _monetizationStart(CustomEvent event) async {
    _receiptVerifier = http.Client();
    _total = 0;
    _vanillaClient = http.Client();
    _state = js.state;
    _debug(event);
  }

  Future<void> _monetizationStop(CustomEvent event) async {
    _vanillaClient.close();
    _vanillaRate = 0;
    _state = js.state;
    _debug(event);
  }

  Future<void> _monetizationProgress(CustomEvent event) async {
    final requestId = event.detail['requestId'];
    final receipt = event.detail['receipt'];

    if (_total == 0) {
      _assetCode = event.detail['assetCode'];
      _assetScale = event.detail['assetScale'];
    }

    _total += double.parse(event.detail['amount']);
    _state = js.state;
    _debug(event, await _proof(requestId, receipt));
  }

  void _addEventHandlers() {
    _onPending = const EventStreamProvider<CustomEvent>('monetizationpending')
        .forTarget(_monetization);
    _onPending.listen((event) {
      _monetizationPending(event);
    });
    onPending = _onPending.map((CustomEvent event) => _mapify(event));

    _onStart = const EventStreamProvider<CustomEvent>('monetizationstart')
        .forTarget(_monetization);
    _onStart.listen((event) {
      _monetizationStart(event);
    });
    onStart = _onStart.map((CustomEvent event) => _mapify(event));

    _onStop = const EventStreamProvider<CustomEvent>('monetizationstop')
        .forTarget(_monetization);
    _onStop.listen((event) {
      _monetizationStop(event);
    });
    onStop = _onStop.map((CustomEvent event) => _mapify(event));

    _onProgress = const EventStreamProvider<CustomEvent>('monetizationprogress')
        .forTarget(_monetization);
    _onProgress.listen((event) {
      _monetizationProgress(event);
    });
    onProgress = _onProgress.map((CustomEvent event) => _mapify(event));
  }

  Map<String, dynamic> _mapify(CustomEvent event) {
    final map = <String, dynamic>{
      'type': js.get(event, 'type'),
      'timeStamp': js.get(event, 'timeStamp'),
    };
    map.addAll((event.detail as Map).cast<String, dynamic>());

    return map;
  }

  void _debug(CustomEvent event, [String proof]) {
    if (debug) {
      final map = _mapify(event);

      if (map['type'] == 'monetizationprogress') {
        js.log('${map.toString()}');
      } else if (map['type'] == 'monetizationpending') {
        js.log('%c${map.toString()}', 'color: yellow');
      } else if (map['type'] == 'monetizationstart') {
        js.log('%c${map.toString()}', 'color: lime');
      } else {
        js.log('%c${map.toString()}', 'color: red');
      }

      if (proof != null) {
        js.log(proof);
      }
    }
  }
}
