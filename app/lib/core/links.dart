import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'native.dart';
import 'ui/components.dart' show toast;

/// Opens a link in its app or the browser; copies it when nothing can open it.
Future<void> openUrl(BuildContext context, String url) async {
  try {
    await native.invokeMethod('openUrl', {'url': url});
  } on PlatformException {
    await Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) toast(context, 'Link copied');
  } on MissingPluginException {
    await Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) toast(context, 'Link copied');
  }
}

/// Google Maps search for a place: opens the Maps app, no API key or billing needed.
String mapsUrl(Map<String, dynamic> place) {
  final q = [place['name'], place['area'], place['city']]
      .whereType<String>()
      .where((s) => s.isNotEmpty)
      .join(', ');
  return 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeQueryComponent(q)}';
}

/// Search links for a title: searches, not claims (nothing here is invented).
String imdbSearch(String title) =>
    'https://www.imdb.com/find/?q=${Uri.encodeQueryComponent(title)}';
String goodreadsSearch(String title) =>
    'https://www.goodreads.com/search?q=${Uri.encodeQueryComponent(title)}';
String justWatchSearch(String title) =>
    'https://www.justwatch.com/eg/search?q=${Uri.encodeQueryComponent(title)}';
String webSearch(String q) =>
    'https://www.google.com/search?q=${Uri.encodeQueryComponent(q)}';

String _calendarTime(DateTime t) {
  final u = t.toUtc();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${u.year}${two(u.month)}${two(u.day)}T${two(u.hour)}${two(u.minute)}00Z';
}

/// An "add to calendar" link (Google Calendar's event template), which opens the Calendar app
/// on Android and the web on iPhone. No calendar permission needed.
String calendarUrl(
    {required String title,
    required DateTime start,
    Duration length = const Duration(hours: 2),
    String? details,
    String? location}) {
  final q = {
    'action': 'TEMPLATE',
    'text': title,
    'dates': '${_calendarTime(start)}/${_calendarTime(start.add(length))}',
    if (details != null) 'details': details,
    if (location != null) 'location': location,
  };
  return Uri.https('calendar.google.com', '/calendar/render', q).toString();
}

/// Shares text through the phone's share sheet (clipboard on desktop web).
Future<void> shareOut(String text) => shareText(text);
