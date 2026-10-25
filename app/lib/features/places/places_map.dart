import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/surface.dart';
import '../../core/theme/tokens.dart';
import '../factcheck/fact_check_view.dart' show openUrl;
import '../section/section_screen.dart' show setItemState;
import 'places_view.dart';

/// One pin: the place, the item it came from (for Visited), and where the backend found it.
typedef Pin = ({
  Map<String, dynamic> item,
  Map<String, dynamic> place,
  LatLng at
});

/// Every geocoded place across the Places items, in order. Places without `geo` stay off the
/// map (they still show in the list with Open in Maps).
List<Pin> placePins(Iterable<Map<String, dynamic>> items) => [
      for (final item in items)
        for (final p in ((item['data'] as Map?)?['items'] as List?) ?? const [])
          if ((p as Map)['geo'] case {'lat': num lat, 'lng': num lng})
            (
              item: item,
              place: p.cast<String, dynamic>(),
              at: LatLng(lat.toDouble(), lng.toDouble())
            ),
    ];

// Inverts OSM's light tiles for dark mode and keeps hues roughly right (hue-rotate 180).
const _darkTiles = ColorFilter.matrix([
  -0.574, -1.43, -0.144, 0, 255, //
  -0.426, -1.43, -0.144, 0, 255, //
  -0.426, -1.43, 0.856, 0, 255, //
  0, 0, 0, 1, 0,
]);

/// P1-12 map on OpenStreetMap (no billing): neutral pins, the selected one in the accent, a
/// bottom carousel that follows the pins, Visited and Open in Maps on each card.
class PlacesMap extends StatefulWidget {
  const PlacesMap({super.key, required this.items});
  final List<Map<String, dynamic>> items;

  @override
  State<PlacesMap> createState() => _PlacesMapState();
}

class _PlacesMapState extends State<PlacesMap> {
  final _map = MapController();
  final _cards = PageController(viewportFraction: 0.88);
  int _selected = 0;

  void _select(int i, List<Pin> pins, {bool fromPin = false}) {
    setState(() => _selected = i);
    _map.move(pins[i].at, _map.camera.zoom < 14 ? 14 : _map.camera.zoom);
    if (fromPin) {
      _cards.animateToPage(i, duration: RbMotion.base, curve: RbMotion.curve);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final pins = placePins(widget.items);
    if (pins.isEmpty) {
      return Scaffold(
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(RbSpace.side),
            child: Text('No places on the map yet. New places saves get a pin; '
                'older ones can be re-filed under Places to look them up.'),
          ),
        ),
      );
    }
    final selected = _selected.clamp(0, pins.length - 1);
    Widget tiles = TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.reelbrain.reelbrain',
    );
    if (dark) tiles = ColorFiltered(colorFilter: _darkTiles, child: tiles);
    return Scaffold(
      body: Stack(children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCameraFit: pins.length == 1
                ? null
                : CameraFit.coordinates(
                    coordinates: [for (final p in pins) p.at],
                    padding: const EdgeInsets.fromLTRB(48, 48, 48, 200)),
            initialCenter: pins.first.at,
            initialZoom: 14,
          ),
          children: [
            tiles,
            MarkerLayer(markers: [
              for (final (i, p) in pins.indexed)
                Marker(
                  point: p.at,
                  width: 48,
                  height: 48,
                  child: GestureDetector(
                    onTap: () => _select(i, pins, fromPin: true),
                    child: Icon(Icons.location_on,
                        size: i == selected ? 40 : 32,
                        color: i == selected ? c.accent : c.text),
                  ),
                ),
            ]),
            const RichAttributionWidget(attributions: [
              TextSourceAttribution('OpenStreetMap contributors'),
            ]),
          ],
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 24,
          height: 156,
          child: PageView.builder(
            controller: _cards,
            itemCount: pins.length,
            onPageChanged: (i) => _select(i, pins),
            itemBuilder: (context, i) => _PlaceCard(pin: pins[i]),
          ),
        ),
      ]),
    );
  }
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({required this.pin});
  final Pin pin;

  @override
  Widget build(BuildContext context) {
    final p = pin.place;
    final t = Theme.of(context).textTheme;
    // Text on a floating panel uses the full text colour.
    final ink = RbColors.of(context).text;
    final visited = pin.item['user_state'] == 'visited';
    // ponytail: up to 2 cards plus the pill blur at once here; fine on the S22, go solid if it drops frames.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Panel(
        radius: RbSpace.cardRadius,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${p['name']}',
                style: t.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            Text(
                [
                  if ((p['geo'] as Map)['matched'] == 'area') 'Area only',
                  p['area'],
                  p['city']
                ].whereType<String>().join(' · '),
                style: t.bodySmall?.copyWith(color: ink)),
            if (p['why_go'] != null)
              Text('${p['why_go']}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: ink)),
            const Spacer(),
            Row(children: [
              FilterChip(
                label: const Text('Visited'),
                selected: visited,
                onSelected: pin.item['item_id'] == null
                    ? null
                    : (v) => setItemState(pin.item, v ? 'visited' : 'to_try'),
              ),
              const Spacer(),
              TextButton(
                  onPressed: () => openUrl(context, mapsUrl(p)),
                  child: const Text('Open in Maps')),
            ]),
          ]),
        ),
      ),
    );
  }
}
