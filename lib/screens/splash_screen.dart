import 'package:flutter/material.dart';

import '../services/firestore_service.dart';
import '../services/permission_service.dart';
import 'admin_dashboard_screen.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _goNext();
  }

  Future<void> _goNext() async {
    final permissionsGranted = await PermissionService.instance
        .requestPermissionsOnFirstLaunch();
    if (!permissionsGranted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Permission is required for emergency reporting features.',
          ),
        ),
      );
    }

    await FirestoreService.instance.loadSession();
    if (!mounted) {
      return;
    }

    Widget destination = const LoginScreen();
    if (FirestoreService.instance.isAdminLoggedIn) {
      destination = const AdminDashboardScreen();
    } else if (FirestoreService.instance.isLoggedIn) {
      destination = const HomeScreen();
    }

    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => destination));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.red.shade50, Colors.white],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/images/emergency_logo.png', width: 220),
              const SizedBox(height: 20),
              Text(
                'Real-Time Emergency Reporting',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Preparing emergency services...',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}
