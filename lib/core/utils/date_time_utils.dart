import 'package:intl/intl.dart';

class DateTimeUtils {
  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  static final DateFormat _displayDateFormat = DateFormat('MMM dd, yyyy');
  static final DateFormat _dateTimeFormat = DateFormat(
    'MMM dd, yyyy • hh:mm a',
  );
  static final DateFormat _shortDateFormat = DateFormat('dd/MM/yyyy');

  static String toDateString(DateTime date) => _dateFormat.format(date);
  static String toDisplayDate(DateTime date) => _displayDateFormat.format(date);
  static String toDisplayDateTime(DateTime date) =>
      _dateTimeFormat.format(date);
  static String toShortDate(DateTime date) => _shortDateFormat.format(date);

  static String formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    final minStr = minutes.toString().padLeft(2, '0');
    final secStr = remainingSeconds.toString().padLeft(2, '0');
    return '$minStr:$secStr';
  }

  static String formatRemainingTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}
