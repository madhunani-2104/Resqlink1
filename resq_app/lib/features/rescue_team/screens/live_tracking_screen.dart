import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class LiveTrackingScreen extends StatelessWidget {
  final String victimName;
  final String coordinates;

  const LiveTrackingScreen({
    Key? key,
    required this.victimName,
    required this.coordinates,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Live Tracking: $victimName'),
        backgroundColor: AppColors.headerBlue,
      ),
      body: Stack(
        children: [
          // Map Placeholder / OpenStreetMap GIS Simulation Container
          Container(
            color: const Color(0xFFE2E8F0),
            width: double.infinity,
            height: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.navigation_rounded, size: 70, color: AppColors.headerBlue),
                const SizedBox(height: 14),
                Text(
                  'Tracking Victim: $victimName',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text('Coordinates: $coordinates', style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'GPS Route Active • Estimated Arrival: 6 mins',
                    style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Action Navigation Bar
          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.person_pin_circle_rounded, color: AppColors.primary, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(victimName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const Text('Distance: 0.8 km • Multi-hop Mesh Beacon', style: TextStyle(fontSize: 12, color: Colors.black54)),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Marked $victimName as Rescued!'), backgroundColor: AppColors.success),
                        );
                      },
                      child: const Text('Mark Rescued'),
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
}
