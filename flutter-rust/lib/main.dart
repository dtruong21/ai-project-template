import 'package:app/app.dart';
import 'package:app/core/bootstrap.dart';
import 'package:app/src/rust/frb_generated.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init(); // loads the compiled rust/core library
  await dotenv.load(); // .env is bundled — config only, never secrets
  final firebaseReady = await initFirebase();

  runApp(
    ProviderScope(
      overrides: [firebaseReadyProvider.overrideWithValue(firebaseReady)],
      child: const App(),
    ),
  );
}
