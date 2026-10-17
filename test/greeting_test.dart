import 'package:bloop/utils/greeting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DateTime at(int hour, [int minute = 0]) =>
      DateTime(2026, 10, 17, hour, minute);

  group('greetingFor', () {
    test('follows the clock at every boundary', () {
      expect(greetingFor(at(4, 59)), 'Good night, User');
      expect(greetingFor(at(5)), 'Good morning, User');
      expect(greetingFor(at(11, 59)), 'Good morning, User');
      expect(greetingFor(at(12)), 'Good afternoon, User');
      expect(greetingFor(at(16, 59)), 'Good afternoon, User');
      expect(greetingFor(at(17)), 'Good evening, User');
      expect(greetingFor(at(20, 59)), 'Good evening, User');
      expect(greetingFor(at(21)), 'Good night, User');
      expect(greetingFor(at(0)), 'Good night, User');
    });

    test('adds the first name only', () {
      expect(greetingFor(at(15), name: 'Saad'), 'Good afternoon, Saad');
      expect(
        greetingFor(at(15), name: '  Saad   Ansari '),
        'Good afternoon, Saad',
      );
    });

    test('calls the user "User" without a name', () {
      expect(greetingFor(at(9), name: null), 'Good morning, User');
      expect(greetingFor(at(9), name: ''), 'Good morning, User');
      expect(greetingFor(at(9), name: '   '), 'Good morning, User');
    });
  });
}
