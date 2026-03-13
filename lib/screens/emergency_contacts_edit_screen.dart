import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/firestore_service.dart';
import '../widgets/custom_textfield.dart';

class EmergencyContactsEditScreen extends StatefulWidget {
  const EmergencyContactsEditScreen({super.key, required this.contacts});

  final List<String> contacts;

  @override
  State<EmergencyContactsEditScreen> createState() =>
      _EmergencyContactsEditScreenState();
}

class _EmergencyContactsEditScreenState
    extends State<EmergencyContactsEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _contact1Controller = TextEditingController();
  final _contact2Controller = TextEditingController();
  final _contact3Controller = TextEditingController();

  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    if (widget.contacts.isNotEmpty) {
      _contact1Controller.text = widget.contacts[0];
    }
    if (widget.contacts.length > 1) {
      _contact2Controller.text = widget.contacts[1];
    }
    if (widget.contacts.length > 2) {
      _contact3Controller.text = widget.contacts[2];
    }
  }

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

  Future<void> _updateContacts() async {
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

    if (_isUpdating) {
      return;
    }

    setState(() => _isUpdating = true);

    try {
      await FirestoreService.instance.saveEmergencyContacts(
        contact1: _contact1Controller.text,
        contact2: _contact2Controller.text,
        contact3: _contact3Controller.text,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Contacts updated')));
      Navigator.of(context).pop(true);
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
        setState(() => _isUpdating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Emergency Contacts')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                    onPressed: _isUpdating ? null : _updateContacts,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isUpdating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Update Contacts'),
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
