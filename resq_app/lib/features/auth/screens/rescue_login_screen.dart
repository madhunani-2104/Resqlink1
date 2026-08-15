import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../widgets/custom_button.dart';
import '../../../widgets/custom_textfield.dart';
import '../providers/auth_provider.dart';
import 'rescue_register_screen.dart';
import '../../rescue_team/screens/rescue_team_portal_screen.dart';

class RescueLoginScreen extends StatefulWidget {
  static const routeName = '/rescue-login';

  const RescueLoginScreen({Key? key}) : super(key: key);

  @override
  State<RescueLoginScreen> createState() => _RescueLoginScreenState();
}

class _RescueLoginScreenState extends State<RescueLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  Future<void> _submitLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.rescueLogin(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const RescueTeamPortalScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Rescue team login failed'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Rescue Team Login')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const Icon(Icons.shield_rounded, size: 76, color: AppColors.headerBlue),
                  const SizedBox(height: 18),
                  const Text(
                    'Rescue Team Portal',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 28),
                  CustomTextField(
                    controller: _emailController,
                    labelText: 'Team Email',
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (val) => val != null && val.contains('@') ? null : 'Enter a valid email',
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: _passwordController,
                    labelText: 'Password',
                    prefixIcon: Icons.lock_outline,
                    obscureText: true,
                    validator: (val) => val != null && val.length >= 6 ? null : 'Min 6 characters required',
                  ),
                  const SizedBox(height: 24),
                  CustomButton(
                    text: 'Enter Rescue Dashboard',
                    isLoading: authProvider.status == AuthStatus.authenticating,
                    onPressed: _submitLogin,
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, RescueRegisterScreen.routeName),
                    child: const Text('Register Rescue Team Account'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}