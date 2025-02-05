// Core Dart imports
export 'dart:async';
export 'dart:convert';
export 'dart:io';

// Flutter and Material Design
export 'package:flutter/material.dart'
    hide Notification; // Hide Flutter's Notification
export 'package:google_fonts/google_fonts.dart';

// Firebase
export 'package:firebase_auth/firebase_auth.dart';
export 'package:firebase_core/firebase_core.dart';
export 'package:cloud_firestore/cloud_firestore.dart';

// Utilities
export 'package:connectivity_plus/connectivity_plus.dart';
export 'package:image_picker/image_picker.dart';
export 'package:intl/intl.dart' hide TextDirection;
export 'package:permission_handler/permission_handler.dart';
export 'package:rxdart/rxdart.dart'; // Keep RxDart's Notification
export 'package:shared_preferences/shared_preferences.dart';
export 'package:uuid/uuid.dart';

// App Screens
export 'package:to_do_app/screens/home.dart';
export 'package:to_do_app/screens/login_page.dart';
export 'package:to_do_app/screens/profile_page.dart';
export 'package:to_do_app/screens/welcome_page.dart';
export 'package:to_do_app/screens/sign-up_screen.dart';
export 'screens/password_reset_screen.dart';

// App Services
export 'package:to_do_app/services/auth_service.dart';
export 'package:to_do_app/services/data_sync_manager.dart';

// App Utils
export 'package:to_do_app/utilities/quick_task_items.dart';
export 'package:to_do_app/utilities/scheduled_task.dart';
export 'package:to_do_app/utilities/todo_category.dart';
//Themes
export 'package:to_do_app/themes/colors.dart';
