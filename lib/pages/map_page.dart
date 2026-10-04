import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/models.dart';
import '../core/widgets.dart';
import '../supabase_config.dart';
import 'requests_page.dart';
import 'auth_page.dart';

class IssuesMapPage extends StatefulWidget {
  const IssuesMapPage({super.key});
  @override
  State<IssuesMapPage> createState() => _IssuesMapPageState();
}

class _IssuesMapPageState extends State<IssuesMapPage> {
  Future<List<Map<String, dynamic>>> _load() async {
    final repo = AppScope.of(context).repository;
    final rows = <Map<String, dynamic>>[];
    // Paging avoids silently dropping reports at PostgREST's per-query cap.
    var offset = 0;
    while (true) {
      final batch = await repo.requests(offset: offset);
      rows.addAll(
        batch.where((r) => r['latitude'] != null && r['longitude'] != null),
      );
      offset += batch.length;
      if (batch.length < 30) break;
      if (offset >= 3000) break;
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context).repository;
    if (repo.userId == null) {
      return Center(
        child: FilledButton(
          onPressed: () async {
            await requireSignIn(context);
            if (mounted) setState(() {});
          },
          child: const Text('تسجيل الدخول لعرض خريطة طلباتك'),
        ),
      );
    }
    return DataView<List<Map<String, dynamic>>>(
      load: _load,
      builder: (context, rows, reload) {
        if (rows.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const EmptyState('لا توجد مواقع مرفقة بطلباتك بعد.'),
                TextButton(onPressed: reload, child: const Text('تحديث')),
              ],
            ),
          );
        }
        final first = rows.first;
        final center = LatLng(
          (first['latitude'] as num).toDouble(),
          (first['longitude'] as num).toDouble(),
        );
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Expanded(child: Text('تظهر هنا مواقع طلباتك فقط.')),
                  IconButton(
                    onPressed: reload,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'تحديث',
                  ),
                ],
              ),
            ),
            Expanded(
              child: FlutterMap(
                key: ValueKey('${rows.length}/${first['id']}'),
                options: MapOptions(initialCenter: center, initialZoom: 14),
                children: [
                  TileLayer(
                    urlTemplate: mapTileUrl,
                    userAgentPackageName: 'lb.sweissa.sweissa_municipality',
                  ),
                  MarkerLayer(
                    markers: rows
                        .map(
                          (r) => Marker(
                            point: LatLng(
                              (r['latitude'] as num).toDouble(),
                              (r['longitude'] as num).toDouble(),
                            ),
                            width: 48,
                            height: 48,
                            child: IconButton(
                              tooltip:
                                  '${r['category']} • ${statusLabels[r['status']]}',
                              icon: Icon(
                                Icons.location_on,
                                color: r['status'] == 'resolved'
                                    ? Colors.green
                                    : Theme.of(context).colorScheme.primary,
                                size: 36,
                              ),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      RequestDetailsPage(id: r['id'] as String),
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution(
                        mapAttribution,
                        onTap: () => launchUrl(
                          Uri.parse('https://www.openstreetmap.org/copyright'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
