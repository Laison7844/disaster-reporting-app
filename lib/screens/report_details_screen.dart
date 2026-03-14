import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../firebase/firebase_constants.dart';
import '../widgets/network_audio_player.dart';
import '../widgets/severity_badge.dart';
import 'full_screen_image_screen.dart';

class ReportDetailsScreen extends StatelessWidget {
  const ReportDetailsScreen({
    super.key,
    required this.reportData,
    this.title = 'Report Details',
  }) : reportId = null;

  const ReportDetailsScreen.fromReportId({
    super.key,
    required this.reportId,
    this.title = 'Report Details',
  }) : reportData = null;

  final Map<String, dynamic>? reportData;
  final String? reportId;
  final String title;

  @override
  Widget build(BuildContext context) {
    if (reportData != null) {
      return _ReportDetailsView(title: title, reportData: reportData!);
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(FirebaseCollections.reports)
          .doc(reportId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: Text(title)),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final data = snapshot.data?.data();
        if (data == null) {
          return Scaffold(
            appBar: AppBar(title: Text(title)),
            body: const Center(
              child: Text('Report not found or has been deleted.'),
            ),
          );
        }

        return _ReportDetailsView(title: title, reportData: data);
      },
    );
  }
}

class _ReportDetailsView extends StatelessWidget {
  const _ReportDetailsView({required this.title, required this.reportData});

  final String title;
  final Map<String, dynamic> reportData;

  DateTime _createdAt(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return DateTime.now();
  }

  double _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse('$value') ?? 0;
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

  @override
  Widget build(BuildContext context) {
    final reportId = (reportData['id'] ?? '').toString();
    final type = (reportData['type'] ?? 'INCIDENT').toString().toUpperCase();
    final severity = (reportData['severity'] ?? 'GREEN').toString();
    final description =
        (reportData['description'] ?? reportData['message'] ?? '').toString();
    final reporterName = (reportData['reporterName'] ?? 'Unknown Reporter')
        .toString();
    final tag = (reportData['tag'] ?? '').toString();
    final latitude = _asDouble(reportData['latitude']);
    final longitude = _asDouble(reportData['longitude']);
    final imageUrl = (reportData['imageUrl'] ?? '').toString();
    final audioUrl = (reportData['audioUrl'] ?? '').toString();
    final createdAt = _createdAt(reportData['createdAt']);
    final heroTag =
        'report_image_${reportId.isEmpty ? imageUrl.hashCode : reportId}';

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reporterName,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Chip(label: Text(type)),
                    SeverityBadge(severity: severity),
                    if (tag.isNotEmpty) Chip(label: Text(tag)),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Description',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(description.isEmpty ? 'No description' : description),
                const SizedBox(height: 16),
                const Text(
                  'Location',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text('Latitude: $latitude'),
                Text('Longitude: $longitude'),
                const SizedBox(height: 10),
                Text(
                  'Date: ${createdAt.toLocal()}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => _openMap(context, latitude, longitude),
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Open Map'),
                ),
                if (imageUrl.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Image',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => FullScreenImageScreen(
                            imageUrl: imageUrl,
                            heroTag: heroTag,
                          ),
                        ),
                      );
                    },
                    child: Hero(
                      tag: heroTag,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(
                          imageUrl,
                          width: double.infinity,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 160,
                              alignment: Alignment.center,
                              color: Colors.grey.shade100,
                              child: const Text('Unable to load image.'),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
                if (audioUrl.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  NetworkAudioPlayer(
                    audioUrl: audioUrl,
                    label: 'Voice message attached',
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
