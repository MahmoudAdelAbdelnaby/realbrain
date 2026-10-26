import 'package:firebase_core/firebase_core.dart';

/// Android: Firebase options come from google-services.json and the channel is Kotlin.
/// The web build swaps in native_web.dart.
Future<FirebaseOptions?> platformSetup() async => null;
