import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../providers/map_provider.dart';
import '../../../core/constants/app_colors.dart';

class LiveMapScreen extends StatefulWidget {
  const LiveMapScreen({Key? key}) : super(key: key);

  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen> {
  final MapController _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    final mapProvider = Provider.of<MapProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Disaster Map & GIS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () {
              _mapController.move(mapProvider.currentLocation, 14.0);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: mapProvider.currentLocation,
              initialZoom: 14.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.resq.app',
              ),

              // Safe Zone Radius Circles
              CircleLayer(
                circles: mapProvider.safeZones.map((sz) {
                  return CircleMarker(
                    point: LatLng(sz.latitude, sz.longitude),
                    color: AppColors.success.withOpacity(0.2),
                    borderColor: AppColors.success,
                    borderStrokeWidth: 2,
                    useRadiusInMeter: true,
                    radius: sz.radiusMeters,
                  );
                }).toList(),
              ),

              // Markers for User, Safe Zones, Shelters, and SOS Victims
              MarkerLayer(
                markers: [
                  // User Current Location
                  Marker(
                    point: mapProvider.currentLocation,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.person_pin_circle_rounded, color: AppColors.secondary, size: 40),
                  ),

                  // Safe Zones
                  ...mapProvider.safeZones.map((sz) {
                    return Marker(
                      point: LatLng(sz.latitude, sz.longitude),
                      width: 36,
                      height: 36,
                      child: GestureDetector(
                        onTap: () => _showMarkerDetails(context, sz.name, sz.description, 'Safe Zone'),
                        child: const Icon(Icons.shield, color: AppColors.success, size: 34),
                      ),
                    );
                  }).toList(),

                  // Shelters
                  ...mapProvider.shelters.map((sh) {
                    return Marker(
                      point: LatLng(sh.latitude, sh.longitude),
                      width: 36,
                      height: 36,
                      child: GestureDetector(
                        onTap: () => _showMarkerDetails(
                          context,
                          sh.name,
                          'Address: ${sh.address}\nCapacity: ${sh.currentOccupants}/${sh.capacity}\nAmenities: ${sh.amenities.join(", ")}',
                          'Shelter',
                        ),
                        child: const Icon(Icons.night_shelter_rounded, color: AppColors.accentAlert, size: 34),
                      ),
                    );
                  }).toList(),

                  // SOS Victims
                  ...mapProvider.victims.map((v) {
                    return Marker(
                      point: LatLng(v.latitude, v.longitude),
                      width: 40,
                      height: 40,
                      child: GestureDetector(
                        onTap: () => _showMarkerDetails(
                          context,
                          'SOS VICTIM: ${v.userName}',
                          'Severity: ${v.severity}\nPhone: ${v.userPhone}\nNotes: ${v.notes}',
                          'Active SOS Distress',
                        ),
                        child: const Icon(Icons.warning_rounded, color: AppColors.primary, size: 40),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ],
          ),

          // Map Filter Control Overlay Card
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Card(
              color: AppColors.darkSurface.withOpacity(0.9),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildFilterChip(
                      label: 'Safe Zones',
                      color: AppColors.success,
                      value: mapProvider.showSafeZones,
                      onChanged: mapProvider.toggleSafeZones,
                    ),
                    _buildFilterChip(
                      label: 'Shelters',
                      color: AppColors.accentAlert,
                      value: mapProvider.showShelters,
                      onChanged: mapProvider.toggleShelters,
                    ),
                    _buildFilterChip(
                      label: 'SOS Victims',
                      color: AppColors.primary,
                      value: mapProvider.showVictims,
                      onChanged: mapProvider.toggleVictims,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required Color color,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      selected: value,
      selectedColor: color.withOpacity(0.3),
      checkmarkColor: color,
      onSelected: onChanged,
    );
  }

  void _showMarkerDetails(BuildContext context, String title, String details, String category) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category.toUpperCase(),
                style: const TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 6),
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text(details, style: const TextStyle(fontSize: 14, color: Colors.white70)),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}
