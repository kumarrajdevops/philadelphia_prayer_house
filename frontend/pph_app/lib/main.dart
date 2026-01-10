import 'package:flutter/material.dart';
import 'auth/login_screen.dart';
import 'auth/auth_service.dart';
import 'utils/navigation_helper.dart';

void main() {
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
      // Navigate to appropriate home based on role
      await NavigationHelper.navigateToHome(context);
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
