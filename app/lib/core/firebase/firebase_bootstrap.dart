import 'package:firebase_core/firebase_core.dart';
import 'package:logging/logging.dart';

bool _firebaseReady = false;

bool get isFirebaseReady => _firebaseReady;

Future<void> initializeFirebase() async {
  final logger = Logger('VaultSpend.Firebase');
  try {
    await Firebase.initializeApp();
    _firebaseReady = true;
    logger.info('firebase_initialized');
  } catch (error, stack) {
    _firebaseReady = false;
    logger.warning('firebase_init_failed', error, stack);
  }
}
