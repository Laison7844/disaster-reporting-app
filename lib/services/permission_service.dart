import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PermissionService {
  PermissionService._();

  static final PermissionService instance = PermissionService._();

  static const String _permissionsRequestedKey = 'permissions_requested_once';

  Future<bool> requestPermissionsOnFirstLaunch() async {
    if (kIsWeb) {
      return true;
    }

    final prefs = await SharedPreferences.getInstance();
    final requestedBefore = prefs.getBool(_permissionsRequestedKey) ?? false;

    if (requestedBefore) {
      return true;
    }

    final permissions = <Permission>[
      Permission.locationWhenInUse,
      Permission.camera,
      Permission.microphone,
      if (Platform.isAndroid) Permission.storage,
      if (Platform.isAndroid || Platform.isIOS) Permission.photos,
    ];

    final results = await permissions.request();
    await prefs.setBool(_permissionsRequestedKey, true);

    for (final status in results.values) {
      if (!status.isGranted && !status.isLimited) {
        return false;
      }
    }

    return true;
  }
}
