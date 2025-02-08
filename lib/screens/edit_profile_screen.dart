import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:to_do_app/screens/password_reset_screen.dart';
import 'package:to_do_app/themes/colors.dart';
class EditProfilePage extends StatefulWidget {
  final String currentName;
  final String currentEmail;
  final File? profileImage;
  final String? imageUrl;

  const EditProfilePage({
    Key? key,
    required this.currentName,
    required this.currentEmail,
    this.profileImage,
    this.imageUrl,
  }) : super(key: key);

  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _currentPasswordController;
  late TextEditingController _newPasswordController;
  late TextEditingController _confirmPasswordController;

  File? _profileImage;
  String? _imageUrl;
  bool _isPasswordChangeMode = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
    _emailController = TextEditingController(text: widget.currentEmail);
    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    _profileImage = widget.profileImage;
    _imageUrl = widget.imageUrl;
  }

  void _saveChanges() {
    // Implement save logic for profile updates
    // This should include validation, Firebase updates, etc.
  }

  void _changePassword() {
    // Implement password change logic
    if (_newPasswordController.text == _confirmPasswordController.text) {
      // Validate and change password
    } else {
      // Show error that passwords don't match
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('Edit Profile'),
          backgroundColor: Colors.transparent,
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              // Profile Image Selection
              GestureDetector(
                onTap: () {
                  // Implement image selection logic similar to profile page
                },
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundImage: _profileImage != null
                          ? FileImage(_profileImage!)
                          : (_imageUrl != null
                              ? NetworkImage(_imageUrl!)
                              : null),
                      child: _profileImage == null && _imageUrl == null
                          ? Icon(Icons.person, size: 60)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Icon(Icons.camera_alt, color: Colors.blue),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),

              // Name and Email Fields
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Name',
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              SizedBox(height: 10),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                ),
              ),

              // Password Change Section
              SwitchListTile(
                title: Text('Change Password'),
                value: _isPasswordChangeMode,
                onChanged: (bool value) {
                  setState(() {
                    _isPasswordChangeMode = value;
                  });
                },
              ),

              if (_isPasswordChangeMode) ...[
                TextField(
                  controller: _currentPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    prefixIcon: Icon(Icons.lock),
                  ),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: _newPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ResetPasswordPage(),
                      ),
                    );
                  },
                  child: Text('Forgot Password?'),
                ),
              ],

              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveChanges,
                child: Text('Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
