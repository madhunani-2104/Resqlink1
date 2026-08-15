import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/profile_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/models/user_model.dart';
import '../../../widgets/custom_button.dart';
import '../../../widgets/custom_textfield.dart';
import '../../../core/constants/app_colors.dart';

class MedicalInfoScreen extends StatefulWidget {
  const MedicalInfoScreen({Key? key}) : super(key: key);

  @override
  State<MedicalInfoScreen> createState() => _MedicalInfoScreenState();
}

class _MedicalInfoScreenState extends State<MedicalInfoScreen> {
  String _selectedBloodGroup = 'O+';
  final _allergiesController = TextEditingController();
  final _conditionsController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user != null) {
      _selectedBloodGroup = user.medicalInfo.bloodGroup;
      _allergiesController.text = user.medicalInfo.allergies.join(', ');
      _conditionsController.text = user.medicalInfo.chronicConditions.join(', ');
      _notesController.text = user.medicalInfo.notes;
    }
  }

  void _saveMedicalInfo() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);

    if (authProvider.user != null) {
      final newMedicalInfo = MedicalInfo(
        bloodGroup: _selectedBloodGroup,
        allergies: _allergiesController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        chronicConditions: _conditionsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        notes: _notesController.text.trim(),
      );

      final success = await profileProvider.updateMedicalInfo(authProvider.user!, newMedicalInfo);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Medical Info Updated Successfully'), backgroundColor: AppColors.success),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = Provider.of<ProfileProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Medical Emergency Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Critical First Responder Medical Info',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'This medical card is attached to your SOS signal and read by emergency responders upon arrival.',
              style: TextStyle(fontSize: 13, color: Colors.white70),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-', 'Unknown'].contains(_selectedBloodGroup)
                  ? _selectedBloodGroup
                  : 'Unknown',
              decoration: const InputDecoration(
                labelText: 'Blood Group',
                prefixIcon: Icon(Icons.bloodtype),
              ),
              items: ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-', 'Unknown']
                  .map((bg) => DropdownMenuItem(value: bg, child: Text(bg)))
                  .toList(),
              onChanged: (val) => setState(() => _selectedBloodGroup = val!),
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _allergiesController,
              labelText: 'Allergies (comma separated)',
              hintText: 'e.g. Penicillin, Nuts, Latex',
              prefixIcon: Icons.warning_amber_rounded,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _conditionsController,
              labelText: 'Chronic Conditions (comma separated)',
              hintText: 'e.g. Asthma, Diabetes, Hypertension',
              prefixIcon: Icons.monitor_heart_outlined,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _notesController,
              labelText: 'Emergency Medical Notes',
              hintText: 'Any special rescue instructions...',
              prefixIcon: Icons.notes,
              maxLines: 3,
            ),
            const SizedBox(height: 30),
            CustomButton(
              text: 'Save Medical Profile',
              isLoading: profileProvider.isLoading,
              onPressed: _saveMedicalInfo,
            ),
          ],
        ),
      ),
    );
  }
}
