import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../controllers/contact_controller.dart';
import '../models/emergency_contact_model.dart';
import 'success_screen.dart';

class EmergencyContactScreen extends StatefulWidget {
  const EmergencyContactScreen({super.key});

  @override
  State<EmergencyContactScreen> createState() => _EmergencyContactScreenState();
}

class _EmergencyContactScreenState extends State<EmergencyContactScreen> {
  final _formKey = GlobalKey<FormState>();
  final ContactController _contactController = ContactController();

  final List<TextEditingController> contactControllers = List.generate(
    3,
    (_) => TextEditingController(),
  );

  String? errorMessage;

  bool isValidPhone(String value) {
    return RegExp(r'^\d{10}$').hasMatch(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency Contacts')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const Text(
                'Enter Emergency Contact Numbers (Minimum 2)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              for (int i = 0; i < 3; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextFormField(
                    controller: contactControllers[i],
                    decoration: InputDecoration(labelText: 'Contact ${i + 1}'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              if (errorMessage != null)
                Text(errorMessage!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  // int filledCount = 0;

                  // for (var controller in contactControllers) {
                  //   if (controller.text.isNotEmpty) {
                  //     if (!isValidPhone(controller.text)) {
                  //       setState(() {
                  //         errorMessage =
                  //             'All filled contacts must be exactly 10 digits';
                  //       });
                  //       return;
                  //     }
                  //     filledCount++;
                  //   }
                  // }

                  // if (filledCount < 2) {
                  //   setState(() {
                  //     errorMessage =
                  //         'Please enter at least 2 emergency contacts';
                  //   });
                  //   return;
                  // }

                  // setState(() {
                  //   errorMessage = null;
                  // });

                  // final contacts = EmergencyContactModel(
                  //   contact1: contactControllers[0].text,
                  //   contact2: contactControllers[1].text,
                  //   contact3: contactControllers[2].text,
                  //   createdAt: Timestamp.now(),
                  // );

                  // await _contactController.saveEmergencyContacts(contacts);

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SuccessScreen(),
                    ),
                  );
                },
                child: const Text('Finish Setup'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
