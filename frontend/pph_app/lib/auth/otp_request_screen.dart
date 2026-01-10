import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'otp_verify_screen.dart';

class OtpRequestScreen extends StatefulWidget {
  const OtpRequestScreen({super.key});

  @override
  State<OtpRequestScreen> createState() => _OtpRequestScreenState();
}

class _OtpRequestScreenState extends State<OtpRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final ctrl = TextEditingController();
  bool loading = false;
  String? error;

  Future<void> requestOtp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final ok = await AuthService.requestOtp(ctrl.text.trim());

      if (!mounted) return;

      setState(() => loading = false);

      if (ok) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpVerifyScreen(value: ctrl.text.trim()),
          ),
        );
      } else {
        setState(() => error = "Failed to send OTP. Please try again.");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = "Connection error. Please try again.";
      });
    }
  }

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEmail = ctrl.text.contains("@");

    return Scaffold(
      appBar: AppBar(
        title: const Text("Request OTP"),
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
                Icons.sms,
                size: 80,
                color: Colors.blue,
              ),
              const SizedBox(height: 20),
              const Text(
                "Enter your phone number or email",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 40),
              TextFormField(
                controller: ctrl,
                decoration: InputDecoration(
                  labelText: isEmail ? "Email" : "Phone Number",
                  hintText: isEmail
                      ? "example@email.com"
                      : "+1234567890",
                  prefixIcon: Icon(isEmail ? Icons.email : Icons.phone),
                  border: const OutlineInputBorder(),
                ),
                keyboardType: isEmail
                    ? TextInputType.emailAddress
                    : TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Please enter ${isEmail ? 'email' : 'phone number'}";
                  }
                  if (isEmail && !value.contains("@")) {
                    return "Please enter a valid email";
                  }
                  return null;
                },
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => requestOtp(),
                onChanged: (value) {
                  setState(() {}); // Rebuild to update icon
                },
              ),
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
                onPressed: loading ? null : requestOtp,
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
                    : const Text(
                        "Send OTP",
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

