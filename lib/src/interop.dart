@JS('window')
library monetization;

import 'dart:html' show document, EventTarget;
import 'package:js/js.dart';
import 'package:js/js_util.dart';

@JS('document.monetization')
external EventTarget get monetization;

@JS('document.monetization.state')
external String get state;

@JS('console.log')
external void log(dynamic str, [dynamic str2]);

bool get supportsMonetization => hasProperty(document, 'monetization');

dynamic get(dynamic value, dynamic property) => getProperty(value, property);
