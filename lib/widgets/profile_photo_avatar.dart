import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../screens/safety/safety_shell.dart';
import '../services/profile_photo_service.dart';

/// Round avatar showing the user's own photo (stored on this device by
/// [ProfilePhotoService]) or their initials, with a camera badge to add,
/// change or remove the photo.
///
/// Used by both the Profile and Edit Profile pages, so they always show the
/// same photo: a change on either page updates the other immediately in real-time.
class ProfilePhotoAvatar extends StatefulWidget {
  final String uid;
  final String initials;

  /// Diameter of the inner circle.
  final double size;

  const ProfilePhotoAvatar({
    super.key,
    required this.uid,
    required this.initials,
    this.size = 84,
  });

  @override
  State<ProfilePhotoAvatar> createState() => _ProfilePhotoAvatarState();
}

class _ProfilePhotoAvatarState extends State<ProfilePhotoAvatar> {
  static const Color _azure = Color(0xFF007FFF);
  static const Color _dodger = Color(0xFF1E90FF);
  static const Color _ink = Color(0xFF0B2545);
  static const Color _line = Color(0xFFD6ECFF);
  static const Color _danger = Color(0xFFD93025);

  final _service = ProfilePhotoService.instance;
  late Future<File?> _photo = _service.load(widget.uid);
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _service.changes.addListener(_reload);
  }

  @override
  void didUpdateWidget(covariant ProfilePhotoAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid) _reload();
  }

  @override
  void dispose() {
    _service.changes.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    if (mounted) setState(() => _photo = _service.load(widget.uid));
  }

  Future<void> _run(Future<void> Function() action, String failure) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(failure, style: GoogleFonts.outfit()),
            backgroundColor: _danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _optionIcon(IconData icon, Color color) => Container(
    width: 38,
    height: 38,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Icon(icon, color: color, size: 20),
  );

  Future<void> _showOptions(bool hasPhoto) async {
    // Hide the floating SOS button while this menu is open so it does not
    // cover the options. SOS itself keeps working.
    SafetyShell.sosButtonHiders.value++;
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Profile photo',
                style: GoogleFonts.outfit(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: _optionIcon(Icons.photo_library_outlined, _azure),
                title: Text(
                  hasPhoto ? 'Change photo' : 'Choose from gallery',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w600,
                    color: _ink,
                  ),
                ),
                onTap: () => Navigator.of(sheetContext).pop('pick'),
              ),
              if (hasPhoto)
                ListTile(
                  leading: _optionIcon(Icons.delete_outline_rounded, _danger),
                  title: Text(
                    'Remove photo',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600,
                      color: _danger,
                    ),
                  ),
                  onTap: () => Navigator.of(sheetContext).pop('remove'),
                ),
            ],
          ),
        ),
      ),
    );
    SafetyShell.sosButtonHiders.value--;
    if (choice == 'pick') {
      await _run(
        () => _service.pickFromGallery(widget.uid),
        'Could not add the photo. Please try again.',
      );
    } else if (choice == 'remove') {
      await _run(
        () => _service.remove(widget.uid),
        'Could not remove the photo. Please try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<File?>(
    future: _photo,
    // Show a photo already loaded this session straight away (no initials
    // flash when switching tabs or opening Edit Profile).
    initialData: _service.cached(widget.uid),
    builder: (context, snapshot) {
      final file = snapshot.data;
      final size = widget.size;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _line, width: 2),
            ),
            child: Container(
              width: size,
              height: size,
              alignment: Alignment.center,
              clipBehavior: Clip.antiAlias,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_azure, _dodger],
                ),
              ),
              child: file != null
                  ? Image.file(
                      file,
                      width: size,
                      height: size,
                      fit: BoxFit.cover,
                      semanticLabel: 'Profile photo',
                    )
                  : Text(
                      widget.initials,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: size * 0.36,
                      ),
                    ),
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Tooltip(
              message: file != null ? 'Change photo' : 'Add photo',
              child: Material(
                color: _azure,
                shape: const CircleBorder(
                  side: BorderSide(color: Colors.white, width: 3),
                ),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _busy || widget.uid.isEmpty
                      ? null
                      : () => _showOptions(file != null),
                  child: SizedBox(
                    width: 34,
                    height: 34,
                    child: _busy
                        ? const Padding(
                            padding: EdgeInsets.all(9),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.photo_camera_rounded,
                            color: Colors.white,
                            size: 17,
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}
