import 'package:flutter/material.dart';
import '../controllers/emergency_controller.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  final EmergencyController _emergencyController = EmergencyController();

  @override
  void initState() {
    super.initState();
    _triggerSos();
  }

  Future<void> _triggerSos() async {
    await _emergencyController.triggerSos();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const Center(
        child: Text(
          'HELP IS ON THE WAY',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
