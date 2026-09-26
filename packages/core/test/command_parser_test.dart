import 'package:lifeos_core/lifeos_core.dart';
import 'package:test/test.dart';

void main() {
  group('CommandParser', () {
    const parser = CommandParser();
    final refDate = DateTime(2026, 9, 26); // Saturday

    test('parses "Fix the iOS issue by today"', () {
      final res = parser.parseTask('Fix the iOS issue by today', referenceDate: refDate);
      expect(res.cleanTitle, 'Fix the iOS issue');
      expect(res.dueDate, DateTime(2026, 9, 26));
      expect(res.dueString, 'Today');
      expect(res.priority, CommandPriority.medium);
      expect(res.category, isNull);
    });

    test('parses "Fix the iOS issue by today @ios"', () {
      final res = parser.parseTask('Fix the iOS issue by today @ios', referenceDate: refDate);
      expect(res.cleanTitle, 'Fix the iOS issue');
      expect(res.dueDate, DateTime(2026, 9, 26));
      expect(res.dueString, 'Today');
      expect(res.category, 'ios');
      expect(res.tags, contains('ios'));
    });

    test('parses "Fix the iOS issue by tomorrow @work !urgent"', () {
      final res = parser.parseTask('Fix the iOS issue by tomorrow @work !urgent', referenceDate: refDate);
      expect(res.cleanTitle, 'Fix the iOS issue');
      expect(res.dueDate, DateTime(2026, 9, 27));
      expect(res.dueString, 'Tomorrow');
      expect(res.category, 'work');
      expect(res.priority, CommandPriority.urgent);
    });

    test('parses "Fix the iOS issue due:today @ios !p1"', () {
      final res = parser.parseTask('Fix the iOS issue due:today @ios !p1', referenceDate: refDate);
      expect(res.cleanTitle, 'Fix the iOS issue');
      expect(res.dueDate, DateTime(2026, 9, 26));
      expect(res.category, 'ios');
      expect(res.priority, CommandPriority.urgent);
    });

    test('parses weekday "Review PR by monday @engineering #p2"', () {
      final res = parser.parseTask('Review PR by monday @engineering #p2', referenceDate: refDate);
      expect(res.cleanTitle, 'Review PR');
      // Next Monday after Saturday Sep 26 is Monday Sep 28
      expect(res.dueDate, DateTime(2026, 9, 28));
      expect(res.category, 'engineering');
      expect(res.priority, CommandPriority.high);
    });

    test('parses ISO date "Pay electricity bill by 2026-10-05 @finance"', () {
      final res = parser.parseTask('Pay electricity bill by 2026-10-05 @finance', referenceDate: refDate);
      expect(res.cleanTitle, 'Pay electricity bill');
      expect(res.dueDate, DateTime(2026, 10, 5));
      expect(res.category, 'finance');
    });

    test('parses undated task with category "Clean desk @home"', () {
      final res = parser.parseTask('Clean desk @home', referenceDate: refDate);
      expect(res.cleanTitle, 'Clean desk');
      expect(res.dueDate, isNull);
      expect(res.category, 'home');
      expect(res.tags, ['home']);
    });
  });
}
