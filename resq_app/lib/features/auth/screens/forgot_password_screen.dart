import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../../../widgets/custom_button.dart';
import '../../../widgets/custom_textfield.dart';
import '../../../core/constants/app_colors.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({Key? key}) : super(key: key);

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isSent = false;
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.severityCritical : AppColors.success,
      ),
    );
  }

  void _handleResetRequest() async {
    final email = _emailController.text.trim();
    if (!email.contains('@')) {
      _showSnack('Please enter a valid email address.', isError: true);
      return;
    }

    setState(() => _loading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.forgotPassword(email);

    setState(() {
      _loading = false;
      if (success) _isSent = true;
    });

    if (success) {
      _showSnack('Recovery code sent. Check your email (or server console in dev).');
    } else {
      _showSnack(authProvider.errorMessage ?? 'Failed to send instructions.', isError: true);
    }
  }

  void _handleResetPassword() async {
    final otp = _otpController.text.trim();
    final newPassword = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (otp.isEmpty) {
      _showSnack('Please enter the reset code.', isError: true);
      return;
    }
    if (newPassword.length < 6) {
      _showSnack('Password must be at least 6 characters.', isError: true);
      return;
    }
    if (newPassword != confirmPassword) {
      _showSnack('Passwords do not match.', isError: true);
      return;
    }

    setState(() => _loading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.resetPassword(
      _emailController.text.trim(),
      otp,
      newPassword,
    );
    setState(() => _loading = false);

    if (success) {
      _showSnack('Password reset successful. You can now log in.');
      if (mounted) Navigator.pop(context);
    } else {
      _showSnack(authProvider.errorMessage ?? 'Failed to reset password.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Forgot Your Password?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _isSent
                  ? 'Enter the reset code sent to your email and your new password.'
                  : 'Enter your registered email address to receive a recovery code.',
              style: const TextStyle(fontSize: 14, color: Colors.white70),
            ),
            const SizedBox(height: 24),
            CustomTextField(
              controller: _emailController,
              labelText: 'Email Address',
              prefixIcon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              enabled: !_isSent,
            ),
            if (_isSent) ...[
              const SizedBox(height: 24),
              CustomTextField(
                controller: _otpController,
                labelText: 'Reset Code (OTP)',
                prefixIcon: Icons.lock_clock_outlined,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _passwordController,
                labelText: 'New Password',
                prefixIcon: Icons.lock_outline,
                obscureText: _obscurePassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _confirmPasswordController,
                labelText: 'Confirm New Password',
                prefixIcon: Icons.lock_outline,
                obscureText: _obscureConfirmPassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                ),
              ),
            ],
            const SizedBox(height: 24),
            if (!_isSent)
              CustomButton(
                text: 'Send Recovery Code',
                isLoading: _loading,
                onPressed: _handleResetRequest,
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CustomButton(
                    text: 'Reset Password',
                    isLoading: _loading,
                    onPressed: _handleResetPassword,
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _loading ? null : _handleResetRequest,
                    child: const Text('Resend Recovery Code'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
