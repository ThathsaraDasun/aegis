import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores each user's profile photo.
///
/// The photo is saved in two places so it is always available:
/// * **Your account** – a small compressed JPEG (max 512 px) in the `photo`
///   field of `users/{uid}` (owner-only by the existing rules), so it survives
///   reinstalls, cleared app data and new phones.
/// * **This phone** – a copy in the app's private folder for instant, offline
///   display.
///
/// [changes] notifies every avatar on screen when the photo changes.
class ProfilePhotoService {
  ProfilePhotoService._();
  static final ProfilePhotoService instance = ProfilePhotoService._();

  final ImagePicker _picker = ImagePicker();

  /// Increments whenever a photo is added, replaced, removed or restored.
  final ValueNotifier<int> changes = ValueNotifier<int>(0);

  /// Photos already loaded this session, so avatars show them instantly.
  final Map<String, File?> _memory = {};

  static const String _field = 'photo';
  String _pathKey(String uid) => 'profile_photo_path_$uid';
  String _pendingKey(String uid) => 'profile_photo_pending_$uid';

  bool get _cloud => Firebase.apps.isNotEmpty;

  /// The photo already known for [uid] this session (no waiting).
  File? cached(String uid) => _memory[uid];

  /// The photo for [uid]: from memory, this phone, or your account.
  Future<File?> load(String uid) async {
    if (uid.isEmpty) return null;
    final known = _memory[uid];
    if (known != null && await known.exists()) return known;

    final local = await _loadLocal(uid);
    if (local != null) {
      _memory[uid] = local;
      // A photo picked offline (or before cloud saving existed) is uploaded
      // in the background so it is safe in the account too.
      _uploadIfPending(uid, local);
      return local;
    }

    final restored = await _loadFromAccount(uid);
    _memory[uid] = restored;
    return restored;
  }

  /// Lets the user choose a photo from the gallery and saves it for [uid].
  /// Returns the saved file, or null if the user cancelled.
  Future<File?> pickFromGallery(String uid) async {
    if (uid.isEmpty) return null;
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 75,
    );
    if (picked == null) return null;
    final bytes = await picked.readAsBytes();
    final file = await _saveLocal(uid, bytes);
    _memory[uid] = file;
    changes.value++;
    await _upload(uid, bytes);
    return file;
  }

  /// Removes the photo for [uid] from this phone and from the account.
  Future<void> remove(String uid) async {
    final old = await _loadLocal(uid);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pathKey(uid));
      await prefs.remove(_pendingKey(uid));
    } catch (_) {}
    if (old != null) {
      try {
        await old.delete();
      } catch (_) {}
    }
    _memory[uid] = null;
    changes.value++;
    if (_cloud) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set({_field: FieldValue.delete()}, SetOptions(merge: true))
            .timeout(const Duration(seconds: 8));
      } catch (_) {
        // Queued offline by Firestore; it syncs when the connection returns.
      }
    }
  }

  // ------------------------------------------------------------------ local

  Future<File?> _loadLocal(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final path = prefs.getString(_pathKey(uid));
      if (path == null) return null;
      final file = File(path);
      return await file.exists() ? file : null;
    } catch (_) {
      return null;
    }
  }

  Future<File> _saveLocal(String uid, Uint8List bytes) async {
    final dir = await getApplicationDocumentsDirectory();
    // A new name each time so the image cache never shows the old photo.
    final file = File(
      '${dir.path}/profile_photo_${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(bytes, flush: true);
    final old = await _loadLocal(uid);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pathKey(uid), file.path);
    if (old != null && old.path != file.path) {
      try {
        await old.delete();
      } catch (_) {}
    }
    return file;
  }

  // ---------------------------------------------------------------- account

  Future<void> _upload(String uid, Uint8List bytes) async {
    if (!_cloud) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pendingKey(uid), true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({
            _field: base64Encode(bytes),
            'photoUpdatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .timeout(const Duration(seconds: 10));
      await prefs.remove(_pendingKey(uid));
    } catch (_) {
      // Offline or slow: Firestore keeps the write queued; the pending flag
      // makes the next load try again too.
    }
  }

  bool _uploading = false;
  Future<void> _uploadIfPending(String uid, File local) async {
    if (!_cloud || _uploading) return;
    _uploading = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      var pending = prefs.getBool(_pendingKey(uid)) ?? false;
      if (!pending) {
        // Photos saved before cloud backup existed: upload once if the
        // account has no photo yet.
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get()
            .timeout(const Duration(seconds: 8));
        pending = doc.data()?[_field] == null;
      }
      if (pending) await _upload(uid, await local.readAsBytes());
    } catch (_) {
    } finally {
      _uploading = false;
    }
  }

  Future<File?> _loadFromAccount(String uid) async {
    if (!_cloud) return null;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 10));
      final data = doc.data()?[_field];
      if (data is! String || data.isEmpty) return null;
      return await _saveLocal(uid, base64Decode(data));
    } catch (_) {
      return null;
    }
  }
}
