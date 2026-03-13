import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ReportDetailsScreen extends StatelessWidget {
  const ReportDetailsScreen({super.key, required this.reportData});

  final Map<String, dynamic> reportData;

  Color _severityColor(String severity) {
    switch (severity.toUpperCase()) {
      case 'RED':
        return Colors.red;
      case 'ORANGE':
        return Colors.orange;
      case 'YELLOW':
        return Colors.amber;
      case 'GREEN':
        return Colors.green;
      default:
        return Colors.blueGrey;
    }
  }

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

  Future<void> _openAudio(BuildContext context, String url) async {
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open audio file.')),
      );
    }
  }

  void _viewImage(BuildContext context, String imageUrl) {
    showDialog<void>(
      context: context,
      builder: (_) {
        return Dialog(
          child: InteractiveViewer(
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Unable to load image'),
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final type = (reportData['type'] ?? 'INCIDENT').toString().toUpperCase();
    final severity = (reportData['severity'] ?? 'GREEN').toString();
    final description =
        (reportData['description'] ?? reportData['message'] ?? '').toString();
    final latitude = _asDouble(reportData['latitude']);
    final longitude = _asDouble(reportData['longitude']);
    final imageUrl = (reportData['imageUrl'] ?? '').toString();
    final audioUrl = (reportData['audioUrl'] ?? '').toString();
    final createdAt = _createdAt(reportData['createdAt']);

    return Scaffold(
      appBar: AppBar(title: const Text('Report Details')),
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
                Row(
                  children: [
                    Icon(Icons.report, color: _severityColor(severity)),
                    const SizedBox(width: 8),
                    Text(
                      'Type: $type',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Severity: ${severity.toUpperCase()}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _severityColor(severity),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Description',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(description.isEmpty ? 'No description' : description),
                const SizedBox(height: 12),
                const Text(
                  'Location',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text('Latitude: $latitude'),
                Text('Longitude: $longitude'),
                const SizedBox(height: 12),
                Text(
                  'Date: ${createdAt.toLocal()}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _openMap(context, latitude, longitude),
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('View Location'),
                    ),
                    OutlinedButton.icon(
                      onPressed: imageUrl.isEmpty
                          ? null
                          : () => _viewImage(context, imageUrl),
                      icon: const Icon(Icons.image_outlined),
                      label: const Text('View Image'),
                    ),
                    OutlinedButton.icon(
                      onPressed: audioUrl.isEmpty
                          ? null
                          : () => _openAudio(context, audioUrl),
                      icon: const Icon(Icons.play_circle_outline),
                      label: const Text('Play Audio'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
