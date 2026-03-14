import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/emergency_report.dart';
import '../screens/report_details_screen.dart';
import 'network_audio_player.dart';
import 'severity_badge.dart';

class ReportCard extends StatelessWidget {
  const ReportCard({super.key, required this.report});

  final EmergencyReport report;

  @override
  Widget build(BuildContext context) {
    final position = LatLng(report.latitude, report.longitude);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openDetails(context),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SeverityBadge(severity: report.severity),
                  Text(
                    report.status,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                report.type,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(report.description),
              if (report.tag.isNotEmpty) ...[
                const SizedBox(height: 8),
                Chip(label: Text(report.tag)),
              ],
              const SizedBox(height: 8),
              Text(
                _formatDate(report.createdAt),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
              ),
              if (report.imageUrl.isNotEmpty) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    report.imageUrl,
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
              if (report.audioUrl.isNotEmpty) ...[
                const SizedBox(height: 12),
                NetworkAudioPlayer(
                  audioUrl: report.audioUrl,
                  label: 'Voice message attached',
                  compact: true,
                ),
              ],
              const SizedBox(height: 10),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _openMap(context),
                child: SizedBox(
                  height: 160,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: GoogleMap(
                      key: ValueKey('map_${report.id}'),
                      initialCameraPosition: CameraPosition(
                        target: position,
                        zoom: 15,
                      ),
                      markers: {
                        Marker(
                          markerId: MarkerId('marker_${report.id}'),
                          position: position,
                        ),
                      },
                      myLocationButtonEnabled: false,
                      mapToolbarEnabled: false,
                      zoomControlsEnabled: false,
                      compassEnabled: false,
                      tiltGesturesEnabled: false,
                      rotateGesturesEnabled: false,
                      scrollGesturesEnabled: false,
                      zoomGesturesEnabled: false,
                      liteModeEnabled: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _openDetails(context),
                    icon: const Icon(Icons.article_outlined),
                    label: const Text('View Details'),
                  ),
                  TextButton.icon(
                    onPressed: () => _openMap(context),
                    icon: const Icon(Icons.open_in_new),
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

  String _formatDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    return '${local.year}-${_twoDigits(local.month)}-${_twoDigits(local.day)} '
        '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');

  void _openDetails(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReportDetailsScreen(reportData: report.toMap()),
      ),
    );
  }

  Future<void> _openMap(BuildContext context) async {
    final url =
        'https://www.google.com/maps/search/?api=1&query=${report.latitude},${report.longitude}';
    final launched = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );

    if (!launched && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open map.')));
    }
  }
}
