import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../map/providers/map_provider.dart';

class HeatMapsScreen extends StatefulWidget {
  const HeatMapsScreen({Key? key}) : super(key: key);

  @override
  State<HeatMapsScreen> createState() => _HeatMapsScreenState();
}

class _HeatMapsScreenState extends State<HeatMapsScreen> {
  String _activeLayer = 'Distress Heat';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshMapData());
  }

  Future<void> _refreshMapData() async {
    final provider = context.read<MapProvider>();
    await provider.fetchMapLayers();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final mapProvider = context.watch<MapProvider>();
    final victims = mapProvider.victims;
    final mapCenter = victims.isNotEmpty
        ? LatLng(victims.first.latitude, victims.first.longitude)
        : mapProvider.currentLocation;

    return Scaffold(
      appBar: AppBar(
        title: const Text('GIS Hazard & Heat Maps'),
        backgroundColor: AppColors.headerBlue,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children:
                    [
                      'Distress Heat',
                      'Evacuation Routes',
                      'Safe Zones',
                      'Water Level Risk',
                    ].map((layer) {
                      final isSelected = _activeLayer == layer;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(layer),
                          selected: isSelected,
                          selectedColor: AppColors.headerBlue,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          onSelected: (selected) {
                            if (selected) setState(() => _activeLayer = layer);
                          },
                        ),
                      );
                    }).toList(),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshMapData,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.68,
                    child: Stack(
                      children: [
                        FlutterMap(
                          options: MapOptions(
                            initialCenter: mapCenter,
                            initialZoom: 13,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.resq.app',
                            ),
                            if (_activeLayer == 'Distress Heat') ...[
                              CircleLayer(
                                circles: victims.map((victim) {
                                  final color = victim.severity == 'CRITICAL'
                                      ? AppColors.severityCritical
                                      : victim.severity == 'HIGH'
                                      ? AppColors.severityHigh
                                      : AppColors.severityMedium;
                                  return CircleMarker(
                                    point: LatLng(
                                      victim.latitude,
                                      victim.longitude,
                                    ),
                                    radius: 180,
                                    useRadiusInMeter: true,
                                    color: color.withOpacity(0.22),
                                    borderColor: color,
                                    borderStrokeWidth: 2,
                                  );
                                }).toList(),
                              ),
                              MarkerLayer(
                                markers: victims.map((victim) {
                                  return Marker(
                                    point: LatLng(
                                      victim.latitude,
                                      victim.longitude,
                                    ),
                                    width: 42,
                                    height: 42,
                                    child: const Icon(
                                      Icons.warning_rounded,
                                      color: AppColors.primary,
                                      size: 36,
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                        if (_activeLayer == 'Distress Heat' && victims.isEmpty)
                          const Center(
                            child: Card(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Text(
                                  'No active SOS locations available.',
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          bottom: 20,
                          left: 20,
                          right: 20,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(14.0),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: const [
                                    _LegendItem(
                                      color: AppColors.severityCritical,
                                      label: 'High Risk (SOS > 10)',
                                    ),
                                    SizedBox(width: 18),
                                    _LegendItem(
                                      color: AppColors.severityMedium,
                                      label: 'Moderate Risk',
                                    ),
                                    SizedBox(width: 18),
                                    _LegendItem(
                                      color: AppColors.success,
                                      label: 'Safe Zone',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
