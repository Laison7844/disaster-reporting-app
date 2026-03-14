import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../firebase/firebase_constants.dart';
import '../services/admin_service.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../widgets/network_audio_player.dart';
import '../widgets/severity_badge.dart';
import 'login_screen.dart';
import 'report_details_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.instance.flushPendingNavigation();
    });
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

  Future<bool> _confirmDeleteReport(String reportId) async {
    final shouldDelete =
        await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Delete Report'),
              content: const Text(
                'Are you sure you want to delete this report?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldDelete) {
      return false;
    }

    try {
      await AdminService.instance.deleteReport(reportId);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Report deleted.')));
      }
      return true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete report: $error')),
        );
      }
      return false;
    }
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
        body: TabBarView(
          children: [
            _ReportsTab(
              typeFilter: 'SOS',
              emptyMessage: 'No SOS alerts found.',
              formatDate: _formatDate,
              asDouble: _asDouble,
              onOpenMap: _openMap,
              onDeleteReport: _confirmDeleteReport,
            ),
            _ReportsTab(
              typeFilter: 'INCIDENT',
              emptyMessage: 'No incident reports found.',
              formatDate: _formatDate,
              asDouble: _asDouble,
              onOpenMap: _openMap,
              onDeleteReport: _confirmDeleteReport,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportsTab extends StatelessWidget {
  const _ReportsTab({
    required this.typeFilter,
    required this.emptyMessage,
    required this.formatDate,
    required this.asDouble,
    required this.onOpenMap,
    required this.onDeleteReport,
  });

  final String typeFilter;
  final String emptyMessage;
  final String Function(dynamic value) formatDate;
  final double Function(dynamic value) asDouble;
  final Future<void> Function(BuildContext context, double lat, double lng)
  onOpenMap;
  final Future<bool> Function(String reportId) onDeleteReport;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(FirebaseCollections.reports)
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

        final docs =
            snapshot.data?.docs
                .where(
                  (doc) =>
                      (doc.data()['type'] ?? '').toString().toUpperCase() ==
                      typeFilter,
                )
                .toList() ??
            <QueryDocumentSnapshot<Map<String, dynamic>>>[];

        if (docs.isEmpty) {
          return Center(child: Text(emptyMessage));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final doc = docs[index];
            return Dismissible(
              key: ValueKey('admin_report_${doc.id}'),
              direction: DismissDirection.endToStart,
              confirmDismiss: (_) => onDeleteReport(doc.id),
              background: Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.red.shade600,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Delete',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              secondaryBackground: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.red.shade600,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(Icons.delete_outline, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Delete',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              child: _AdminReportCard(
                reportId: doc.id,
                data: doc.data(),
                formatDate: formatDate,
                asDouble: asDouble,
                onOpenMap: onOpenMap,
              ),
            );
          },
        );
      },
    );
  }
}

class _AdminReportCard extends StatelessWidget {
  const _AdminReportCard({
    required this.reportId,
    required this.data,
    required this.formatDate,
    required this.asDouble,
    required this.onOpenMap,
  });

  final String reportId;
  final Map<String, dynamic> data;
  final String Function(dynamic value) formatDate;
  final double Function(dynamic value) asDouble;
  final Future<void> Function(BuildContext context, double lat, double lng)
  onOpenMap;

  @override
  Widget build(BuildContext context) {
    final description =
        (data['description'] ?? data['message'] ?? 'No description').toString();
    final reporterName = (data['reporterName'] ?? 'Unknown Reporter')
        .toString();
    final severity = (data['severity'] ?? 'GREEN').toString();
    final tag = (data['tag'] ?? '').toString();
    final latitude = asDouble(data['latitude']);
    final longitude = asDouble(data['longitude']);
    final imageUrl = (data['imageUrl'] ?? '').toString();
    final audioUrl = (data['audioUrl'] ?? '').toString();

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openDetails(context),
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
              if (tag.isNotEmpty) ...[
                const SizedBox(height: 10),
                Chip(label: Text(tag)),
              ],
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
              const SizedBox(height: 6),
              Text('Timestamp: ${formatDate(data['createdAt'])}'),
              Text('Location: $latitude, $longitude'),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _openDetails(context),
                    icon: const Icon(Icons.article_outlined),
                    label: const Text('View Details'),
                  ),
                  TextButton.icon(
                    onPressed: () => onOpenMap(context, latitude, longitude),
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Open Map'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openDetails(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReportDetailsScreen(
          reportData: {...data, 'id': reportId},
          title: 'Admin Report Details',
        ),
      ),
    );
  }
}
