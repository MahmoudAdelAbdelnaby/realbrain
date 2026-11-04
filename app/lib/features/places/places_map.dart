import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/art/glyphs.dart';
import '../../core/data/repo.dart';
import '../../core/links.dart';
import '../../core/theme/tokens.dart';
import '../../core/ui/components.dart';
import '../../core/ui/states.dart';
import '../shared/open.dart';
import '../shared/tiles.dart';

/// One pin: the place, the discovery it came from, and where the backend found it.
typedef Pin = ({Discovery d, Json place, LatLng at});

/// Every geocoded place, in order. Places without `geo` stay off the map (they keep Open in Maps
/// on their page).
List<Pin> placePins(Iterable<Discovery> places) => [
      for (final d in places)
        for (final p in listOf(d.data['items']))
          if (p['geo'] case {'lat': num lat, 'lng': num lng})
            (d: d, place: p, at: LatLng(lat.toDouble(), lng.toDouble())),
    ];

// Inverts OSM's light tiles for the ink theme and keeps hues roughly right.
const _inkTiles = ColorFilter.matrix([
  -0.574, -1.43, -0.144, 0, 255, //
  -0.426, -1.43, -0.144, 0, 255, //
  -0.426, -1.43, 0.856, 0, 255, //
  0, 0, 0, 1, 0,
]);

/// The map from the Library: every place you saved.
class PlacesMapScreen extends StatelessWidget {
  const PlacesMapScreen({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<BrainState>(
        valueListenable: Repo.instance.state,
        builder: (context, s, _) => Scaffold(
          appBar: AppBar(title: const Text('Places')),
          body: PlacesMap(discoveries: s.inCategory('places')),
        ),
      );
}

/// OpenStreetMap (no billing): glyph pins, the selected one in saffron, a card carousel that
/// follows the pins, with the stamp and Open in Maps on each card.
class PlacesMap extends StatefulWidget {
  const PlacesMap({super.key, required this.discoveries});
  final List<Discovery> discoveries;

  @override
  State<PlacesMap> createState() => _PlacesMapState();
}

class _PlacesMapState extends State<PlacesMap> {
  final _map = MapController();
  final _cards = PageController(viewportFraction: 0.86);
  int _selected = 0;

  void _select(int i, List<Pin> pins, {bool fromPin = false}) {
    setState(() => _selected = i);
    _map.move(pins[i].at, _map.camera.zoom < 14 ? 14 : _map.camera.zoom);
    if (fromPin) {
      _cards.animateToPage(i, duration: RbMotion.base, curve: RbMotion.curve);
    }
  }

  @override
  void dispose() {
    _cards.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final pins = placePins(widget.discoveries);
    if (pins.isEmpty) {
      return const Center(
        child: SingleChildScrollView(
          child: EmptyState(
            title: 'No places on the map yet',
            body:
                'New place saves get a pin. Older ones can be filed under Places again to '
                'look them up.',
          ),
        ),
      );
    }
    final selected = _selected.clamp(0, pins.length - 1);
    Widget tiles = TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.reelbrain.reelbrain',
    );
    if (dark) tiles = ColorFiltered(colorFilter: _inkTiles, child: tiles);
    return Stack(children: [
      FlutterMap(
        mapController: _map,
        options: MapOptions(
          backgroundColor: c.raised,
          initialCameraFit: pins.length == 1
              ? null
              : CameraFit.coordinates(
                  coordinates: [for (final p in pins) p.at],
                  padding: const EdgeInsets.fromLTRB(48, 48, 48, 220)),
          initialCenter: pins.first.at,
          initialZoom: 14,
        ),
        children: [
          tiles,
          MarkerLayer(markers: [
            for (final (i, p) in pins.indexed)
              Marker(
                point: p.at,
                width: 44,
                height: 44,
                child: Semantics(
                  button: true,
                  label: '${p.place['name']}',
                  child: GestureDetector(
                    onTap: () => _select(i, pins, fromPin: true),
                    child: AnimatedScale(
                      duration: RbMotion.fast,
                      scale: i == selected ? 1.15 : 1,
                      child: Container(
                        decoration: BoxDecoration(
                          color: i == selected ? c.brand : c.surface,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: i == selected ? c.onBrand : c.line,
                              width: 1.5),
                          boxShadow: const [
                            BoxShadow(color: Color(0x40000000), blurRadius: 6)
                          ],
                        ),
                        alignment: Alignment.center,
                        child: p.d.isDone
                            ? Glyph(Glyphs.piece,
                                size: 18,
                                color: i == selected ? c.onBrand : c.brand,
                                fill: i == selected ? c.onBrand : c.brand,
                                weight: 1)
                            : Glyph(Glyphs.map,
                                size: 20,
                                color: i == selected ? c.onBrand : c.text),
                      ),
                    ),
                  ),
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
        bottom: 20,
        height: 176,
        child: PageView.builder(
          controller: _cards,
          itemCount: pins.length,
          onPageChanged: (i) => _select(i, pins),
          itemBuilder: (context, i) => _PlaceCard(pin: pins[i]),
        ),
      ),
    ]);
  }
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({required this.pin});
  final Pin pin;

  @override
  Widget build(BuildContext context) {
    final p = pin.place;
    final c = RbColors.of(context);
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Panel(
        child: InkWell(
          onTap: () => openDiscovery(context, pin.d),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 10, 6),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              MonoLabel([
                if ((p['geo'] as Map)['matched'] == 'area') 'Area only',
                p['area'],
                p['city'],
              ].whereType<String>().join(' · ')),
              const SizedBox(height: 4),
              Text('${p['name']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RbType.serif(20, color: c.text)),
              if (p['why_go'] != null)
                Text('${p['why_go']}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodySmall?.copyWith(color: c.text)),
              const Spacer(),
              Row(children: [
                StampButton(pin.d),
                const Spacer(),
                TextButton(
                    onPressed: () => openUrl(context, mapsUrl(p)),
                    child: const Text('Open in Maps')),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}
