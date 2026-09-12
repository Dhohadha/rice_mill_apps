import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/providers.dart';
import 'main_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final authService = ref.watch(authServiceProvider);

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.teal.shade700,
              Colors.teal.shade900,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                // Logo Container
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.25)),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/GPlogo.png',
                      width: 96,
                      height: 96,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // App Title
                const Text(
                  'Grid Pulse',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Smart Monitoring & Analytics',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.7),
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                // Login Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : () async {
                      setState(() => _isLoading = true);
                      try {
                        final user = await authService.signInWithGoogle();
                        if (user != null && mounted) {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (_) => const MainScreen()),
                          );
                        } else if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Sign in failed')),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _isLoading = false);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.teal.shade900,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading 
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.teal))
                      : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.network(
                            'https://www.gstatic.com/images/branding/googleg/1x/googleg_standard_color_128dp.png',
                            height: 24,
                            errorBuilder: (context, error, stackTrace) => const Icon(
                              Icons.login,
                              color: Colors.teal,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Sign in with Google',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'By signing in, you agree to our Terms & Privacy Policy',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
