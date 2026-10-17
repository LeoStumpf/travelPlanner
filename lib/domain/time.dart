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

DateTime dateOfDay(DateTime start, int day) =>
    DateTime(start.year, start.month, start.day + day);

// Day names, durations and plurals are formatted by the UI (lib/ui/common/
// format.dart), so this file stays language-neutral.
