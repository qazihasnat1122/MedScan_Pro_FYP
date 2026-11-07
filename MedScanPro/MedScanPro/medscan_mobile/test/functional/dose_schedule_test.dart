import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Pure logic mirror of the schedule algorithms implemented in AddMedicineScreen
TimeOfDay parseTimeOfDay(String timeStr) {
  try {
    final parts = timeStr.trim().split(' ');
    final hm = parts[0].split(':');
    int hour = int.parse(hm[0]);
    final minute = int.parse(hm[1]);
    final period = parts.length > 1 ? parts[1].toUpperCase() : 'AM';
    if (period == 'PM' && hour < 12) hour += 12;
    if (period == 'AM' && hour == 12) hour = 0;
    return TimeOfDay(hour: hour, minute: minute);
  } catch (_) {
    return const TimeOfDay(hour: 8, minute: 0);
  }
}

int compareTimeStrings(String a, String b) {
  final ta = parseTimeOfDay(a);
  final tb = parseTimeOfDay(b);
  final ma = ta.hour * 60 + ta.minute;
  final mb = tb.hour * 60 + tb.minute;
  return ma.compareTo(mb);
}

DateTime getNextScheduledDateTime(String timeStr, DateTime referenceNow) {
  final tod = parseTimeOfDay(timeStr);
  var scheduled = DateTime(
    referenceNow.year,
    referenceNow.month,
    referenceNow.day,
    tod.hour,
    tod.minute,
  );
  if (scheduled.isBefore(referenceNow)) {
    scheduled = scheduled.add(const Duration(days: 1));
  }
  return scheduled;
}

void main() {
  group('Dose Reminder Scheduling Functional Tests', () {
    test(
      'Correctly parses 12-hour AM / PM strings to 24-hour TimeOfDay values',
      () {
        final morning = parseTimeOfDay('08:00 AM');
        expect(morning.hour, 8);
        expect(morning.minute, 0);

        final noon = parseTimeOfDay('12:00 PM');
        expect(noon.hour, 12);
        expect(noon.minute, 0);

        final afternoon = parseTimeOfDay('01:30 PM');
        expect(afternoon.hour, 13);
        expect(afternoon.minute, 30);

        final night = parseTimeOfDay('10:33 PM');
        expect(night.hour, 22);
        expect(night.minute, 33);

        final midnight = parseTimeOfDay('12:15 AM');
        expect(midnight.hour, 0);
        expect(midnight.minute, 15);
      },
    );

    test('Chronologically sorts arbitrary user-added reminder times', () {
      final unsorted = [
        '10:33 PM',
        '08:00 AM',
        '01:00 PM',
        '07:15 AM',
        '06:45 PM',
      ];
      unsorted.sort(compareTimeStrings);

      expect(unsorted, [
        '07:15 AM',
        '08:00 AM',
        '01:00 PM',
        '06:45 PM',
        '10:33 PM',
      ]);
    });

    test(
      'Calculates correct next upcoming schedule date for today vs tomorrow rollover',
      () {
        // Case 1: Time is in the future today
        final now = DateTime(2026, 9, 27, 9, 0); // 9:00 AM
        final futureTime = getNextScheduledDateTime('10:33 AM', now);
        expect(futureTime.day, 27);
        expect(futureTime.hour, 10);
        expect(futureTime.minute, 33);

        // Case 2: Time has already passed today, should roll over to tomorrow
        final pastTime = getNextScheduledDateTime('08:00 AM', now);
        expect(pastTime.day, 28);
        expect(pastTime.hour, 8);
        expect(pastTime.minute, 0);
      },
    );
  });
}
