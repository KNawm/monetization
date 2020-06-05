import 'dart:html'
    show CustomEvent, EventStreamProvider, EventTarget, MetaElement, document;
import 'dart:math' as math show pow, Random;
import 'interop.dart' as js;

class Monetization {
  EventTarget _monetization;
  String _paymentPointer;
  String _assetCode;
  int _assetScale;
  String _state;
  double _total;
  /// Whether to log events to the console.
  bool debug;

  Stream<CustomEvent> _onPending;
  Stream<CustomEvent> _onStart;
  Stream<CustomEvent> _onStop;
  Stream<CustomEvent> _onProgress;
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

  /// Returns the current payment pointer.
  String get pointer => _paymentPointer;
  /// Returns the code identifying the asset's unit.
  /// For example: 'USD' or 'XRP'.
  String get assetCode => _assetCode;
  /// Returns the number of places past the decimal for the amount.
  /// For example, if you have USD with an [assetScale] of 2, then the minimum
  /// divisible unit is cents.
  int get assetScale => _assetScale;
  /// ## 'undefined'
  /// Monetization is not supported for this user.
  ///
  /// ## 'pending'
  /// Streaming has been initiated, yet first non zero packet is
  /// "pending". It will normally transition from this `state` to `started`,
  /// yet not always.
  ///
  /// ## 'started'
  /// Streaming has received a non zero packet and is still active.
  ///
  /// ## 'stopped'
  /// Streaming is inactive. This could mean a variety of things:
  /// - May not have started yet
  /// - May be paused (potentially will be resumed)
  /// - Has finished completely (and awaits another request)
  /// - The payment request was denied by user intervention
  String get state => _state ?? 'undefined';

  /// Initialize Web Monetization supplying a [paymentPointer].
  Monetization(String paymentPointer, {this.debug = false}) {
    if (js.supportsMonetization) {
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
  /// var pointers = { 'pay.tomasarias.me/usd': 0.5,
  ///                  'pay.tomasarias.me/xrp': 0.2,
  ///                  'pay.tomasarias.me/ars': 0.3 };
  /// ```
  ///
  /// For more information,
  /// see <https://coil.com/p/sharafian/Probabilistic-Revenue-Sharing/8aQDSPsw>
  factory Monetization.probabilistic(Map<String, double> paymentPointers, {debug = false}) {
    final sum = paymentPointers.values.reduce((sum, weight) => sum + weight);
    var choice = math.Random().nextDouble() * sum;
    String paymentPointer;

    for (final pointer in paymentPointers.keys) {
      final weight = paymentPointers[pointer];
      if ((choice -= weight) <= 0) {
        paymentPointer = pointer;
      }
    }

    return Monetization(paymentPointer, debug: debug);
  }

  /// Whether a user supports Web Monetization.
  bool get isMonetized => state != 'undefined';

  /// Whether a user is streaming payments.
  bool get isPaying => state == 'started';

  /// Enable Web Monetization.
  void enable() {
    _addMetaTag();
  }

  /// Disable Web Monetization.
  void disable() {
    _removeMetaTag();
  }

  /// Returns the amount received by the current [pointer] on this session.
  double getTotal({bool formatted}) {
    if (formatted) {
      return double.parse(
          (_total * math.pow(10, -_assetScale)).toStringAsFixed(_assetScale));
    }

    return _total;
  }

  void _setPaymentPointer(String paymentPointer) {
    if (paymentPointer.startsWith('\$')) {
      _paymentPointer = paymentPointer;
    } else {
      throw ArgumentError.value(paymentPointer, 'paymentPointer',
          'The payment pointer must start with "\$"');
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
      _total = 0;
    }
  }

  // Not used yet.
  /*void _updateMetaTag(String paymentPointer) {
    final metaTag = _getMetaTag();

    if (metaTag != null) {
      metaTag.setAttribute('content', paymentPointer);
      _total = 0;
    }
  }*/

  void _removeMetaTag() {
    final metaTag = _getMetaTag();

    if (metaTag != null) {
      metaTag.remove();
    }
  }

  void _monetizationPending(CustomEvent event) {
    _state = js.state;
    _debug(event);
  }

  void _monetizationStart(CustomEvent event) {
    _state = js.state;
    _debug(event);
  }

  void _monetizationStop(CustomEvent event) {
    _state = js.state;
    _debug(event);
  }

  void _monetizationProgress(CustomEvent event) {
    if (_total == 0) {
      _assetCode = event.detail['assetCode'];
      _assetScale = event.detail['assetScale'];
    }

    _total += double.parse(event.detail['amount']);
    _state = js.state;
    _debug(event);
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

  void _debug(CustomEvent event) {
    if (debug) {
      final map = _mapify(event);

      if (map['type'] == 'monetizationprogress') {
        js.log('${map.toString()}');
      } else if (map['type'] == 'monetizationpending') {
        js.log('%c${map.toString()}', 'color: yellow');
      } else if (map['type'] == 'monetizationstart') {
        js.log('%c${map.toString()}', 'color: lime');
      } else {
        // monetizationstop
        js.log('%c${map.toString()}', 'color: red');
      }
    }
  }
}
