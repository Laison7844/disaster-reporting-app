import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/firestore_service.dart';
import '../widgets/custom_textfield.dart';
import 'home_screen.dart';

class EmergencyContactsSetupScreen extends StatefulWidget {
  const EmergencyContactsSetupScreen({super.key});

  @override
  State<EmergencyContactsSetupScreen> createState() =>
      _EmergencyContactsSetupScreenState();
}

class _EmergencyContactsSetupScreenState
    extends State<EmergencyContactsSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _contact1Controller = TextEditingController();
  final _contact2Controller = TextEditingController();
  final _contact3Controller = TextEditingController();

  bool _isSaving = false;

  @override
  void dispose() {
    _contact1Controller.dispose();
    _contact2Controller.dispose();
    _contact3Controller.dispose();
    super.dispose();
  }

  String? _validateContact(String? value) {
    final contact = value?.trim() ?? '';
    if (contact.isEmpty) {
      return null;
    }
    if (!RegExp(r'^[0-9]{10}$').hasMatch(contact)) {
      return 'Enter a valid 10 digit mobile number';
    }
    return null;
  }

  Future<void> _saveContacts() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final contacts = <String>[
      _contact1Controller.text.trim(),
      _contact2Controller.text.trim(),
      _contact3Controller.text.trim(),
    ].where((value) => value.isNotEmpty).toList();
    if (contacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one emergency contact number.'),
        ),
      );
      return;
    }

    if (_isSaving) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      await FirestoreService.instance.saveEmergencyContacts(
        contact1: _contact1Controller.text,
        contact2: _contact2Controller.text,
        contact3: _contact3Controller.text,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _skipForNow() async {
    if (_isSaving) {
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency Contacts Setup')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Add emergency contact mobile numbers. Contacts must be registered in this app.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                const Text(
                  'You can skip now and add at least one later from Home.',
                ),
                const SizedBox(height: 18),
                CustomTextField(
                  controller: _contact1Controller,
                  label: 'Emergency Contact 1',
                  icon: Icons.phone,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 10,
                  validator: _validateContact,
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: _contact2Controller,
                  label: 'Emergency Contact 2',
                  icon: Icons.phone,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 10,
                  validator: _validateContact,
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: _contact3Controller,
                  label: 'Emergency Contact 3',
                  icon: Icons.phone,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 10,
                  validator: _validateContact,
                ),
                const SizedBox(height: 22),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveContacts,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save Emergency Contacts'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 46,
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : _skipForNow,
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Skip For Now'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
