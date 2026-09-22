import 'package:lifeos_core/lifeos_core.dart';
import 'package:test/test.dart';

void main() {
  group('newId', () {
    test('generates valid UUID v4 ids', () {
      final id = newId();
      expect(isValidId(id), isTrue);
    });

    test('generates distinct ids', () {
      final ids = {for (var i = 0; i < 100; i++) newId()};
      expect(ids.length, 100);
    });
  });
}