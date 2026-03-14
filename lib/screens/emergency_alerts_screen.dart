import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../firebase/firebase_constants.dart';
import '../models/received_emergency_alert.dart';
import '../services/emergency_alerts_service.dart';
import '../widgets/network_audio_player.dart';
import '../widgets/severity_badge.dart';
import 'emergency_details_page.dart';

class EmergencyAlertsScreen extends StatefulWidget {
  const EmergencyAlertsScreen({super.key});

  @override
  State<EmergencyAlertsScreen> createState() => _EmergencyAlertsScreenState();
}

class _EmergencyAlertsScreenState extends State<EmergencyAlertsScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<ReceivedEmergencyAlert> _alerts = [];
  DocumentSnapshot? _lastDocument;
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchAlerts();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMore) {
      _fetchAlerts();
    }
  }

  Future<void> _fetchAlerts({bool refresh = false}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
      if (refresh) {
        _alerts.clear();
        _lastDocument = null;
        _hasMore = true;
      }
    });

    try {
      var query = FirebaseFirestore.instance
          .collection(FirebaseCollections.reports)
          .orderBy('createdAt', descending: true)
          .limit(10);

      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final snapshot = await query.get();

      if (snapshot.docs.length < 10) {
        _hasMore = false;
      }

      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
        final newAlerts = snapshot.docs.map((doc) {
          final data = doc.data();
          return ReceivedEmergencyAlert.fromMap({...data, 'id': doc.id});
        }).toList();

        setState(() {
          _alerts.addAll(newAlerts);
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load alerts: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Emergency Alerts',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _confirmClearAlerts,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _fetchAlerts(refresh: true),
        child: _error != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_error!),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _fetchAlerts(refresh: true),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            : _alerts.isEmpty && !_isLoading
            ? const Center(child: Text('No emergency alerts received yet.'))
            : ListView.separated(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _alerts.length + (_isLoading ? 1 : 0),
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  if (index < _alerts.length) {
                    return _AlertCard(alert: _alerts[index]);
                  } else {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                },
              ),
      ),
    );
  }

  Future<void> _confirmClearAlerts() async {
    final shouldClear =
        await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Clear Alerts'),
              content: const Text(
                'Remove all saved emergency alerts from this device?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Clear'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldClear) {
      return;
    }

    await EmergencyAlertsService.instance.clearAlerts();
    _fetchAlerts(refresh: true);
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert});

  final ReceivedEmergencyAlert alert;

  @override
  Widget build(BuildContext context) {
    final locationText = alert.hasLocation
        ? '${alert.latitude!.toStringAsFixed(5)}, ${alert.longitude!.toStringAsFixed(5)}'
        : 'Location not provided';

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => EmergencyDetailsPage(
                message: alert.description,
                reporterName: alert.reporterName,
                severity: alert.severity,
                lat: alert.latitude,
                lng: alert.longitude,
                imageUrl: alert.imageUrl,
                audioUrl: alert.audioUrl,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                alert.title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (alert.reporterName.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Reporter: ${alert.reporterName}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
              if (alert.severity.isNotEmpty) ...[
                const SizedBox(height: 8),
                SeverityBadge(severity: alert.severity),
              ],
              const SizedBox(height: 10),
              Text(alert.description),
              const SizedBox(height: 10),
              Text('Location: $locationText'),
              Text(
                'Received: ${_formatDate(alert.createdAt)}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
              ),
              if (alert.imageUrl.isNotEmpty) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    alert.imageUrl,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 120,
                        alignment: Alignment.center,
                        color: Colors.grey.shade100,
                        child: const Text('Unable to load image preview.'),
                      );
                    },
                  ),
                ),
              ],
              if (alert.audioUrl.isNotEmpty) ...[
                const SizedBox(height: 12),
                NetworkAudioPlayer(
                  audioUrl: alert.audioUrl,
                  label: 'Voice message attached',
                  compact: true,
                ),
              ],
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => EmergencyDetailsPage(
                          message: alert.description,
                          reporterName: alert.reporterName,
                          severity: alert.severity,
                          lat: alert.latitude,
                          lng: alert.longitude,
                          imageUrl: alert.imageUrl,
                          audioUrl: alert.audioUrl,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open Alert'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}
