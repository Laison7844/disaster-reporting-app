import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../services/firestore_service.dart';
import '../services/report_service.dart';
import '../utils/severity_utils.dart';
import 'emergency_contacts_edit_screen.dart';

class ReportIncidentScreen extends StatefulWidget {
  const ReportIncidentScreen({super.key});

  @override
  State<ReportIncidentScreen> createState() => _ReportIncidentScreenState();
}

class _ReportIncidentScreenState extends State<ReportIncidentScreen> {
  final _descriptionController = TextEditingController();
  final _imagePicker = ImagePicker();
  final _audioRecorder = AudioRecorder();

  File? _imageFile;
  String? _audioPath;
  String _selectedSeverity = 'RED';
  bool _isRecording = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    if (source == ImageSource.camera) {
      final cameraPermission = await Permission.camera.request();
      if (!cameraPermission.isGranted) {
        _showMessage(
          'Camera permission is required to capture photo evidence.',
        );
        return;
      }
    }

    final file = await _imagePicker.pickImage(source: source, imageQuality: 70);
    if (file == null || !mounted) {
      return;
    }

    setState(() => _imageFile = File(file.path));
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _audioRecorder.stop();
      if (!mounted) {
        return;
      }

      setState(() {
        _isRecording = false;
        _audioPath = path;
      });
      return;
    }

    final micPermission = await Permission.microphone.request();
    if (!micPermission.isGranted) {
      _showMessage('Microphone permission is required for voice notes.');
      return;
    }

    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      _showMessage('Unable to access microphone.');
      return;
    }

    final tempDir = await getTemporaryDirectory();
    final path =
        '${tempDir.path}/incident_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _audioRecorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );

    if (!mounted) {
      return;
    }

    setState(() => _isRecording = true);
  }

  Future<void> _submit() async {
    final hasContacts = await _ensureEmergencyContactExists();
    if (!hasContacts) {
      return;
    }

    if (_isSubmitting) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final result = await ReportService.instance.createIncidentReport(
        description: _descriptionController.text,
        severity: _selectedSeverity,
        imageFile: _imageFile,
        audioFile: _audioPath == null ? null : File(_audioPath!),
      );

      if (!mounted) {
        return;
      }

      _showMessage(result.message);
      if (!result.wasQueued) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<bool> _ensureEmergencyContactExists() async {
    final contacts = await FirestoreService.instance.getEmergencyContacts();
    if (contacts.isNotEmpty) {
      return true;
    }

    if (!mounted) {
      return false;
    }

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

    if (!shouldAddContact || !mounted) {
      return false;
    }

    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EmergencyContactsEditScreen(contacts: contacts),
      ),
    );
    if (updated != true) {
      return false;
    }

    final refreshedContacts = await FirestoreService.instance
        .getEmergencyContacts();
    return refreshedContacts.isNotEmpty;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Report Incident',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              '1. Capture or upload photo evidence',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Camera'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo),
                  label: const Text('Gallery'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_imageFile != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(_imageFile!, height: 180, fit: BoxFit.cover),
              ),
            const SizedBox(height: 20),
            const Text(
              '2. Record voice message',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _toggleRecording,
              icon: Icon(_isRecording ? Icons.stop : Icons.mic),
              label: Text(_isRecording ? 'Stop Recording' : 'Start Recording'),
            ),
            if (_audioPath != null) ...[
              const SizedBox(height: 8),
              Text('Audio attached: ${_audioPath!.split('/').last}'),
            ],
            const SizedBox(height: 20),
            const Text(
              '3. Enter description',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Describe what happened (optional)...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '4. Select severity level',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _selectedSeverity,
              items: const [
                DropdownMenuItem(value: 'RED', child: Text('🔴 Critical')),
                DropdownMenuItem(value: 'ORANGE', child: Text('🟠 High')),
                DropdownMenuItem(value: 'YELLOW', child: Text('🟡 Medium')),
                DropdownMenuItem(value: 'GREEN', child: Text('🟢 Low')),
              ],
              decoration: const InputDecoration(border: OutlineInputBorder()),
              selectedItemBuilder: (context) {
                const severities = ['RED', 'ORANGE', 'YELLOW', 'GREEN'];
                return severities
                    .map((severity) => Text(getSeverityDisplay(severity)))
                    .toList();
              },
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() => _selectedSeverity = value);
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit Incident Report'),
            ),
          ],
        ),
      ),
    );
  }
}
