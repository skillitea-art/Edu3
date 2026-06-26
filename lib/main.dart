import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'providers/auth_provider.dart';
import 'providers/tuition_provider.dart';
import 'providers/task_provider.dart';
import 'firebase_options.dart';
import 'screens/auth/splash_screen.dart';

void main() async {
  // Ensure bindings are initialized first
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase synchronously before running the app
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const VedoApp());
}

class VedoApp extends StatelessWidget {
  const VedoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => TuitionProvider()),
        ChangeNotifierProvider(create: (_) => TaskProvider()),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          return MaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: authProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}


