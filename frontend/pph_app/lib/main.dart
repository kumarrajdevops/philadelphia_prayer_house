import 'package:flutter/material.dart';
import 'auth/login_screen.dart';
import 'auth/auth_service.dart';
import 'utils/navigation_helper.dart';
import 'utils/error_handler.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize notification service
  await NotificationService().initialize();
  
  runApp(const PPHApp());
}

class PPHApp extends StatelessWidget {
  const PPHApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Philadelphia Prayer House',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      navigatorKey: ErrorHandler.navigatorKey,
      home: const AuthCheckScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthCheckScreen extends StatefulWidget {
  const AuthCheckScreen({super.key});

  @override
  State<AuthCheckScreen> createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<AuthCheckScreen> {
  bool checking = true;

  @override
  void initState() {
    super.initState();
    checkAuth();
  }

  Future<void> checkAuth() async {
    final isLoggedIn = await AuthService.isLoggedIn();
    if (!mounted) return;
    
    setState(() => checking = false);

    if (isLoggedIn) {
      // Check user status before navigating (catches blocked users)
      await ErrorHandler.checkUserStatus(context);
      
      // Re-check if still logged in (might have been logged out by error handler)
      final stillLoggedIn = await AuthService.isLoggedIn();
      if (!mounted) return;
      
      if (stillLoggedIn) {
        // Navigate to appropriate home based on role
        await NavigationHelper.navigateToHome(context);
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    } else {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
