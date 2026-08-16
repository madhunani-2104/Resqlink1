// lib/core/services/contact_import_service.dart

import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';

class ContactImportService {
  static Future<List<Contact>> importContacts() async {
    final permission = await Permission.contacts.request();

    if (!permission.isGranted) {
      return <Contact>[];
    }

    try {
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );

      return contacts.where((contact) {
        return contact.phones.any((phone) => phone.number.trim().isNotEmpty);
      }).toList();
    } catch (e) {
      print('CONTACT IMPORT ERROR: $e');
      return <Contact>[];
    }
  }

  static Future<List<Map<String, String>>> getContacts() async {
    final contacts = await importContacts();

    final result = <Map<String, String>>[];

    for (final contact in contacts) {
      String name = contact.displayName.trim();

      if (name.isEmpty) {
        name = 'Unknown Contact';
      }

      final validPhones = contact.phones
          .map((phone) => phone.number.trim())
          .where((number) => number.isNotEmpty)
          .toList();

      if (validPhones.isEmpty) {
        continue;
      }

      result.add({'name': name, 'phone': validPhones.first});
    }

    return result;
  }

  static Future<bool> hasPermission() async {
    return Permission.contacts.isGranted;
  }

  static Future<bool> requestPermission() async {
    final status = await Permission.contacts.request();
    return status.isGranted;
  }

  static Future<bool> openSettings() async {
    return openAppSettings();
  }
}
