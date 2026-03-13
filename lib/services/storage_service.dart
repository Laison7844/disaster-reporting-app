import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

class StorageService {
  StorageService._();

  static final StorageService instance = StorageService._();

  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadFile({
    required File file,
    required String folder,
    required String userId,
    bool compressImage = false,
  }) async {
    final uploadFile = compressImage
        ? await _compressImageIfNeeded(file)
        : file;
    final fileExtension = _resolveExtension(
      file: uploadFile,
      compressImage: compressImage,
    );
    final fileName =
        '$userId-${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
    final ref = _storage.ref().child('$folder/$userId/$fileName');
    final metadata = SettableMetadata(
      contentType: _resolveContentType(
        file: uploadFile,
        compressImage: compressImage,
      ),
      cacheControl: 'public,max-age=3600',
    );

    final task = await ref
        .putFile(uploadFile, metadata)
        .timeout(const Duration(seconds: 20));
    return task.ref.getDownloadURL();
  }

  Future<File> _compressImageIfNeeded(File file) async {
    final extension = file.path.split('.').last.toLowerCase();
    if (!<String>{'jpg', 'jpeg', 'png', 'webp', 'heic'}.contains(extension)) {
      return file;
    }

    final tempDir = await getTemporaryDirectory();
    final targetPath =
        '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final compressed = await FlutterImageCompress.compressAndGetFile(
      file.path,
      targetPath,
      minWidth: 1024,
      quality: 75,
      format: CompressFormat.jpeg,
    );

    return compressed == null ? file : File(compressed.path);
  }

  String _resolveExtension({required File file, required bool compressImage}) {
    if (compressImage) {
      return 'jpg';
    }

    final extension = file.path.split('.').last.toLowerCase();
    if (extension.isEmpty) {
      return 'bin';
    }
    return extension;
  }

  String _resolveContentType({
    required File file,
    required bool compressImage,
  }) {
    if (compressImage) {
      return 'image/jpeg';
    }

    final extension = file.path.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'm4a':
        return 'audio/m4a';
      case 'aac':
        return 'audio/aac';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      default:
        return 'application/octet-stream';
    }
  }
}
