import 'package:to_do_app/common_imports.dart';
import 'package:to_do_app/screens/edit_profile_screen.dart';

class ProfilePage extends StatefulWidget {
  List<ScheduleTask> scheduledTasks;
  List<QuickTask> quickTasks;

  ProfilePage({
    Key? key,
    required this.scheduledTasks,
    required this.quickTasks,
  }) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  bool _isEditingName = false;
  bool _isEditingEmail = false;
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    final currentUser = FirebaseAuth.instance.currentUser;
    _nameController.text = currentUser?.displayName ?? 'User Name';
    _emailController.text = currentUser?.email ?? 'user@example.com';
    _loadUserData();
    _loadSavedImage();
  }
Widget _buildProfileImage() {
  return Stack(
    alignment: Alignment.bottomRight,
    children: [
      Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ClipOval(
          child: _imageUrl != null
              ? Image.network(_imageUrl!, fit: BoxFit.cover)
              : _profileImage != null
                  ? Image.file(_profileImage!, fit: BoxFit.cover)
                  : Container(
                      color: Colors.white,
                      child: Icon(
                        Icons.person,
                        size: 60,
                        color: Colors.blue.shade200,
                      ),
                    ),
        ),
      ),
      Positioned(
        bottom: 0,
        right: 0,
        child: GestureDetector(
          onTap: () {
            Navigator.push(
              context, 
              MaterialPageRoute(
                builder: (context) => EditProfilePage(
                  currentName: _nameController.text,
                  currentEmail: _emailController.text,
                  profileImage: _profileImage,
                  imageUrl: _imageUrl,
                ),
              ),
            );
          },
          child: Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 5,
                ),
              ],
            ),
            child: Icon(
              Icons.edit,
              size: 20,
              color: Colors.blue,
            ),
          ),
        ),
      ),
    ],
  );
}
  Future<void> _saveImage(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null) {
      // Save image with user-specific key
      await prefs.setString('profile_image_path_${currentUser.uid}', path);
    }
  }

  Future<void> _loadSavedImage() async {
    final prefs = await SharedPreferences.getInstance();
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null) {
      final savedImagePath =
          prefs.getString('profile_image_path_${currentUser.uid}');
      if (savedImagePath != null) {
        setState(() {
          _profileImage = File(savedImagePath);
          _imageUrl = null;
        });
      }
    }
  }

  Future<void> _loadUserData() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      _nameController.text = prefs.getString('user_name') ??
          currentUser?.displayName ??
          'User Name';
      _emailController.text = prefs.getString('user_email') ??
          currentUser?.email ??
          'user@example.com';
    });
  }

  @override
  Widget build(BuildContext context) {
    return HomePageGradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: Colors.transparent,
              expandedHeight: 280.0,
              floating: false,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: 40),
                    _buildProfileImage(), // Use the existing method
                    SizedBox(height: 16),
                    Text(
                      _nameController.text,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textLight,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      _emailController.text,
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildTaskOverview(
                        widget.scheduledTasks, widget.quickTasks),
                    SizedBox(height: 16),
                    TaskProgressBars(
                      scheduledTasks: widget.scheduledTasks,
                      quickTasks: widget.quickTasks,
                    ),
                    SizedBox(height: 16),
                    _buildNameEmailSection(),
                    SizedBox(height: 16),
                    _buildSettingsButton(),
                    SizedBox(height: 16),
                    _buildLogoutDeleteButtons(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskOverview(
      List<ScheduleTask> scheduledTasks, List<QuickTask> quickTasks) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2), // Slightly transparent white
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            "Task Overview",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textLight,
            ),
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatCard(
                "Scheduled Tasks",
                scheduledTasks.length.toString(),
                AppColors.primaryTeal,
              ),
              _buildStatCard(
                "Quick Tasks",
                quickTasks.length.toString(),
                AppColors.primaryPurple,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String count, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            count,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateUserProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.updateDisplayName(_nameController.text);
        if (_isEditingEmail) {
          await user.updateEmail(_emailController.text);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profile updated successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile: $e')),
      );
    }
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

  Widget _buildTaskProgressBars(
      List<ScheduleTask> scheduledTasks, List<QuickTask> quickTasks) {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            'YOUR PROGRESS',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 20),
          TaskProgressBars(
            scheduledTasks: scheduledTasks,
            quickTasks: quickTasks,
          ),
        ],
      ),
    );
  }

  Widget _buildNameEmailSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          // Name Section
          _buildEditableField(
            controller: _nameController,
            isEditing: _isEditingName,
            onEdit: () => setState(() => _isEditingName = true),
            onSave: () async {
              setState(() => _isEditingName = false);
              await _updateUserProfile();
            },
            icon: Icons.person,
            label: 'Name',
          ),
          SizedBox(height: 15),
          // Email Section
          _buildEditableField(
            controller: _emailController,
            isEditing: _isEditingEmail,
            onEdit: () => setState(() => _isEditingEmail = true),
            onSave: () async {
              setState(() => _isEditingEmail = false);
              await _updateUserProfile();
            },
            icon: Icons.email,
            label: 'Email',
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsButton() {
    return Container(
      margin: EdgeInsets.only(top: 20),
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.pushNamed(context, '/settings');
        },
        icon: Icon(Icons.settings, color: Colors.white),
        label: Text('Settings'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryTeal,
          padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),
    );
  }

  Widget _buildEditableField({
    required TextEditingController controller,
    required bool isEditing,
    required VoidCallback onEdit,
    required VoidCallback onSave,
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: isEditing
                ? TextField(
                    controller: controller,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: label,
                      hintStyle: TextStyle(color: Colors.white54),
                    ),
                  )
                : Text(
                    controller.text,
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
          ),
          IconButton(
            icon: Icon(
              isEditing ? Icons.check : Icons.edit,
              color: Colors.white70,
            ),
            onPressed: isEditing ? onSave : onEdit,
          ),
        ],
      ),
    );
  }

  // Helper methods for task filtering remain the same...
  Widget _buildLogoutDeleteButtons() {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        children: [
          if (currentUser != null) ...[
            // Logout Button - Only shown if logged in
            ElevatedButton(
              onPressed: _showLogoutConfirmation,
              child: Text("Logout"),
              style: ElevatedButton.styleFrom(
                iconColor: Colors.red,
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              ),
            ),
            SizedBox(height: 10),

            // Delete Account Button - Only shown if logged in
            ElevatedButton(
              onPressed: _showDeleteConfirmation,
              child: Text("Delete Account"),
              style: ElevatedButton.styleFrom(
                iconColor: Colors.black,
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              ),
            ),
          ] else ...[
            // Option to delete current data - if not logged in
            ElevatedButton(
              onPressed: _showDeleteCurrentDataConfirmation,
              child: Text("Delete Current Data"),
              style: ElevatedButton.styleFrom(
                iconColor: Colors.black,
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Show confirmation dialog for deleting local data
  void _showDeleteCurrentDataConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Are you sure?"),
          content: Text(
              "This action will delete all tasks on this device, but not from Firebase."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteLocalData(); // Delete tasks from device
              },
              child: Text("Yes"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text("No"),
            ),
          ],
        );
      },
    );
  }

  // Show confirmation dialog for logout
  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Are you sure?"),
          content: Text("Do you really want to logout?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _logout(); // Call your logout function here
              },
              child: Text("Yes"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text("No"),
            ),
          ],
        );
      },
    );
  }

  // Show confirmation dialog for deleting account
  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Are you sure?"),
          content: Text(
              "This action is permanent. Do you want to delete your account? This will delete your account data from Firebase too."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteAccount(); // Call your delete account function here
              },
              child: Text("Yes"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text("No"),
            ),
          ],
        );
      },
    );
  } // Delete local tasks when logged out

  void _deleteLocalData() async {
    try {
      // Show the loading indicator
      _showLoadingIndicator();

      // Delete all data from Firebase
      await FirebaseTaskService.deleteAllData();

      // Update the local state with an empty list

      // Close loading indicator after 2 seconds
      await Future.delayed(Duration(seconds: 2));
      setState(() {
        widget.scheduledTasks = [];
        widget.quickTasks = []; // Set todos to empty list immediately
      });

      Navigator.of(context, rootNavigator: true)
          .pop(); // Dismiss loading indicator

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("All tasks deleted successfully")),
      );
    } catch (e) {
      // Close loading indicator if there's an error
      Navigator.of(context, rootNavigator: true).pop();

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error deleting tasks: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

// Logout function
  void _logout() async {
    _showLoadingIndicator();
    // Perform logout action (Firebase sign out or similar)
    await FirebaseAuth.instance.signOut();

    // Clear tasks locally
    FirebaseTaskService.logoutAndClearLocalData(context);

    // Navigate to login page after logout
    Navigator.pushNamed(context, '/login').then((_) {
      // When coming back to this page, you can trigger a refresh if needed
      setState(() {});
    });
  }

// Delete account function
  void _deleteAccount() async {
    try {
      _showLoadingIndicator();

      // Re-authenticate the user

      // Perform account deletion
      await FirebaseTaskService.deleteUserDataAndAccount();

      // Close the loading indicator
      if (mounted) Navigator.of(context).pop();

      // Navigate to the login page and clear tasks
      Navigator.pushReplacementNamed(context, '/login').then((_) {
        setState(() {
          widget.scheduledTasks = [];
          widget.quickTasks = [];
        });
      });
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error deleting account: $e")),
      );
    }
  }

