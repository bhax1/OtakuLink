import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:otakulink/core/models/user_model.dart';
import 'package:otakulink/repository/profile_repository.dart';

class EditProfilePage extends ConsumerStatefulWidget {
  final UserModel user;
  const EditProfilePage({super.key, required this.user});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _avatarController;
  late TextEditingController _bannerController;

  bool _isSavingAvatar = false;
  bool _isSavingBanner = false;
  bool _isSavingInfo = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.displayName);
    _bioController = TextEditingController(text: widget.user.bio);
    _avatarController = TextEditingController(text: widget.user.avatarUrl);
    _bannerController = TextEditingController(text: widget.user.bannerUrl);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _avatarController.dispose();
    _bannerController.dispose();
    super.dispose();
  }

  ImageProvider _getImageProvider(String url) {
    if (url.isEmpty || !url.startsWith('http')) {
      return const AssetImage('assets/placeholder.png');
    }
    return CachedNetworkImageProvider(url, maxHeight: 400);
  }

  // ... (Keep existing _validateImageLink logic unchanged)
  Future<String?> _validateImageLink(String url, {required int maxRes}) async {
    final validExtensions = ['.jpg', '.jpeg', '.png', '.webp'];
    bool hasValidExt =
        validExtensions.any((ext) => url.toLowerCase().contains(ext));
    if (!hasValidExt) return "Link must contain .jpg, .png, or .webp";

    final Completer<String?> completer = Completer();
    final ImageStream stream =
        NetworkImage(url).resolve(ImageConfiguration.empty);
    late ImageStreamListener listener;

    listener = ImageStreamListener((ImageInfo info, bool _) {
      final int width = info.image.width;
      final int height = info.image.height;
      info.image.dispose();
      if (width > maxRes || height > maxRes)
        completer.complete("Image too large! Max is ${maxRes}px.");
      else if (width < 200 || height < 200)
        completer.complete("Image too small! Min is 200x200px.");
      else
        completer.complete(null);
      stream.removeListener(listener);
    }, onError: (dynamic exception, StackTrace? stackTrace) {
      completer.complete("Could not load image. Check the link.");
      stream.removeListener(listener);
    });
    stream.addListener(listener);
    return completer.future;
  }

  // ... (Keep existing _saveImage logic unchanged)
  Future<void> _saveImage(String type) async {
    final isAvatar = type == 'avatar';
    final controller = isAvatar ? _avatarController : _bannerController;
    final url = controller.text.trim();
    setState(() => isAvatar ? _isSavingAvatar = true : _isSavingBanner = true);

    final error = await _validateImageLink(url, maxRes: isAvatar ? 1000 : 4000);
    if (error != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), backgroundColor: Colors.red));
        setState(
            () => isAvatar ? _isSavingAvatar = false : _isSavingBanner = false);
      }
      return;
    }

    try {
      final profileRepo = ref.read(profileRepositoryProvider);
      await profileRepo.updateUserProfile(
        displayName: _nameController.text,
        bio: _bioController.text,
        avatarUrl: isAvatar ? url : widget.user.avatarUrl,
        bannerUrl: isAvatar ? widget.user.bannerUrl : url,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('$type updated!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted)
        setState(
            () => isAvatar ? _isSavingAvatar = false : _isSavingBanner = false);
    }
  }

  Future<void> _saveInfo() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSavingInfo = true);
    try {
      final profileRepo = ref.read(profileRepositoryProvider);
      await profileRepo.updateUserProfile(
        displayName: _nameController.text.trim(),
        bio: _bioController.text.trim(),
        avatarUrl: _avatarController.text.trim(),
        bannerUrl: _bannerController.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      // Handle error
    } finally {
      if (mounted) setState(() => _isSavingInfo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Reusable input decoration matching the manga draft style
    InputDecoration inputStyle(String label) {
      return InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: theme.hintColor),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      );
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text("Edit Profile",
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: theme.dividerColor.withOpacity(0.2)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("AVATAR",
                  style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: theme.colorScheme.surfaceContainerHighest,
                      image: DecorationImage(
                          image: _getImageProvider(_avatarController.text),
                          fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _avatarController,
                      decoration: inputStyle("Image URL"),
                      onChanged: (val) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed:
                        _isSavingAvatar ? null : () => _saveImage('avatar'),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.all(16),
                    ),
                    child: _isSavingAvatar
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save),
                  )
                ],
              ),
              const SizedBox(height: 32),
              Text("BANNER",
                  style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 90,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: theme.colorScheme.surfaceContainerHighest,
                      image: DecorationImage(
                          image: _getImageProvider(_bannerController.text),
                          fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _bannerController,
                      decoration: inputStyle("Image URL"),
                      onChanged: (val) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed:
                        _isSavingBanner ? null : () => _saveImage('banner'),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.all(16),
                    ),
                    child: _isSavingBanner
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save),
                  )
                ],
              ),
              const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Divider()),
              Text("PROFILE INFO",
                  style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: inputStyle("Display Name"),
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                validator: (val) => val!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bioController,
                maxLines: 4,
                maxLength: 150,
                decoration: inputStyle("Bio / Description"),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _isSavingInfo ? null : _saveInfo,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSavingInfo
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Save Changes",
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
