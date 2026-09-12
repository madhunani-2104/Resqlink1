import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../providers/profile_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/models/user_model.dart';

import '../../../widgets/custom_button.dart';
import '../../../widgets/custom_textfield.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/emergency_contact_notification_service.dart';
import '../../../core/services/preference_service.dart';

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  final List<EmergencyContact> _contacts = [];

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _relationController = TextEditingController(
    text: 'Family',
  );

  bool _isImporting = false;

  @override
  void initState() {
    super.initState();

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final user = authProvider.user;

    if (user != null) {
      _contacts.addAll(user.emergencyContacts);
    }

    _loadSavedContacts();
  }

  Future<void> _loadSavedContacts() async {
    final savedUserData = await PreferenceService.getUserData();
    if (!mounted || savedUserData == null) return;

    final savedUser = UserModel.fromJson(savedUserData);
    setState(() {
      _contacts
        ..clear()
        ..addAll(savedUser.emergencyContacts);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _relationController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------
  // PHONE NUMBER NORMALIZATION
  // ------------------------------------------------------------

  String _normalizePhone(String phone) {
    return phone.replaceAll(RegExp(r'[^0-9+]'), '');
  }

  // ------------------------------------------------------------
  // ADD MANUAL CONTACT
  // ------------------------------------------------------------

  void _addContact() {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final relationship = _relationController.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter both name and phone number.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final normalizedPhone = _normalizePhone(phone);

    final exists = _contacts.any(
      (contact) => _normalizePhone(contact.phone) == normalizedPhone,
    );

    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This contact is already added.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _contacts.add(
        EmergencyContact(
          name: name,
          phone: phone,
          relationship: relationship.isEmpty ? 'Family' : relationship,
        ),
      );
    });

    _nameController.clear();
    _phoneController.clear();
    _relationController.text = 'Family';

    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Emergency contact added.'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  // ------------------------------------------------------------
  // SAVE CONTACTS
  // ------------------------------------------------------------

  Future<void> _saveContacts() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final profileProvider = Provider.of<ProfileProvider>(
      context,
      listen: false,
    );

    final user = authProvider.user;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User information is not available.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final success = await profileProvider.updateEmergencyContacts(
      user,
      _contacts,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Emergency contacts saved successfully.'),
          backgroundColor: AppColors.success,
        ),
      );

      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save emergency contacts.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ------------------------------------------------------------
  // ADD CONTACT DIALOG
  // ------------------------------------------------------------

  void _showAddContactDialog() {
    _nameController.clear();
    _phoneController.clear();
    _relationController.text = 'Family';

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.darkSurface,
          title: const Text(
            'Add Emergency Contact',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomTextField(controller: _nameController, labelText: 'Name'),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: _phoneController,
                  labelText: 'Phone Number',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: _relationController,
                  labelText: 'Relationship (e.g. Parent)',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(onPressed: _addContact, child: const Text('Add')),
          ],
        );
      },
    );
  }

  // ------------------------------------------------------------
  // REQUEST CONTACT PERMISSION
  // ------------------------------------------------------------

  Future<bool> _requestContactsPermission() async {
    PermissionStatus status = await Permission.contacts.status;

    if (status.isGranted) {
      return true;
    }

    if (status.isPermanentlyDenied) {
      if (!mounted) return false;

      final openSettings = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Contacts Permission Required'),
            content: const Text(
              'ResQ needs permission to read your phone contacts.\n\n'
              'The permission was permanently denied. '
              'Please enable Contacts permission from Android Settings.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(false);
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(true);
                },
                child: const Text('Open Settings'),
              ),
            ],
          );
        },
      );

      if (openSettings == true) {
        await openAppSettings();
      }

      return false;
    }

    status = await Permission.contacts.request();

    return status.isGranted;
  }

  // ------------------------------------------------------------
  // IMPORT DEVICE CONTACTS
  // ------------------------------------------------------------

  Future<void> _importDeviceContacts() async {
    if (_isImporting) return;

    setState(() {
      _isImporting = true;
    });

    try {
      final permissionGranted = await _requestContactsPermission();

      if (!mounted) return;

      if (!permissionGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contacts permission was not granted.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final deviceContacts =
          await EmergencyContactNotificationService.getDeviceContacts();

      if (!mounted) return;

      if (deviceContacts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No contacts with phone numbers were found.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final selected = await _showContactPicker(deviceContacts);

      if (!mounted || selected == null || selected.isEmpty) {
        return;
      }

      int addedCount = 0;

      setState(() {
        for (final contact in selected) {
          final normalizedPhone = _normalizePhone(contact.phone);

          final exists = _contacts.any(
            (existing) => _normalizePhone(existing.phone) == normalizedPhone,
          );

          if (!exists) {
            _contacts.add(contact);
            addedCount++;
          }
        }
      });

      if (!mounted) return;

      if (addedCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$addedCount contact(s) imported successfully.'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selected contacts are already added.')),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to import contacts: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  // ------------------------------------------------------------
  // CONTACT PICKER
  // ------------------------------------------------------------

  Future<List<EmergencyContact>?> _showContactPicker(
    List<EmergencyContact> contacts,
  ) async {
    final Set<String> selectedPhones = <String>{};

    return showModalBottomSheet<List<EmergencyContact>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Container(
                height: MediaQuery.of(context).size.height * 0.82,
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 45,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Icon(
                            Icons.contacts_rounded,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Select Emergency Contacts',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        '${contacts.length} device contacts found',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Divider(),
                    Expanded(
                      child: ListView.builder(
                        itemCount: contacts.length,
                        itemBuilder: (context, index) {
                          final contact = contacts[index];

                          final phone = _normalizePhone(contact.phone);

                          final isSelected = selectedPhones.contains(phone);

                          return CheckboxListTile(
                            value: isSelected,
                            activeColor: AppColors.primary,
                            title: Text(
                              contact.name.isEmpty
                                  ? 'Unnamed Contact'
                                  : contact.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(contact.phone),
                            secondary: CircleAvatar(
                              backgroundColor: AppColors.primary.withValues(
                                alpha: 0.12,
                              ),
                              child: const Icon(
                                Icons.person,
                                color: AppColors.primary,
                              ),
                            ),
                            onChanged: (value) {
                              setSheetState(() {
                                if (value == true) {
                                  selectedPhones.add(phone);
                                } else {
                                  selectedPhones.remove(phone);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: selectedPhones.isEmpty
                              ? null
                              : () {
                                  final selected = contacts
                                      .where(
                                        (contact) => selectedPhones.contains(
                                          _normalizePhone(contact.phone),
                                        ),
                                      )
                                      .toList();

                                  Navigator.of(sheetContext).pop(selected);
                                },
                          child: Text(
                            selectedPhones.isEmpty
                                ? 'Select Contacts'
                                : 'Add ${selectedPhones.length} Selected',
                          ),
                        ),
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
  }

  // ------------------------------------------------------------
  // DELETE CONTACT
  // ------------------------------------------------------------

  void _deleteContact(int index) {
    final contact = _contacts[index];

    setState(() {
      _contacts.removeAt(index);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${contact.name} removed.'),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () {
            if (!mounted) return;

            final insertIndex = index.clamp(0, _contacts.length);

            setState(() {
              _contacts.insert(insertIndex, contact);
            });
          },
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // CONTACT CARD
  // ------------------------------------------------------------

  Widget _buildContactCard(EmergencyContact contact, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: const CircleAvatar(
          backgroundColor: AppColors.primary,
          child: Icon(Icons.person, color: Colors.white),
        ),
        title: Text(
          contact.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('${contact.phone} • ${contact.relationship}'),
        ),
        trailing: IconButton(
          tooltip: 'Remove contact',
          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          onPressed: () {
            _deleteContact(index);
          },
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final profileProvider = Provider.of<ProfileProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Emergency Contacts')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // INFORMATION CARD
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.shield_rounded, color: AppColors.primary),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Emergency contacts can be notified when you send an SOS alert.',
                        style: TextStyle(fontSize: 13, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // CONTACT LIST
              Expanded(
                child: _contacts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.contact_phone_outlined,
                              size: 64,
                              color: Colors.grey.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'No Emergency Contacts',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Add a contact manually or import one from your phone.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _contacts.length,
                        itemBuilder: (context, index) {
                          return _buildContactCard(_contacts[index], index);
                        },
                      ),
              ),

              const SizedBox(height: 12),

              // ADD + IMPORT
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showAddContactDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Contact'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isImporting ? null : _importDeviceContacts,
                      icon: _isImporting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.contacts_outlined),
                      label: Text(_isImporting ? 'Importing...' : 'Import'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // SAVE
              SizedBox(
                width: double.infinity,
                child: CustomButton(
                  text: 'Save Contacts',
                  isLoading: profileProvider.isLoading,
                  onPressed: _saveContacts,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
