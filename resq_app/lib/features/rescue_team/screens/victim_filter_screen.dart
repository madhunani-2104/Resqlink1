import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class VictimFilterScreen extends StatefulWidget {
  const VictimFilterScreen({Key? key}) : super(key: key);

  @override
  State<VictimFilterScreen> createState() => _VictimFilterScreenState();
}

class _VictimFilterScreenState extends State<VictimFilterScreen> {
  String _severity = 'All';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Filter Victim Incidents'),
        backgroundColor: AppColors.headerBlue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Filter by Severity Level', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              children: ['All', 'Critical', 'High', 'Medium', 'Low', 'Rescued'].map((opt) {
                final isSelected = _severity == opt;
                return ChoiceChip(
                  label: Text(opt),
                  selected: isSelected,
                  selectedColor: AppColors.headerBlue,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (selected) {
                    if (selected) setState(() => _severity = opt);
                  },
                );
              }).toList(),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.headerBlue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  Navigator.pop(context, _severity);
                },
                child: const Text('Apply Filter', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
