import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';

import 'package:flutter/foundation.dart';
import 'supabase_config.dart';
import 'firebase_options.dart';
import 'models/models.dart';
import 'widgets/empty_state.dart';
import 'db_repository.dart';
import 'supabase_repository.dart';

part 'app/ledger_service.dart';
part 'app/app_shell.dart';
part 'app/auth.dart';
part 'app/dashboard.dart';
part 'app/shared_widgets.dart';

Future<void> bootstrapApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase and messaging only on mobile platforms (Android/iOS)
  if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
    } catch (e) {
      print('Firebase initialization failed: $e');
    }
  } else {
    print('Firebase skipped on this platform ($defaultTargetPlatform)');
  }

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  runApp(const GeoTrustApp());
}
