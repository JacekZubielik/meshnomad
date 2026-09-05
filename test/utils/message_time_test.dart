import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:meshnomad/utils/message_time.dart';

void main() {
  setUpAll(initializeDateFormatting);

  final now = DateTime(2026, 9, 5, 14, 27);
  final yesterday = DateTime(2026, 9, 4, 12, 57);

  test('a message from today shows the time only', () {
    expect(
      formatMessageTimestamp(
        DateTime(2026, 9, 5, 9, 4),
        locale: 'pl_PL',
        now: now,
      ),
      '09:04',
    );
  });

  test('an older message is prefixed with the region\'s short date', () {
    expect(
      formatMessageTimestamp(yesterday, locale: 'pl_PL', now: now),
      '4.09 12:57',
    );
    expect(
      formatMessageTimestamp(yesterday, locale: 'en_GB', now: now),
      '04/09 12:57',
    );
    expect(
      formatMessageTimestamp(yesterday, locale: 'de_DE', now: now),
      '4.9. 12:57',
    );
  });

  test('en_US gets month-first date and a 12-hour clock', () {
    expect(
      formatMessageTimestamp(yesterday, locale: 'en_US', now: now),
      '9/4 12:57 PM',
    );
  });

  test('the date follows the calendar day, not a 24-hour window', () {
    expect(
      formatMessageTimestamp(
        DateTime(2026, 9, 4, 23, 30),
        locale: 'pl_PL',
        now: DateTime(2026, 9, 5, 0, 10),
      ),
      '4.09 23:30',
    );
  });

  test('an unknown locale falls back to en_US instead of throwing', () {
    expect(
      formatMessageTimestamp(yesterday, locale: 'xx_YY', now: now),
      '9/4 12:57 PM',
    );
  });
}
