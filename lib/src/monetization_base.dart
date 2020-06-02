import 'dart:html'
    show CustomEvent, EventStreamProvider, EventTarget, MetaElement, document;
import 'dart:math' as math show pow;
import 'interop.dart' as js;

class Monetization {
  EventTarget _monetization;
  String _paymentPointer;
  String _assetCode;
  int _assetScale;
  String _state;
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
  String get assetCode => _assetCode;
  int get assetScale => _assetScale;
  String get state => _state ?? 'undefined';

  Monetization(String paymentPointer, {this.debug = false}) {
    if (js.supportsMonetization) {
      _setPaymentPointer(paymentPointer);
      _monetization = js.monetization;
      _total = 0;
      _addEventHandlers();
      _addMetaTag();
    }
  }

  void enable() {
    _addMetaTag();
  }

  void disable() {
    _removeMetaTag();
  }

  double total({bool formatted}) {
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

  MetaElement _getMetaTag() => document.head.querySelector('meta[name="monetization"]');

  void _addMetaTag() {
    if (_getMetaTag() == null) {
      final metaTag = MetaElement();
      metaTag.name = 'monetization';
      metaTag.content = _paymentPointer;
      document.head.append(metaTag);
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
      } else { // monetizationstop
        js.log('%c${map.toString()}', 'color: red');
      }
    }
  }
}
