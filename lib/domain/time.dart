// Helpers for the trip-relative minute time model.

const int minutesPerDay = 1440;

/// Coarse parts of a day used while planning roughly.
enum DayPart { morning, midday, afternoon, evening, night }

extension DayPartX on DayPart {
  int get minuteOfDay => switch (this) {
        DayPart.morning => 9 * 60,
        DayPart.midday => 12 * 60,
        DayPart.afternoon => 15 * 60,
        DayPart.evening => 18 * 60,
        DayPart.night => 22 * 60,
      };

  String get label => switch (this) {
        DayPart.morning => 'Morgens',
        DayPart.midday => 'Mittags',
        DayPart.afternoon => 'Nachmittags',
        DayPart.evening => 'Abends',
        DayPart.night => 'Nachts',
      };
}

/// Default arrival/departure for a stay: arrive early afternoon, leave
/// mid-morning, so consecutive stays share the travel day without overlapping.
const int defaultStayArrival = 14 * 60;
const int defaultStayDeparture = 10 * 60;

/// Accommodation check-in / check-out times.
const int defaultCheckIn = 15 * 60;
const int defaultCheckOut = 11 * 60;

int dayOf(int minute) => (minute / minutesPerDay).floor();
int minuteOfDay(int minute) => minute - dayOf(minute) * minutesPerDay;
int at(int day, int minuteOfDay) => day * minutesPerDay + minuteOfDay;

/// Last day an item touches. An item ending exactly at midnight does not
/// touch the following day.
int lastDayOf(int end) => minuteOfDay(end) == 0 ? dayOf(end) - 1 : dayOf(end);

/// Number of calendar days an interval touches.
int daysTouched(int start, int end) => lastDayOf(end) - dayOf(start) + 1;

/// Number of nights (midnights crossed) in an interval.
int nightsIn(int start, int end) => lastDayOf(end) - dayOf(start);

String formatClock(int minute) {
  final m = minuteOfDay(minute);
  return '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
}

const _weekdays = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
const _months = ['Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun', 'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez'];

DateTime dateOfDay(DateTime start, int day) =>
    DateTime(start.year, start.month, start.day + day);

/// "Tag 3" without a start date, "Mi 12. Mär" with one.
String formatDay(DateTime? tripStart, int day, {bool withDayNumber = false}) {
  if (tripStart == null) return 'Tag ${day + 1}';
  final d = dateOfDay(tripStart, day);
  final s = '${_weekdays[d.weekday - 1]} ${d.day}. ${_months[d.month - 1]}';
  return withDayNumber ? '$s (Tag ${day + 1})' : s;
}

String formatMoment(DateTime? tripStart, int minute) =>
    '${formatDay(tripStart, dayOf(minute))}, ${formatClock(minute)}';

String pluralDays(int n) => n == 1 ? '1 Tag' : '$n Tage';
String pluralNights(int n) => n == 1 ? '1 Nacht' : '$n Nächte';
