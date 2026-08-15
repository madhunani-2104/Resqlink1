import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/profile_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/models/user_model.dart';
import '../../../widgets/custom_button.dart';
import '../../../widgets/custom_textfield.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/emergency_contact_notification_service.dart';

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({Key? key}) : super(key: key);

  @override
  State<EmergencyContactsScreen> createState() => _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  final List<EmergencyContact> _contacts = [];
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _relationController = TextEditingController(text: 'Family');

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user != null) {
      _contacts.addAll(user.emergencyContacts);
    }
  }

  void _addContact() {
    if (_nameController.text.isNotEmpty && _phoneController.text.isNotEmpty) {
      setState(() {
        _contacts.add(EmergencyContact(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          relationship: _relationController.text.trim(),
        ));
        _nameController.clear();
        _phoneController.clear();
      });
      Navigator.pop(context);
    }
  }

  void _saveContacts() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);

    if (authProvider.user != null) {
      final success = await profileProvider.updateEmergencyContacts(authProvider.user!, _contacts);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contacts Saved Successfully'), backgroundColor: AppColors.success),
        );
        Navigator.pop(context);
      }
    }
  }

  void _showAddContactDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.darkSurface,
          title: const Text('Add Emergency Contact'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(controller: _nameController, labelText: 'Name'),
              const SizedBox(height: 12),
              CustomTextField(controller: _phoneController, labelText: 'Phone Number', keyboardType: TextInputType.phone),
              const SizedBox(height: 12),
              CustomTextField(controller: _relationController, labelText: 'Relationship (e.g. Spouse/Parent)'),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(onPressed: _addContact, child: const Text('Add')),
          ],
        );
      },
    );
  }

  Future<void> _importDeviceContacts() async {
    final contacts = await EmergencyContactNotificationService.getDeviceContacts();
    if (!mounted) return;

    if (contacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No device contacts available or permission was denied.')),
      );
      return;
    }

    final selected = await showModalBottomSheet<List<EmergencyContact>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final selectedPhones = <String>{};
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.75,
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Select Emergency Contacts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: contacts.length,
                        itemBuilder: (context, index) {
                          final contact = contacts[index];
                          final selected = selectedPhones.contains(contact.phone);
                          return CheckboxListTile(
                            value: selected,
                            title: Text(contact.name),
                            subtitle: Text(contact.phone),
                            onChanged: (value) {
                              setSheetState(() {
                                if (value == true) {
                                  selectedPhones.add(contact.phone);
                                } else {
                                  selectedPhones.remove(contact.phone);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: CustomButton(
                        text: 'Add Selected',
                        onPressed: () {
                          Navigator.pop(
                            ctx,
                            contacts.where((contact) => selectedPhones.contains(contact.phone)).toList(),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (selected == null || selected.isEmpty) return;
    setState(() {
      for (final contact in selected) {
        if (!_contacts.any((existing) => existing.phone == contact.phone)) {
          _contacts.add(contact);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = Provider.of<ProfileProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Emergency Contacts')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Expanded(
              child: _contacts.isEmpty
                  ? const Center(
                      child: Text('No Emergency Contacts added yet.', style: TextStyle(color: Colors.white60)),
                    )
                  : ListView.builder(
                      itemCount: _contacts.length,
                      itemBuilder: (ctx, index) {
                        final c = _contacts[index];
                        return Card(
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: AppColors.primary,
                              child: Icon(Icons.phone, color: Colors.white),
                            ),
                            title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${c.phone} • ${c.relationship}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              onPressed: () {
                                setState(() => _contacts.removeAt(index));
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showAddContactDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Contact'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _importDeviceContacts,
                    icon: const Icon(Icons.contacts_outlined),
                    label: const Text('Import'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomButton(
                    text: 'Save Contacts',
                    isLoading: profileProvider.isLoading,
                    onPressed: _saveContacts,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
