import 'dart:html' show CustomEvent, EventStreamProvider, EventTarget, MetaElement, document, window;
import 'dart:math' as math show pow;
import 'interop.dart' as js;

class Monetization {
  EventTarget _monetization;
  String _paymentPointer;
  List<Map> _payments;
  String _assetCode;
  int _assetScale;
  double _total;
  bool debug;

  Stream<CustomEvent> _onPending;
  Stream<CustomEvent> _onStart;
  Stream<CustomEvent> _onStop;
  Stream<CustomEvent> _onProgress;
  Stream<Map> onPending;
  Stream<Map> onStart;
  Stream<Map> onStop;
  Stream<Map> onProgress;

  String get pointer => _paymentPointer;
  List<Map> get payments => _payments;
  String get assetCode => _assetCode;
  int get assetScale => _assetScale;
  String get state => js.state;

  Monetization(String paymentPointer, {this.debug = false}) {
    if (js.supportsMonetization) {
      _monetization = js.monetization;
      _payments = <Map>[];
      _total = 0;
      setPaymentPointer(paymentPointer);
      _addEventHandlers();
      addMetaTag();
    } else {
      throw MonetizationException('Monetization polyfill not found.');
    }
  }

  void _monetizationPending(CustomEvent event) async {
    _debug(event);
  }

  void _monetizationStart(CustomEvent event) {
    _debug(event);
  }

  void _monetizationStop(CustomEvent event) {
    _debug(event);
  }

  Map _monetizationProgress(CustomEvent event) {
    final details = event.detail;
    final payment = {
      'amount': double.parse(details['amount']),
      'assetCode': details['assetCode'],
      'assetScale': details['assetScale'],
      'paymentPointer': details['paymentPointer'],
      'requestId': details['requestId']
    };

    if (_total == 0) {
      _assetCode = payment['assetCode'];
      _assetScale = payment['assetScale'];
    }

    _total += payment['amount'];
    _debug(event);

    return payment;
  }

  void _addEventHandlers() {
    _onPending = const EventStreamProvider<CustomEvent>('monetizationpending').forTarget(_monetization);
    _onPending.listen((event) { _monetizationPending(event); });
    onPending = _onPending.map((CustomEvent event) => _mapify(event));

    _onStart = const EventStreamProvider<CustomEvent>('monetizationstart').forTarget(_monetization);
    _onStart.listen((event) { _monetizationStart(event); });
    onStart = _onStart.map((CustomEvent event) => _mapify(event));

    _onStop = const EventStreamProvider<CustomEvent>('monetizationstop').forTarget(_monetization);
    _onStop.listen((event) { _monetizationStop(event); });
    onStop = _onStop.map((CustomEvent event) => _mapify(event));

    _onProgress = const EventStreamProvider<CustomEvent>('monetizationprogress').forTarget(_monetization);
    _onProgress.listen((event) { _monetizationProgress(event); });
    onProgress = _onProgress.map((CustomEvent event) => _mapify(event));
  }

  MetaElement _getMetaTag() => document.head.querySelector('meta[name="monetization"]');

  void addMetaTag() {
    if (_getMetaTag() == null) {
      final metaTag = MetaElement();
      metaTag.name = 'monetization';
      metaTag.content = _paymentPointer;
      document.head.append(metaTag);
    }
  }

  void updateMetaTag(String paymentPointer) {
    final metaTag = _getMetaTag();

    if (metaTag != null) {
      metaTag.setAttribute('content', paymentPointer);
    }
  }

  void removeMetaTag() {
    final metaTag = _getMetaTag();

    if (metaTag != null) {
      metaTag.remove();
    }
  }

  void setPaymentPointer(String paymentPointer) {
    if (paymentPointer.startsWith('\$')) {
      _paymentPointer = paymentPointer;
    } else {
      throw ArgumentError.value(paymentPointer, 'paymentPointer', 'The payment pointer should start with \$');
    }
  }

  double total({bool formatted}) {
    if (formatted) {
      return double.parse((_total * math.pow(10, -_assetScale)).toStringAsFixed(_assetScale));
    }

    return _total;
  }

  Map<String, dynamic> _mapify(CustomEvent event) {
    final map = <String, dynamic>{'type': js.get(event, 'type'), 'timeStamp': js.get(event, 'timeStamp')};
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
      } else { // monetizationstop
        js.log('%c${map.toString()}', 'color: red');
      }
    }
  }
}

class MonetizationException implements Exception {
  String message;
  MonetizationException(this.message);
}
