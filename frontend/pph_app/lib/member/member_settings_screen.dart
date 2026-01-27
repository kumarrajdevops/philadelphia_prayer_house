import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/profile_service.dart';
import '../auth/auth_service.dart';
import '../auth/login_screen.dart';
import '../utils/api_client.dart';

class MemberSettingsScreen extends StatefulWidget {
  const MemberSettingsScreen({super.key});

  @override
  State<MemberSettingsScreen> createState() => _MemberSettingsScreenState();
}

class _MemberSettingsScreenState extends State<MemberSettingsScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  Map<String, dynamic>? _profile;

  // Profile fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  // Password fields
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  // Set password fields (for OTP-only users)
  final TextEditingController _setPasswordController = TextEditingController();
  final TextEditingController _setConfirmPasswordController = TextEditingController();

  String? _profileImageUrl;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _setPasswordController.dispose();
    _setConfirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final profile = await ProfileService.getProfile(context: context);
      if (profile != null) {
        setState(() {
          _profile = profile;
          _nameController.text = profile["name"] ?? "";
          _usernameController.text = profile["username"] ?? "";
          _emailController.text = profile["email"] ?? "";
          _profileImageUrl = profile["profile_image_url"];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to load profile: $e")),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfile() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);
    try {
      await ProfileService.updateProfile(
        name: _nameController.text.trim(),
        username: _usernameController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile updated successfully")),
        );
        await _loadProfile();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to update profile: $e")),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _changePassword() async {
    if (_newPasswordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password must be at least 6 characters")),
      );
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords do not match")),
      );
      return;
    }

    try {
      await ProfileService.changePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Password changed successfully")),
        );
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        Navigator.pop(context); // Close dialog
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to change password: $e")),
        );
      }
    }
  }

  Future<void> _setPassword() async {
    if (_setPasswordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password must be at least 6 characters")),
      );
      return;
    }

    if (_setPasswordController.text != _setConfirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords do not match")),
      );
      return;
    }

    try {
      await ProfileService.setPassword(_setPasswordController.text);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Password set successfully. You can now login with username/email and password.")),
        );
        _setPasswordController.clear();
        _setConfirmPasswordController.clear();
        Navigator.pop(context); // Close dialog
        await _loadProfile(); // Reload to update has_password status
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to set password: $e")),
        );
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() => _isSaving = true);
      final imageUrl = await ProfileService.uploadProfilePicture(File(image.path));

      if (imageUrl != null && mounted) {
        setState(() {
          _profileImageUrl = imageUrl;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile picture uploaded successfully")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to upload image: $e")),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Account"),
        content: const Text(
          "Are you sure you want to delete your account? This action cannot be undone. "
          "Your account will be anonymized and you will be logged out.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ProfileService.deleteAccount();
      if (mounted) {
        await AuthService.logout();
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Account deleted successfully")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to delete account: $e")),
        );
      }
    }
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Change Password"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _currentPasswordController,
                decoration: const InputDecoration(
                  labelText: "Current Password",
                  hintText: "Enter current password",
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _newPasswordController,
                decoration: const InputDecoration(
                  labelText: "New Password",
                  hintText: "Enter new password (min 6 characters)",
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmPasswordController,
                decoration: const InputDecoration(
                  labelText: "Confirm New Password",
                  hintText: "Confirm new password",
                ),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _currentPasswordController.clear();
              _newPasswordController.clear();
              _confirmPasswordController.clear();
              Navigator.pop(context);
            },
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: _changePassword,
            child: const Text("Change Password"),
          ),
        ],
      ),
    );
  }

  void _showSetPasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Set Password"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "You're using OTP login only. Set a password for easier login.",
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _setPasswordController,
                decoration: const InputDecoration(
                  labelText: "New Password",
                  hintText: "Enter password (min 6 characters)",
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _setConfirmPasswordController,
                decoration: const InputDecoration(
                  labelText: "Confirm Password",
                  hintText: "Confirm password",
                ),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _setPasswordController.clear();
              _setConfirmPasswordController.clear();
              Navigator.pop(context);
            },
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: _setPassword,
            child: const Text("Set Password"),
          ),
        ],
      ),
    );
  }

  String _getProfileImageUrl() {
    if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      // profileImageUrl is already in format "profiles/filename.jpg"
      return "${ApiClient.baseUrl}/uploads/${_profileImageUrl!}";
    }
    return "";
  }

  String _getInitials() {
    final name = _nameController.text.trim();
    if (name.isNotEmpty) {
      return name.substring(0, 1).toUpperCase();
    }
    return "U";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProfile,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Section
                    _buildSectionHeader("Profile"),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            // Profile Picture
                            GestureDetector(
                              onTap: _pickAndUploadImage,
                              child: Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 50,
                                    backgroundColor: Colors.blue[100],
                                    backgroundImage: _getProfileImageUrl().isNotEmpty
                                        ? NetworkImage(_getProfileImageUrl())
                                        : null,
                                    child: _getProfileImageUrl().isEmpty
                                        ? Text(
                                            _getInitials(),
                                            style: TextStyle(
                                              fontSize: 32,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue[700],
                                            ),
                                          )
                                        : null,
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: CircleAvatar(
                                      radius: 16,
                                      backgroundColor: Colors.blue,
                                      child: const Icon(
                                        Icons.camera_alt,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Tap to change photo",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Name
                            TextField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: "Name",
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Username
                            TextField(
                              controller: _usernameController,
                              decoration: const InputDecoration(
                                labelText: "Username",
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Email
                            TextField(
                              controller: _emailController,
                              decoration: const InputDecoration(
                                labelText: "Email (Optional)",
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 24),
                            // Save Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isSaving ? null : _updateProfile,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                                child: _isSaving
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : const Text("Save Changes"),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Security Section
                    _buildSectionHeader("Security"),
                    Card(
                      child: Column(
                        children: [
                          if (_profile?["has_password"] == true)
                            ListTile(
                              leading: const Icon(Icons.lock),
                              title: const Text("Change Password"),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _showChangePasswordDialog,
                            )
                          else
                            ListTile(
                              leading: const Icon(Icons.lock_open),
                              title: const Text("Set Password"),
                              subtitle: const Text(
                                "You're using OTP login only. Set a password for easier login.",
                                style: TextStyle(fontSize: 12),
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _showSetPasswordDialog,
                            ),
                          const Divider(),
                          ListTile(
                            leading: const Icon(Icons.info_outline),
                            title: const Text("Login Methods"),
                            subtitle: Text(
                              _profile?["has_password"] == true
                                  ? "Password, OTP"
                                  : "OTP only",
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          if (_profile?["last_login"] != null)
                            ListTile(
                              leading: const Icon(Icons.access_time),
                              title: const Text("Last Login"),
                              subtitle: Text(
                                DateFormat("MMM dd, yyyy 'at' hh:mm a").format(
                                  DateTime.parse(_profile!["last_login"]),
                                ),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          if (_profile?["created_at"] != null)
                            ListTile(
                              leading: const Icon(Icons.calendar_today),
                              title: const Text("Account Created"),
                              subtitle: Text(
                                DateFormat("MMM dd, yyyy").format(
                                  DateTime.parse(_profile!["created_at"]),
                                ),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Privacy Section
                    _buildSectionHeader("Privacy"),
                    Card(
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.visibility),
                            title: const Text("Public Prayer Requests"),
                            subtitle: const Text(
                              "Your name may be visible in public prayer time",
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                          const Divider(),
                          ListTile(
                            leading: const Icon(Icons.lock),
                            title: const Text("Private Prayer Requests"),
                            subtitle: const Text(
                              "Your identity is kept confidential. Only the pastor sees your name.",
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Account Section
                    _buildSectionHeader("Account"),
                    Card(
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.delete_outline, color: Colors.red),
                            title: const Text(
                              "Delete Account",
                              style: TextStyle(color: Colors.red),
                            ),
                            subtitle: const Text(
                              "Permanently delete your account. This action cannot be undone.",
                              style: TextStyle(fontSize: 12),
                            ),
                            onTap: _deleteAccount,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.grey[800],
        ),
      ),
    );
  }
}
