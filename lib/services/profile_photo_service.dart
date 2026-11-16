import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores each signed-in user's profile photo on this device.
///
/// The picked image is copied into the app's private documents folder and its
/// path is remembered per user id in shared preferences. No Firestore or
/// Firebase Storage data is created or changed.
class ProfilePhotoService {
  ProfilePhotoService._();
  static final ProfilePhotoService instance = ProfilePhotoService._();

  final ImagePicker _picker = ImagePicker();

  /// Increments whenever a photo is added, replaced or removed.
  final ValueNotifier<int> changes = ValueNotifier<int>(0);

  String _key(String uid) => 'profile_photo_path_$uid';

  /// The saved photo for [uid], or null if none is stored.
  Future<File?> load(String uid) async {
    if (uid.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_key(uid));
    if (path == null) return null;
    final file = File(path);
    return await file.exists() ? file : null;
  }

  /// Lets the user choose a photo from the gallery and saves it for [uid].
  /// Returns the saved file, or null if the user cancelled.
  Future<File?> pickFromGallery(String uid) async {
    if (uid.isEmpty) return null;
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (picked == null) return null;

    final dir = await getApplicationDocumentsDirectory();
    final ext = picked.path.contains('.')
        ? picked.path.substring(picked.path.lastIndexOf('.'))
        : '.jpg';
    // A new name each time so the image cache never shows the old photo.
    final target = File(
      '${dir.path}/profile_photo_${uid}_${DateTime.now().millisecondsSinceEpoch}$ext',
    );
    await File(picked.path).copy(target.path);

    final old = await load(uid);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(uid), target.path);
    if (old != null && old.path != target.path) {
      try {
        await old.delete();
      } catch (_) {}
    }
    changes.value++;
    return target;
  }

  /// Removes the saved photo for [uid].
  Future<void> remove(String uid) async {
    final old = await load(uid);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(uid));
    if (old != null) {
      try {
        await old.delete();
      } catch (_) {}
    }
    changes.value++;
  }
}
