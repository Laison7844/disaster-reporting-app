import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/network_audio_player.dart';
import '../widgets/severity_badge.dart';

class EmergencyDetailsPage extends StatelessWidget {
  const EmergencyDetailsPage({
    super.key,
    required this.message,
    required this.lat,
    required this.lng,
    this.reporterName = '',
    this.severity = '',
    this.imageUrl = '',
    this.audioUrl = '',
  });

  final String message;
  final double lat;
  final double lng;
  final String reporterName;
  final String severity;
  final String imageUrl;
  final String audioUrl;

  Future<void> _openMap(BuildContext context) async {
    final mapUrl = !kIsWeb && Platform.isIOS
        ? 'https://maps.apple.com/?q=$lat,$lng'
        : 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    await _launchUrl(context, mapUrl, 'Could not open map application.');
  }

  Future<void> _launchUrl(
    BuildContext context,
    String value,
    String errorMessage,
  ) async {
    final launched = await launchUrl(
      Uri.parse(value),
      mode: LaunchMode.externalApplication,
    );

    if (!launched && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final position = LatLng(lat, lng);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Emergency Alert Details',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Description',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(message),
                      if (reporterName.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Reporter',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(reporterName),
                      ],
                      if (severity.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Severity',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        SeverityBadge(severity: severity),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Location Coordinates',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text('Latitude: $lat'),
                      Text('Longitude: $lng'),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          height: 180,
                          child: GoogleMap(
                            key: ValueKey('details_map_$lat$lng'),
                            initialCameraPosition: CameraPosition(
                              target: position,
                              zoom: 15,
                            ),
                            markers: {
                              Marker(
                                markerId: const MarkerId('details_location'),
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
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        onPressed: () => _openMap(context),
                        icon: const Icon(Icons.map),
                        label: const Text('Open Map'),
                      ),
                    ],
                  ),
                ),
              ),
              if (imageUrl.isNotEmpty) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Image Preview',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text('Unable to load image preview.'),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (audioUrl.isNotEmpty) ...[
                const SizedBox(height: 16),
                NetworkAudioPlayer(
                  audioUrl: audioUrl,
                  label: 'Voice message attached',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
