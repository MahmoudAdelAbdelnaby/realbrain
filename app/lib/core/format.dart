/// Words for times, dates and sources, in one place so every screen says them the same way.
library;

const weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday'
];
const months = [
  'January', 'February', 'March', 'April', 'May', 'June', //
  'July', 'August', 'September', 'October', 'November', 'December'
];

String short(String s) => s.substring(0, 3);

DateTime fromEpoch(num seconds) =>
    DateTime.fromMillisecondsSinceEpoch((seconds * 1000).round());

double epoch(DateTime t) => t.millisecondsSinceEpoch / 1000;

/// "today", "yesterday", "3 days ago", "2 weeks ago", "4 months ago".
String ago(num seconds, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final then = fromEpoch(seconds);
  final days = DateTime(n.year, n.month, n.day)
      .difference(DateTime(then.year, then.month, then.day))
      .inDays;
  if (days <= 0) return 'today';
  if (days == 1) return 'yesterday';
  if (days < 14) return '$days days ago';
  if (days < 60) return '${days ~/ 7} weeks ago';
  if (days < 730) return '${days ~/ 30} months ago';
  return '${days ~/ 365} years ago';
}

/// "3 days", "6 weeks" (no "ago"), for "waiting 6 weeks".
String span(num seconds) {
  final days = (seconds / 86400).floor();
  if (days < 14) return '$days day${days == 1 ? '' : 's'}';
  if (days < 60) return '${days ~/ 7} weeks';
  return '${days ~/ 30} months';
}

/// "Tue 3 Nov".
String dayMonth(DateTime d) =>
    '${short(weekdays[d.weekday - 1])} ${d.day} ${short(months[d.month - 1])}';

/// "7:30 PM".
String clock12(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m ${d.hour < 12 ? 'AM' : 'PM'}';
}

/// "Sat 8 Nov · 7:30 PM", or "Today · 7:30 PM" / "Tomorrow · 9:00 AM".
String when(DateTime d, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final days = DateTime(d.year, d.month, d.day)
      .difference(DateTime(n.year, n.month, n.day))
      .inDays;
  final day = days == 0
      ? 'Today'
      : days == 1
          ? 'Tomorrow'
          : dayMonth(d);
  return '$day · ${clock12(d)}';
}

/// "0:42", "12:05" for moments in a reel.
String mmss(num seconds) {
  final s = seconds.round();
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

const platformNames = {
  'tiktok': 'TikTok',
  'instagram': 'Instagram',
  'youtube': 'YouTube',
  'facebook': 'Facebook',
  'idea': 'Typed idea',
  'other': 'the web',
};

String platformName(String? p) => platformNames[p] ?? p ?? 'the web';

/// "No. 0142".
String catalogueNo(int n) => 'No. ${n.toString().padLeft(4, '0')}';

/// The first name, for greetings.
String firstName(String name) =>
    name.trim().isEmpty ? '' : name.trim().split(RegExp(r'\s+')).first;

/// Plural helper: "1 recipe", "3 recipes".
String count(int n, String noun, [String? plural]) =>
    '$n ${n == 1 ? noun : (plural ?? '${noun}s')}';
