import 'package:monetization/monetization.dart';
import 'package:test/test.dart';

void main() {
  group('Probabilistic', () {
    Monetization wm;
    int a, b, c;

    final pointers = { 'pay.tomasarias.me/usd': 0.5,
      'pay.tomasarias.me/xrp': 0.2,
      'pay.tomasarias.me/ars': 0.3
    };

    setUp(() {
      for (int i = 0; i < 5000; i++) {
        wm = Monetization.probabilistic(pointers);

        if (wm.pointer == pointers.keys.elementAt(0)) {
          a++;
        } else if (wm.pointer == pointers.keys.elementAt(1)) {
          b++;
        } else if (wm.pointer == pointers.keys.elementAt(2)) {
          c++;
        }
      }
    });

    test('Simulation', () {
      expect(a / 5000, closeTo(pointers[0], 0.1));
      expect(b / 5000, closeTo(pointers[1], 0.1));
      expect(c / 5000, closeTo(pointers[2], 0.1));
    });
  });
}
