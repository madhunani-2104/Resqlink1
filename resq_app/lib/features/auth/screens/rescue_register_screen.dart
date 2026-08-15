import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../widgets/custom_button.dart';
import '../../../widgets/custom_textfield.dart';
import '../providers/auth_provider.dart';

class RescueRegisterScreen extends StatefulWidget {
  static const routeName = '/rescue-register';

  const RescueRegisterScreen({Key? key}) : super(key: key);

  @override
  State<RescueRegisterScreen> createState() => _RescueRegisterScreenState();
}

class _RescueRegisterScreenState extends State<RescueRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _accessCodeController = TextEditingController();

  Future<void> _submitRegister() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.rescueRegister(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      password: _passwordController.text.trim(),
      accessCode: _accessCodeController.text.trim(),
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Rescue team registration failed'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Register Rescue Team')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                CustomTextField(
                  controller: _nameController,
                  labelText: 'Team Member Name',
                  prefixIcon: Icons.person_outline,
                  validator: (val) => val != null && val.trim().isNotEmpty ? null : 'Name required',
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _emailController,
                  labelText: 'Team Email',
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (val) => val != null && val.contains('@') ? null : 'Enter a valid email',
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _phoneController,
                  labelText: 'Team Phone',
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: (val) => val != null && val.trim().isNotEmpty ? null : 'Phone required',
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _passwordController,
                  labelText: 'Password',
                  prefixIcon: Icons.lock_outline,
                  obscureText: true,
                  validator: (val) => val != null && val.length >= 6 ? null : 'Min 6 characters required',
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _accessCodeController,
                  labelText: 'Rescue Access Code',
                  prefixIcon: Icons.verified_user_outlined,
                  obscureText: true,
                  validator: (val) => val != null && val.trim().isNotEmpty ? null : 'Access code required',
                ),
                const SizedBox(height: 24),
                CustomButton(
                  text: 'Create Rescue Account',
                  isLoading: authProvider.status == AuthStatus.authenticating,
                  onPressed: _submitRegister,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
