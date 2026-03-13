import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/firestore_service.dart';
import '../widgets/network_audio_player.dart';
import '../widgets/severity_badge.dart';
import 'login_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _isLoggingOut = false;

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
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Logout'),
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

  Future<void> _openMap(BuildContext context, double lat, double lng) async {
    final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open map.')));
    }
  }

  String _formatDate(dynamic value) {
    final createdAt = value is Timestamp
        ? value.toDate()
        : (value is DateTime ? value : DateTime.now());
    final local = createdAt.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  double _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse('$value') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: const Text(
            'Admin Dashboard',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'SOS Alerts'),
              Tab(text: 'Incident Reports'),
            ],
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
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('reports')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Text('Failed to load reports: ${snapshot.error}'),
              );
            }

            final docs = snapshot.data?.docs ?? [];
            final sosReports = docs
                .where(
                  (doc) =>
                      (doc.data()['type'] ?? '').toString().toUpperCase() ==
                      'SOS',
                )
                .toList();
            final incidentReports = docs
                .where(
                  (doc) =>
                      (doc.data()['type'] ?? '').toString().toUpperCase() !=
                      'SOS',
                )
                .toList();

            return TabBarView(
              children: [
                _buildReportList(
                  context: context,
                  reports: sosReports,
                  emptyMessage: 'No SOS alerts found.',
                ),
                _buildReportList(
                  context: context,
                  reports: incidentReports,
                  emptyMessage: 'No incident reports found.',
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildReportList({
    required BuildContext context,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> reports,
    required String emptyMessage,
  }) {
    if (reports.isEmpty) {
      return Center(child: Text(emptyMessage));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: reports.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) =>
          _buildReportCard(context, reports[index].data()),
    );
  }

  Widget _buildReportCard(BuildContext context, Map<String, dynamic> data) {
    final description =
        (data['description'] ?? data['message'] ?? 'No description').toString();
    final reporterName = (data['reporterName'] ?? 'Unknown Reporter')
        .toString();
    final severity = (data['severity'] ?? 'GREEN').toString();
    final latitude = _asDouble(data['latitude']);
    final longitude = _asDouble(data['longitude']);
    final imageUrl = (data['imageUrl'] ?? '').toString();
    final audioUrl = (data['audioUrl'] ?? '').toString();
    final locationText = '$latitude, $longitude';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              reporterName,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(description),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text(
                  'Severity:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                SeverityBadge(severity: severity),
              ],
            ),
            Text('Timestamp: ${_formatDate(data['createdAt'])}'),
            Text('Location: $locationText'),
            if (imageUrl.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  imageUrl,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 110,
                      alignment: Alignment.center,
                      color: Colors.grey.shade100,
                      child: const Text('Unable to load image preview.'),
                    );
                  },
                ),
              ),
            ],
            if (audioUrl.isNotEmpty) ...[
              const SizedBox(height: 12),
              NetworkAudioPlayer(
                audioUrl: audioUrl,
                label: 'Voice message attached',
                compact: true,
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () => _openMap(context, latitude, longitude),
                icon: const Icon(Icons.map_outlined),
                label: const Text('Open Map'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
