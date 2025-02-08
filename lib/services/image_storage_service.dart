import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:to_do_app/common_imports.dart';

class SecureImageStorage {
  static const String PROFILE_IMAGE_KEY = 'profile_image_';
  static late SharedPreferences _prefs;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Save profile image based on authentication status
  static Future<String> saveProfileImage(File image, String userId) async {
    try {
      // Create a user-specific directory
      final directory = await getApplicationDocumentsDirectory();
      final userDirectory = Directory('${directory.path}/$userId');
      if (!await userDirectory.exists()) {
        await userDirectory.create();
      }

      // Generate unique image name with user ID
      final imageName = 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final localPath = '${userDirectory.path}/$imageName';

      // Copy image to user-specific local storage
      await image.copy(localPath);

      // Store the path with user-specific key
      final userSpecificKey = '${PROFILE_IMAGE_KEY}$userId';
      await _prefs.setString(userSpecificKey, localPath);

      // Upload to Firebase if authenticated
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && currentUser.uid == userId) {
        try {
          final storageRef = _storage
              .ref()
              .child('users')
              .child(userId)
              .child('profile_images')
              .child(imageName);

          await storageRef.putFile(image);
          final downloadUrl = await storageRef.getDownloadURL();

          // Store Firebase URL with user-specific key
          await _prefs.setString('${userSpecificKey}_url', downloadUrl);
        } catch (e) {
          print('Firebase upload failed: $e');
        }
      }

      return localPath;
    } catch (e) {
      print('Error saving profile image: $e');
      throw Exception('Failed to save profile image: $e');
    }
  }

  // Get profile image with strict user isolation
  static Future<String?> getProfileImage(String userId) async {
    try {
      final userSpecificKey = '${PROFILE_IMAGE_KEY}$userId';
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser != null && currentUser.uid == userId) {
        // Try to get Firebase URL first for authenticated user
        final firebaseUrl = _prefs.getString('${userSpecificKey}_url');
        if (firebaseUrl != null) {
          return firebaseUrl;
        }
      }

      // Return user-specific local path as fallback
      final localPath = _prefs.getString(userSpecificKey);
      if (localPath != null) {
        final file = File(localPath);
        if (await file.exists()) {
          return localPath;
        } else {
          // Clean up invalid path
          await _prefs.remove(userSpecificKey);
          return null;
        }
      }
      return null;
    } catch (e) {
      print('Error getting profile image: $e');
      return null;
    }
  }

  // Clean up user data when logging out
  static Future<void> cleanupUserData(String userId) async {
    try {
      final userSpecificKey = '${PROFILE_IMAGE_KEY}$userId';

      // Remove local file
      final localPath = _prefs.getString(userSpecificKey);
      if (localPath != null) {
        final file = File(localPath);
        if (await file.exists()) {
          await file.delete();
        }
      }

      // Remove preferences
      await _prefs.remove(userSpecificKey);
      await _prefs.remove('${userSpecificKey}_url');

      // Clean up user directory
      final directory = await getApplicationDocumentsDirectory();
      final userDirectory = Directory('${directory.path}/$userId');
      if (await userDirectory.exists()) {
        await userDirectory.delete(recursive: true);
      }
    } catch (e) {
      print('Error cleaning up user data: $e');
    }
  }

  // Sync local data to Firebase after authentication
  static Future<void> syncToFirebase(String userId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || currentUser.uid != userId) return;

      final userSpecificKey = '${PROFILE_IMAGE_KEY}$userId';
      final localPath = _prefs.getString(userSpecificKey);

      if (localPath != null) {
        final file = File(localPath);
        if (await file.exists()) {
          final imageName = localPath.split('/').last;
          final storageRef = _storage
              .ref()
              .child('users')
              .child(userId)
              .child('profile_images')
              .child(imageName);

          await storageRef.putFile(file);
          final downloadUrl = await storageRef.getDownloadURL();
          await _prefs.setString('${userSpecificKey}_url', downloadUrl);
        }
      }
    } catch (e) {
      print('Error syncing to Firebase: $e');
    }
  }
}
