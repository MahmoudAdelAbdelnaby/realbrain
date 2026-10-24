import 'package:flutter/material.dart';

import '../factcheck/fact_check_view.dart' show openUrl;

/// Google Maps search link for a place: opens the Maps app, no API key or billing needed.
/// ponytail: P1-12's map + Places lookup need Blaze (Places API, Maps SDK); this is the free part.
String mapsUrl(Map<String, dynamic> place) {
  final q = [place['name'], place['area'], place['city']]
      .whereType<String>()
      .where((s) => s.isNotEmpty)
      .join(', ');
  return 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeQueryComponent(q)}';
}

/// Places item (P1-12, no-billing part): each place with why to go, what to order, Open in Maps.
class PlacesView extends StatelessWidget {
  const PlacesView({super.key, required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final places = [
      for (final p in (data['items'] as List?) ?? const [])
        (p as Map).cast<String, dynamic>()
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final p in places)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${p['name']}',
                  style: Theme.of(context).textTheme.titleSmall),
              if (p['area'] != null || p['city'] != null)
                Text([p['area'], p['city']].whereType<String>().join(', '),
                    style: TextStyle(color: muted)),
              if (p['why_go'] != null)
                Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('${p['why_go']}')),
              if (p['what_to_order'] != null)
                Text('Order: ${p['what_to_order']}',
                    style: TextStyle(color: muted)),
              TextButton.icon(
                onPressed: () => openUrl(context, mapsUrl(p)),
                icon: const Icon(Icons.map_outlined, size: 18),
                label: const Text('Open in Maps'),
              ),
            ]),
          ),
      ],
    );
  }
}