// Show loading indicator
  void _showLoadingIndicator() {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (BuildContext context) {
        return Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    // Automatically dismiss the dialog after 2 seconds
    Future.delayed(Duration(seconds: 2), () {
      Navigator.of(context).pop(); // Dismiss the dialog
    });
  }

  // Helper methods for showing dialogs and error messages
  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Permission Required'),
          content: Text('Please enable required permissions in settings.'),
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

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}

class TaskProgressBars extends StatelessWidget {
  final List<ScheduleTask> scheduledTasks;
  final List<QuickTask> quickTasks;

  const TaskProgressBars({
    Key? key,
    required this.scheduledTasks,
    required this.quickTasks,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Progress Overview',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 20),

        // Scheduled Tasks Progress (with overdue tracking)
        _buildScheduledTasksProgress(
          'Scheduled Tasks',
          scheduledTasks.where((task) => task.isCompleted).length,
          scheduledTasks
              .where((task) =>
                  !task.isCompleted && !task.dueDate.isBefore(DateTime.now()))
              .length,
          scheduledTasks
              .where((task) =>
                  !task.isCompleted && task.dueDate.isBefore(DateTime.now()))
              .length,
          scheduledTasks.length,
        ),

        SizedBox(height: 24),

        // Quick Tasks Progress (simplified without overdue)
        _buildQuickTasksProgress(
          'Quick Tasks',
          quickTasks.where((task) => task.isCompleted ?? false).length,
          quickTasks.where((task) => !(task.isCompleted ?? false)).length,
          quickTasks.length,
        ),

        SizedBox(height: 20),

        // Legend
        _buildLegend(),
      ],
    );
  }

  Widget _buildScheduledTasksProgress(
    String title,
    int completed,
    int pending,
    int overdue,
    int total,
  ) {
    // Calculate percentages
    double completedPercent = total > 0 ? (completed / total) * 100 : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              '${completedPercent.toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Container(
          height: 24,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                // Completed section
                Flexible(
                  flex: completed,
                  child: Container(color: Colors.green),
                ),
                // Pending section
                Flexible(
                  flex: pending,
                  child: Container(color: Colors.orange),
                ),
                // Overdue section
                Flexible(
                  flex: overdue,
                  child: Container(color: Colors.red),
                ),
                // Empty space if total is 0
                if (total == 0)
                  Expanded(
                    child: Container(color: Colors.grey.withOpacity(0.2)),
                  ),
              ],
            ),
          ),
        ),
        SizedBox(height: 8),
      ],
    );
  }

  Widget _buildQuickTasksProgress(
    String title,
    int completed,
    int pending,
    int total,
  ) {
    // Calculate percentage
    double completedPercent = total > 0 ? (completed / total) * 100 : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              '${completedPercent.toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Container(
          height: 24,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                // Completed section
                Flexible(
                  flex: completed,
                  child: Container(color: Colors.green),
                ),
                // Pending section
                Flexible(
                  flex: pending,
                  child: Container(color: Colors.orange),
                ),
                // Empty space if total is 0
                if (total == 0)
                  Expanded(
                    child: Container(color: Colors.grey.withOpacity(0.2)),
                  ),
              ],
            ),
          ),
        ),
        SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatusText('Completed', completed),
            _buildStatusText('Pending', pending),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusText(String label, int count) {
    return Text(
      '$label: $count',
      style: TextStyle(
        fontSize: 12,
        color: Colors.white70,
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        _buildLegendItem('Completed', Colors.green),
        SizedBox(width: 16),
        _buildLegendItem('Pending', Colors.orange),
        SizedBox(width: 16),
        _buildLegendItem('Overdue', Colors.red),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
