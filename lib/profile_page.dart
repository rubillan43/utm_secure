import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'login_page.dart';

const _maroon = Color(0xFF800000);

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _user = FirebaseAuth.instance.currentUser!;
  bool _isUploadingPhoto = false;

  // ── Pick & upload profile photo ───────────────────────────────────────────
  Future<void> _changePhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      imageQuality: 80,
    );
    if (picked == null || !mounted) return;

    setState(() => _isUploadingPhoto = true);
    try {
      final ref = FirebaseStorage.instance
          .ref('profile_photos/${_user.uid}.jpg');
      await ref.putFile(File(picked.path));
      final url = await ref.getDownloadURL();

      await _user.updatePhotoURL(url);
      await FirebaseFirestore.instance
          .collection('Users')
          .doc(_user.uid)
          .update({'photoUrl': url});

      // Reload so currentUser.photoURL reflects the change
      await _user.reload();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  // ── Sign out ──────────────────────────────────────────────────────────────
  Future<void> _signOut() async {
    final confirmed = await _showConfirmDialog(
      title: 'Sign Out',
      message: 'Are you sure you want to sign out?',
      confirmLabel: 'Sign Out',
      confirmColor: _maroon,
    );
    if (confirmed != true || !mounted) return;

    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    }
  }

  // ── Delete account ────────────────────────────────────────────────────────
  Future<void> _deleteAccount() async {
    final confirmed = await _showConfirmDialog(
      title: 'Delete Account',
      message:
          'This will permanently delete your account and all personal data. '
          'This action cannot be undone.',
      confirmLabel: 'Delete',
      confirmColor: Colors.red,
    );
    if (confirmed != true || !mounted) return;

    try {
      // Delete Firestore data first
      await FirebaseFirestore.instance
          .collection('Users')
          .doc(_user.uid)
          .delete();

      // Delete Auth account
      await _user.delete();

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      // delete() requires recent login; prompt re-authentication if needed
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.code == 'requires-recent-login'
                  ? 'Please sign out and sign in again before deleting your account.'
                  : 'Error: ${e.message}',
            ),
          ),
        );
      }
    }
  }

  // ── Reusable confirm dialog ───────────────────────────────────────────────
  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              confirmLabel,
              style: TextStyle(
                  color: confirmColor, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'My Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _maroon,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        elevation: 0,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('Users')
            .doc(_user.uid)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: _maroon));
          }

          final data =
              snapshot.data?.data() as Map<String, dynamic>? ?? {};
          final name = data['name'] as String? ?? '—';
          final matric = data['matrixNumber'] as String? ?? '—';
          final email = _user.email ?? '—';
          final photoUrl =
              FirebaseAuth.instance.currentUser?.photoURL ?? data['photoUrl'];

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
            child: Column(
              children: [
                // ── Profile photo ─────────────────────────────────────────
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 56,
                        backgroundColor: _maroon.withValues(alpha: 0.12),
                        backgroundImage: photoUrl != null
                            ? NetworkImage(photoUrl)
                            : null,
                        child: photoUrl == null
                            ? const Icon(Icons.person,
                                size: 56, color: _maroon)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _isUploadingPhoto ? null : _changePhoto,
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: _maroon,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white, width: 2),
                            ),
                            child: _isUploadingPhoto
                                ? const Padding(
                                    padding: EdgeInsets.all(6),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.camera_alt,
                                    size: 18, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Name ─────────────────────────────────────────────────
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: TextStyle(
                      fontSize: 14, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 32),

                // ── Info card ─────────────────────────────────────────────
                _InfoCard(children: [
                  _InfoTile(
                    icon: Icons.badge_outlined,
                    label: 'Full Name',
                    value: name,
                  ),
                  const Divider(height: 1, indent: 56),
                  _InfoTile(
                    icon: Icons.numbers_outlined,
                    label: 'Matric Number',
                    value: matric,
                  ),
                  const Divider(height: 1, indent: 56),
                  _InfoTile(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    value: email,
                  ),
                  const Divider(height: 1, indent: 56),
                  _InfoTile(
                    icon: Icons.shield_outlined,
                    label: 'Role',
                    value: (data['role'] as String? ?? 'student')
                        .toUpperCase(),
                  ),
                ]),
                const SizedBox(height: 32),

                // ── Sign Out ──────────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.logout, color: _maroon),
                    label: const Text(
                      'Sign Out',
                      style: TextStyle(
                          color: _maroon,
                          fontSize: 15,
                          fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _maroon),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _signOut,
                  ),
                ),
                const SizedBox(height: 12),

                // ── Delete Account ────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.delete_forever_outlined,
                        color: Colors.red),
                    label: const Text(
                      'Delete Account',
                      style: TextStyle(
                          color: Colors.red,
                          fontSize: 15,
                          fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _deleteAccount,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────
// Rounded card wrapper
// ─────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

// ─────────────────────────────────────────
// Single info row inside the card
// ─────────────────────────────────────────
class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoTile(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: _maroon, size: 22),
      title: Text(
        label,
        style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(
            fontSize: 15,
            color: Colors.black87,
            fontWeight: FontWeight.w600),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    );
  }
}
