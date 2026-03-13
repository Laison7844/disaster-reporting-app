import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ActionResultScreen extends StatefulWidget {
  final String action;
  final String service;

  const ActionResultScreen(this.action, this.service, {super.key});

  @override
  State<ActionResultScreen> createState() => _ActionResultScreenState();
}

class _ActionResultScreenState extends State<ActionResultScreen> {
  final TextEditingController messageController = TextEditingController();
  File? imageFile;

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(source: ImageSource.camera);

    if (picked != null) {
      setState(() {
        imageFile = File(picked.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSMS = widget.action.contains('SMS');
    final isCamera = widget.action.contains('Camera');

    return Scaffold(
      appBar: AppBar(title: Text('${widget.action} ${widget.service}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (isSMS) ...[
              TextField(
                controller: messageController,
                maxLines: 5,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Type your message here',
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Message queued successfully'),
                    ),
                  );
                },
                child: const Text('Send'),
              ),
            ],
            if (isCamera) ...[
              ElevatedButton.icon(
                onPressed: pickImage,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Open Camera'),
              ),
              const SizedBox(height: 20),
              if (imageFile != null)
                Column(
                  children: [
                    Image.file(imageFile!, height: 200),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Image uploaded successfully'),
                          ),
                        );
                      },
                      child: const Text('Upload'),
                    ),
                  ],
                ),
            ],
            if (!isSMS && !isCamera)
              Center(
                child: Text(
                  '${widget.action} ${widget.service}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
