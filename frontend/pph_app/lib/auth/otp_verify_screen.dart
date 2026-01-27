import 'package:flutter/material.dart';
import 'auth_service.dart';
import '../pastor/pastor_shell.dart';
import '../member/member_shell.dart';

class OtpVerifyScreen extends StatefulWidget {
  final String value;
  const OtpVerifyScreen({super.key, required this.value});

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
  final _formKey = GlobalKey<FormState>();
  final otpCtrl = TextEditingController();
  final nameCtrl = TextEditingController();
  final usernameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  bool loading = false;
  String? error;
  bool isNewUser = false;
  bool showPassword = false;

  Future<void> verify() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final result = await AuthService.verifyOtp(
        widget.value,
        otpCtrl.text.trim(),
        isNewUser ? nameCtrl.text.trim() : null,
        isNewUser ? usernameCtrl.text.trim() : null,
        isNewUser && emailCtrl.text.trim().isNotEmpty ? emailCtrl.text.trim() : null,
        isNewUser && passwordCtrl.text.trim().isNotEmpty ? passwordCtrl.text.trim() : null,
      );

      if (!mounted) return;

      setState(() => loading = false);

      if (result != null && mounted) {
        // Navigate based on role - use role from response
        final role = result["role"] as String? ?? "member";
        final isPastor = role == "pastor" || role == "admin";
        
        print("OTP verification successful - Role: $role, IsPastor: $isPastor");
        
        if (isPastor) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const PastorShell()),
            (_) => false,
          );
        } else {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const MemberShell()),
            (_) => false,
          );
        }
      } else if (mounted) {
        setState(() {
          error = isNewUser
              ? "Registration failed. Please check your details."
              : "Invalid OTP. Please try again.";
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        // Show backend error message if available, otherwise generic error
        error = e.toString().replaceAll("Exception: ", "");
      });
    }
  }

  @override
  void dispose() {
    otpCtrl.dispose();
    nameCtrl.dispose();
    usernameCtrl.dispose();
    emailCtrl.dispose();
    passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEmail = widget.value.contains("@");

    return Scaffold(
      appBar: AppBar(
        title: const Text("Verify OTP"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              const Icon(
                Icons.verified_user,
                size: 80,
                color: Colors.blue,
              ),
              const SizedBox(height: 20),
              Text(
                "OTP sent to ${widget.value}",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 40),
              TextFormField(
                controller: otpCtrl,
                decoration: const InputDecoration(
                  labelText: "Enter OTP",
                  hintText: "123456",
                  prefixIcon: Icon(Icons.pin),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                maxLength: 6,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Please enter OTP";
                  }
                  if (value.trim().length < 4) {
                    return "OTP must be at least 4 digits";
                  }
                  return null;
                },
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text("New user? Register with OTP"),
                value: isNewUser,
                onChanged: (value) {
                  setState(() {
                    isNewUser = value ?? false;
                  });
                },
              ),
              if (isNewUser) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: "Full Name *",
                    hintText: "Enter your full name",
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (isNewUser &&
                        (value == null || value.trim().isEmpty)) {
                      return "Please enter your name";
                    }
                    return null;
                  },
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: usernameCtrl,
                  decoration: const InputDecoration(
                    labelText: "Username *",
                    hintText: "Choose a username",
                    prefixIcon: Icon(Icons.account_circle),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (isNewUser &&
                        (value == null || value.trim().isEmpty)) {
                      return "Please enter a username";
                    }
                    return null;
                  },
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(
                    labelText: "Email (Optional)",
                    hintText: "example@email.com",
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value != null && value.trim().isNotEmpty) {
                      if (!value.contains("@") || !value.contains(".")) {
                        return "Please enter a valid email";
                      }
                    }
                    return null;
                  },
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: passwordCtrl,
                  decoration: InputDecoration(
                    labelText: "Password (Optional)",
                    hintText: "Set a password for future login",
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(showPassword ? Icons.visibility : Icons.visibility_off),
                      onPressed: () {
                        setState(() {
                          showPassword = !showPassword;
                        });
                      },
                    ),
                    border: const OutlineInputBorder(),
                    helperText: "Set now or skip - you can add it later in settings",
                  ),
                  obscureText: !showPassword,
                  validator: (value) {
                    if (value != null && value.trim().isNotEmpty) {
                      if (value.trim().length < 6) {
                        return "Password must be at least 6 characters";
                      }
                    }
                    return null;
                  },
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => verify(),
                ),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    "💡 Tip: Setting a password lets you login with username/email + password later",
                    style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              ElevatedButton(
                onPressed: loading ? null : verify,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        isNewUser ? "Register & Login" : "Verify",
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

