import 'package:flutter/material.dart';
import 'action_result_screen.dart';
import 'sms_options_screen.dart';
import 'sos_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  void showServiceOptions(BuildContext context, String actionType) {
    final services = [
      'Police',
      'Fire & Rescue',
      'Ambulance',
      'Control Room',
      'Emergency Contacts',
    ];

    showModalBottomSheet(
      context: context,
      builder: (_) {
        return ListView(
          children: services.map((service) {
            return ListTile(
              title: Text(service),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ActionResultScreen(actionType, service),
                  ),
                );
              },
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency Dashboard')),
      body: Column(
        children: [
          // 🔥 Incident images placeholder
          Container(
            height: 150,
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
            child: const Center(
              child: Text(
                'Reported incidents will appear here',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),

          // 📞 💬 📷 Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.phone, size: 30),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SmsOptionsScreen()),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.message, size: 30),
                onPressed: () => showServiceOptions(context, 'Sending SMS to'),
              ),
              IconButton(
                icon: const Icon(Icons.camera_alt, size: 30),
                onPressed: () =>
                    showServiceOptions(context, 'Opening Camera for'),
              ),
            ],
          ),

          // ⚠ Notifications placeholder
          Container(
            height: 120,
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(border: Border.all(color: Colors.orange)),
            child: const Center(
              child: Text(
                'Notifications and warnings will appear here',
                style: TextStyle(color: Colors.orange),
              ),
            ),
          ),

          const Spacer(),

          // 🚨 SOS button
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 15,
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SosScreen()),
                );
              },
              child: const Text(
                'SOS',
                style: TextStyle(fontSize: 22, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
