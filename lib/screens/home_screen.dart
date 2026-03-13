import 'package:flutter/material.dart';

import '../services/firestore_service.dart';
import '../services/report_service.dart';
import 'emergency_contacts_edit_screen.dart';
import 'login_screen.dart';
import 'my_reports_screen.dart';
import 'report_incident_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isSendingSos = false;
  bool _isLoggingOut = false;
  bool _isLoadingContacts = true;
  List<String> _emergencyContacts = <String>[];
  bool _hasShownInitialReminder = false;

  @override
  void initState() {
    super.initState();
    ReportService.instance.startAutoSync();
    ReportService.instance.syncPendingQueue();
    _initializeHome();
  }

  Future<void> _initializeHome() async {
    await _loadContacts();
    if (!mounted || _hasShownInitialReminder || _emergencyContacts.isNotEmpty) {
      return;
    }
    _hasShownInitialReminder = true;
    await _showEmergencyContactRequiredDialog();
  }

  Future<void> _loadContacts() async {
    setState(() => _isLoadingContacts = true);
    final contacts = await FirestoreService.instance.getEmergencyContacts();
    if (!mounted) {
      return;
    }
    setState(() {
      _emergencyContacts = contacts;
      _isLoadingContacts = false;
    });
  }

  Future<void> _openEditContacts() async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            EmergencyContactsEditScreen(contacts: _emergencyContacts),
      ),
    );
    if (updated == true) {
      await _loadContacts();
    }
  }

  Future<bool> _ensureEmergencyContactExists() async {
    if (_isLoadingContacts) {
      await _loadContacts();
    }

    if (_emergencyContacts.isNotEmpty) {
      return true;
    }

    await _showEmergencyContactRequiredDialog();
    return _emergencyContacts.isNotEmpty;
  }

  Future<void> _showEmergencyContactRequiredDialog() async {
    final shouldAddContact =
        await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Emergency Contact Required'),
              content: const Text(
                'You must add at least one emergency contact before using emergency features.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Add Contact'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (shouldAddContact) {
      await _openEditContacts();
    }
  }

  Future<void> _triggerSos() async {
    final hasContacts = await _ensureEmergencyContactExists();
    if (!hasContacts || _isSendingSos) {
      return;
    }

    setState(() => _isSendingSos = true);

    try {
      final result = await ReportService.instance.createSosReport();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
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
        setState(() => _isSendingSos = false);
      }
    }
  }

  Future<void> _confirmLogout() async {
    if (_isLoggingOut) {
      return;
    }

    final shouldLogout =
        await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Logout'),
              content: const Text('Are you sure you want to logout?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('NO'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('YES'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldLogout) {
      return;
    }

    await _logout();
  }

  Future<void> _logout() async {
    if (_isLoggingOut) {
      return;
    }

    setState(() => _isLoggingOut = true);

    await FirestoreService.instance.logout();

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Emergency Home',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _isLoggingOut ? null : _confirmLogout,
            icon: _isLoggingOut
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'SOS alerts are sent only to your registered emergency contacts.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Emergency Services',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 10),
                    _EmergencyServiceRow(
                      icon: Icons.local_police_outlined,
                      label: 'Police',
                      number: '100',
                    ),
                    SizedBox(height: 8),
                    _EmergencyServiceRow(
                      icon: Icons.local_hospital_outlined,
                      label: 'Ambulance',
                      number: '108',
                    ),
                    SizedBox(height: 8),
                    _EmergencyServiceRow(
                      icon: Icons.local_fire_department_outlined,
                      label: 'Fire',
                      number: '101',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Emergency Contacts',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextButton(
                          onPressed: _openEditContacts,
                          child: const Text('Edit Contacts'),
                        ),
                      ],
                    ),
                    if (_isLoadingContacts)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else if (_emergencyContacts.isEmpty)
                      const Text('No emergency contacts added.')
                    else
                      for (final contact in _emergencyContacts)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text('📞 $contact'),
                        ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: GestureDetector(
                onDoubleTap: _triggerSos,
                child: Container(
                  width: 210,
                  height: 210,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x73F44336),
                        blurRadius: 24,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                  child: _isSendingSos
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.notification_important,
                              size: 72,
                              color: Colors.white,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'SOS',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Double Tap',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                final hasContacts = await _ensureEmergencyContactExists();
                if (!hasContacts || !context.mounted) {
                  return;
                }
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ReportIncidentScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.report_gmailerrorred),
              label: const Text('Report Incident'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MyReportsScreen()),
                );
              },
              icon: const Icon(Icons.history),
              label: const Text('View My Reports'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmergencyServiceRow extends StatelessWidget {
  const _EmergencyServiceRow({
    required this.icon,
    required this.label,
    required this.number,
  });

  final IconData icon;
  final String label;
  final String number;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(child: Text(label)),
        Text(
          number,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
