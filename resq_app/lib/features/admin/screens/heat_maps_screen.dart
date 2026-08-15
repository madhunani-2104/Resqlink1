import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class HeatMapsScreen extends StatefulWidget {
  const HeatMapsScreen({Key? key}) : super(key: key);

  @override
  State<HeatMapsScreen> createState() => _HeatMapsScreenState();
}

class _HeatMapsScreenState extends State<HeatMapsScreen> {
  String _activeLayer = 'Distress Heat';

  @override
  Widget build(BuildContext context) {
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
                children: ['Distress Heat', 'Evacuation Routes', 'Safe Zones', 'Water Level Risk'].map((layer) {
                  final isSelected = _activeLayer == layer;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(layer),
                      selected: isSelected,
                      selectedColor: AppColors.headerBlue,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
            child: Stack(
              children: [
                // Simulated Heat Map GIS Layer Container
                Container(
                  width: double.infinity,
                  color: const Color(0xFFE2E8F0),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _activeLayer == 'Distress Heat'
                              ? Icons.local_fire_department_rounded
                              : Icons.map_rounded,
                          size: 80,
                          color: _activeLayer == 'Distress Heat' ? AppColors.primary : AppColors.headerBlue,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'GIS Layer: $_activeLayer',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Rendering OpenStreetMap live density markers...',
                          style: TextStyle(color: Colors.black54),
                        ),
                      ],
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
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: const [
                          _LegendItem(color: AppColors.severityCritical, label: 'High Risk (SOS > 10)'),
                          _LegendItem(color: AppColors.severityMedium, label: 'Moderate Risk'),
                          _LegendItem(color: AppColors.success, label: 'Safe Zone'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
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
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
