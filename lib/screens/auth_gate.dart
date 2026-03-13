import 'package:flutter/material.dart';

import '../services/firestore_service.dart';
import 'admin_dashboard_screen.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    await FirestoreService.instance.loadSession();
    if (!mounted) {
      return;
    }
    setState(() => _isInitializing = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (FirestoreService.instance.isAdminLoggedIn) {
      return const AdminDashboardScreen();
    }

    if (FirestoreService.instance.isLoggedIn) {
      return const HomeScreen();
    }

    return const LoginScreen();
  }
}
