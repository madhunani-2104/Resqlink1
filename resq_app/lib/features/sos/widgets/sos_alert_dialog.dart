import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../widgets/custom_button.dart';

class SosAlertDialog extends StatelessWidget {
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const SosAlertDialog({
    Key? key,
    required this.onConfirm,
    required this.onCancel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.darkSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.primary, size: 28),
          SizedBox(width: 10),
          Text('Trigger SOS Emergency?', style: TextStyle(color: Colors.white)),
        ],
      ),
      content: const Text(
        'This will immediately broadcast an emergency distress signal across the peer-to-peer mesh network, dispatch your GPS coordinates, and transmit your medical profile to nearby rescue teams.',
        style: TextStyle(color: Colors.white70, fontSize: 14),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      actions: [
        TextButton(
          onPressed: onCancel,
          child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
        ),
        CustomButton(
          text: 'BROADCAST SOS NOW',
          width: 180,
          height: 48,
          backgroundColor: AppColors.primary,
          onPressed: onConfirm,
        ),
      ],
    );
  }
}
