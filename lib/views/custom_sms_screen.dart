import 'package:flutter/material.dart';
import '../controllers/emergency_controller.dart';

class CustomSmsScreen extends StatefulWidget {
  const CustomSmsScreen({super.key});

  @override
  State<CustomSmsScreen> createState() => _CustomSmsScreenState();
}

class _CustomSmsScreenState extends State<CustomSmsScreen> {
  final TextEditingController controller = TextEditingController();
  final EmergencyController _emergencyController = EmergencyController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Type Message")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              // Fixed typo from TextFeild
              controller: controller,
              maxLines: 4,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "Enter your emergency message",
              ),
            ),
            const SizedBox(height: 20), // Fixed typo from SizeBox
            ElevatedButton(
              onPressed: () async {
                if (controller.text.isEmpty) return;

                await _emergencyController.sendToControlRoomAndContacts(
                  controller.text,
                );

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Message sent successfully")),
                  );
                  Navigator.pop(context);
                }
              },
              child: const Text("Send"),
            ),
          ],
        ),
      ),
    );
  }
}
