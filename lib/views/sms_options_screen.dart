import 'package:flutter/material.dart';
import '../controllers/emergency_controller.dart';
import 'custom_sms_screen.dart';

class SmsOptionsScreen extends StatelessWidget {
  const SmsOptionsScreen({super.key});

  final List<String> messages = const [
    "Fire",
    "Accident",
    "Emergency",
    "Medical Emergency",
    "Type a message",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Send Emergency SMS")),
      body: ListView.builder(
        itemCount: messages.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(messages[index]),
            onTap: () {
              if (messages[index] == "Type a message") {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CustomSmsScreen()),
                );
              } else {
                sendEmergencyMessage(context, messages[index]);
              }
            },
          );
        },
      ),
    );
  }

  Future<void> sendEmergencyMessage(
    BuildContext context,
    String message,
  ) async {
    final _emergencyController = EmergencyController();
    await _emergencyController.sendToControlRoomAndContacts(message);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Message sent successfully")),
      );
      Navigator.pop(context);
    }
  }
}
