import 'package:firebase_storage/firebase_storage.dart';
import 'package:to_do_app/common_imports.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EditProfileScreen extends StatefulWidget {
  final String currentName;
  final String currentEmail;
  final File? currentImage;

  const EditProfileScreen({
    Key? key,
    required this.currentName,
    required this.currentEmail,
    this.currentImage,
  }) : super(key: key);

  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  File? _selectedImage;
  bool _isLoading = false;
  bool _isGuestUser = FirebaseAuth.instance.currentUser == null;
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();
  bool _isEditingName = false;
  bool _isEditingEmail = false;
  String? _imageUrl;
  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();

    if (_isGuestUser) {
      final guestId = prefs.getString('guest_user_id') ?? 'guest';
      _nameController.text =
          prefs.getString('guest_name_$guestId') ?? widget.currentName;
      _emailController.text =
          prefs.getString('guest_email_$guestId') ?? widget.currentEmail;

      final savedImagePath = prefs.getString('guest_profile_image_$guestId');
      if (savedImagePath != null) {
        setState(() => _selectedImage = File(savedImagePath));
      }
    } else {
      _nameController.text = widget.currentName;
      _emailController.text = widget.currentEmail;

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final savedImagePath =
            prefs.getString('profile_image_path_${user.uid}');
        if (savedImagePath != null) {
          setState(() => _selectedImage = File(savedImagePath));
        }
      }
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      if (_isGuestUser) {
        await _updateGuestProfile();
      } else {
        await _updateAuthenticatedProfile();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile updated successfully')),
      );

      Navigator.pop(context, true); // Return true when profile is updated
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateGuestProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final guestId = prefs.getString('guest_user_id') ?? 'guest';

    await prefs.setString('guest_name_$guestId', _nameController.text);
    await prefs.setString('guest_email_$guestId', _emailController.text);

    if (_selectedImage != null && _selectedImage != widget.currentImage) {
      await prefs.setString(
          'guest_profile_image_$guestId', _selectedImage!.path);
    }
  }

  Future<void> _updateAuthenticatedProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('No user logged in');

    if (_nameController.text != widget.currentName) {
      await user.updateDisplayName(_nameController.text);
    }
    if (_emailController.text != widget.currentEmail) {
      await user.updateEmail(_emailController.text);
    }

    if (_newPasswordController.text.isNotEmpty) {
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentPasswordController.text,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(_newPasswordController.text);
    }

    if (_selectedImage != null && _selectedImage != widget.currentImage) {
      // Implement your image upload logic here
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'profile_image_path_${user.uid}', _selectedImage!.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Profile'),
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: _isLoading ? null : _updateProfile,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildProfileImagePicker(),
                    SizedBox(height: 24),
                    _buildTextField(
                      controller: _nameController,
                      label: 'Name',
                      validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                    ),
                    SizedBox(height: 16),
                    _buildTextField(
                      controller: _emailController,
                      label: 'Email',
                      validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                    ),
                    if (!_isGuestUser) ...[
                      SizedBox(height: 24),
                      _buildPasswordSection(),
                      SizedBox(height: 16),
                      TextButton(
                        onPressed: () =>
                            Navigator.pushNamed(context, '/forgot-password'),
                        child: Text('Forgot Password?'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProfileImagePicker() {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        CircleAvatar(
          radius: 60,
          backgroundImage:
              _selectedImage != null ? FileImage(_selectedImage!) : null,
          child: _selectedImage == null ? Icon(Icons.person, size: 60) : null,
        ),
        IconButton(
          icon: Icon(Icons.camera_alt),
          onPressed: () {
            // Reuse your existing image picker logic
            _showImagePickerOptions();
          },
        ),
      ],
    );
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_camera, color: Colors.blue),
              title: Text('Take a photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: Colors.blue),
              title: Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: Icon(Icons.link, color: Colors.blue),
              title: Text('Upload from URL'),
              onTap: () {
                Navigator.pop(context);
                _uploadImageFromUrl();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      // Request appropriate permission based on source
      PermissionStatus status;
      if (source == ImageSource.camera) {
        status = await Permission.camera.request();
      } else {
        // For gallery - check Android version for appropriate permission
        if (Platform.isAndroid) {
          if (await Permission.photos.request().isGranted) {
            status = PermissionStatus.granted;
          } else {
            // Try legacy storage permission as fallback
            status = await Permission.storage.request();
          }
        } else {
          // For iOS or other platforms
          status = await Permission.photos.request();
        }
      }

      if (status.isGranted) {
        // Permission granted, proceed with image picking
        final pickedFile = await _picker.pickImage(
          source: source,
          maxWidth: 800,
          maxHeight: 800,
          imageQuality: 85,
        );

        if (pickedFile != null) {
          setState(() {
            _profileImage = File(pickedFile.path);
            _imageUrl = null;
          });
          await _saveImage(pickedFile.path); // Save the image path
        }
      } else if (status.isPermanentlyDenied) {
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text('Permission Required'),
                content: Text(source == ImageSource.camera
                    ? 'Camera permission is required to take photos. Please enable it in settings.'
                    : 'Gallery permission is required to pick images. Please enable it in settings.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => openAppSettings(),
                    child: Text('Open Settings'),
                  ),
                ],
              );
            },
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(source == ImageSource.camera
                  ? 'Camera permission denied'
                  : 'Gallery permission denied'),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: () => openAppSettings(),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _saveImage(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null) {
      // Save image with user-specific key
      await prefs.setString('profile_image_path_${currentUser.uid}', path);
    }
  }

  Future<void> _uploadImageFromUrl() async {
    final TextEditingController urlController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Enter Image URL'),
        content: TextField(
          controller: urlController,
          decoration: InputDecoration(
            hintText: 'https://example.com/image.jpg',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _imageUrl = urlController.text;
                _profileImage = null;
              });
              Navigator.pop(context);
            },
            child: Text('Upload'),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
    bool isPassword = false,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(),
      ),
      obscureText: isPassword,
      validator: validator,
    );
  }

  Widget _buildPasswordSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Change Password',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        SizedBox(height: 16),
        _buildTextField(
          controller: _currentPasswordController,
          label: 'Current Password',
          isPassword: true,
        ),
        SizedBox(height: 8),
        _buildTextField(
          controller: _newPasswordController,
          label: 'New Password',
          isPassword: true,
        ),
        SizedBox(height: 8),
        _buildTextField(
          controller: _confirmPasswordController,
          label: 'Confirm New Password',
          isPassword: true,
          validator: (v) => v != _newPasswordController.text
              ? 'Passwords do not match'
              : null,
        ),
      ],
    );
  }
}
