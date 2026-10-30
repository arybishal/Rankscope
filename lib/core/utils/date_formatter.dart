import 'package:intl/intl.dart';

/// Date and time formatting helpers.
class DateFormatter {
  DateFormatter._();

  static final DateFormat _isoDate = DateFormat('yyyy-MM-dd');
  static final DateFormat _mediumDate = DateFormat('MMM d, yyyy');
  static final DateFormat _mediumDateTime = DateFormat('MMM d, yyyy • h:mm a');

  static String toIso(DateTime dt) => _isoDate.format(dt);
  static String toMedium(DateTime dt) => _mediumDate.format(dt);
  static String toMediumDateTime(DateTime dt) => _mediumDateTime.format(dt);

  static String formatEpochMs(int epochMs) {
    return toMediumDateTime(DateTime.fromMillisecondsSinceEpoch(epochMs));
  }

  static String relativeTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return toMedium(dt);
  }
}
