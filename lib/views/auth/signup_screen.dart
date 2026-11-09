// lib/views/auth/signup_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth_viewmodel.dart';

// ── EcoFlux brand palette — shared across Login / Signup / Forgot Password ──
const _kGreenDark    = Color(0xFF1B5E20);
const _kGreen        = Color(0xFF2E7D32);
const _kGreenLight   = Color(0xFF66BB6A);
const _kGreenSurface = Color(0xFFE8F5E9);
const _kBg           = Color(0xFFF4F6F9);
const _kRed          = Color(0xFFC62828);

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _cnicController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreedToTerms = false;
  String? _selectedRole;

  final List<String> _roles = ['Citizen', 'Worker'];

  late final AnimationController _fadeCtrl;
  late final Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _cnicController.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (_selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Please select a role'),
        backgroundColor: _kRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Please agree to Terms and Conditions'),
        backgroundColor: _kRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Passwords do not match'),
        backgroundColor: _kRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
      return;
    }

    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);

    final fullName =
    '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'
        .trim();

    await authViewModel.signup(
      name: fullName,
      email: _emailController.text.trim(),
      password: _passwordController.text,
      role: _selectedRole!,
      phone: _selectedRole == 'Worker' ? _phoneController.text.trim() : null,
      cnic: _selectedRole == 'Worker' ? _cnicController.text.trim() : null,
    );

    if (authViewModel.errorMessage != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authViewModel.errorMessage!),
          backgroundColor: _kRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      authViewModel.clearError();
    }
  }

  void _showTermsAndConditions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Terms and Conditions'),
        content: const SingleChildScrollView(
          child: Text(
            'These are the Terms and Conditions of EcoFlux Waste Management App.\n\n'
                '1. You agree to use the app only for reporting waste issues.\n'
                '2. All reports must be accurate.\n'
                '3. We reserve the right to suspend accounts that misuse the platform.\n\n'
                'Last updated: April 2026',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: _kGreen)),
          )
        ],
      ),
    );
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Privacy Policy'),
        content: const SingleChildScrollView(
          child: Text(
              'EcoFlux respects your privacy. We do not sell your personal information.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: _kGreen)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_kGreenSurface, Color(0xFFE3F2FD), _kBg],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              FadeTransition(
                opacity: _fadeAnim,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 48),

                        // ── Card ───────────────────────────────────────────
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.94),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: _kGreen.withValues(alpha: 0.15),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Logo bubble
                              Center(
                                child: Container(
                                  width: 96,
                                  height: 96,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: _kGreen.withValues(alpha: 0.18),
                                        width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _kGreen.withValues(alpha: 0.2),
                                        blurRadius: 14,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ClipOval(
                                    child: Image.asset(
                                      'assets/images/logo1.png',
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),

                              const Center(
                                child: Text(
                                  'Create Account',
                                  style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: _kGreenDark),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Center(
                                child: Text('Join EcoFlux today',
                                    style: TextStyle(
                                        fontSize: 13, color: Colors.grey[600])),
                              ),

                              const SizedBox(height: 22),

                              Text('Role',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[700])),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                initialValue: _selectedRole,
                                hint: Text('Select Your Role',
                                    style: TextStyle(color: Colors.grey[400])),
                                items: _roles
                                    .map((role) => DropdownMenuItem(
                                    value: role, child: Text(role)))
                                    .toList(),
                                onChanged: (value) =>
                                    setState(() => _selectedRole = value),
                                decoration: _inputDec(
                                    null, Icons.person_outline),
                                validator: (value) =>
                                value == null ? 'Please select a role' : null,
                              ),

                              const SizedBox(height: 16),

                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        _buildLabel('First Name'),
                                        _buildTextField(_firstNameController,
                                            'First name', Icons.person_outline),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        _buildLabel('Last Name'),
                                        _buildTextField(_lastNameController,
                                            'Last name', Icons.person_outline),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              _buildLabel('Email'),
                              _buildTextField(_emailController, 'you@example.com',
                                  Icons.email_outlined,
                                  keyboardType: TextInputType.emailAddress),

                              // Phone number & CNIC are only collected for
                              // Workers — Citizens don't need them.
                              if (_selectedRole == 'Worker') ...[
                                const SizedBox(height: 16),
                                _buildLabel('Phone Number'),
                                _buildTextField(_phoneController, '03xx-xxxxxxx',
                                    Icons.phone_outlined,
                                    keyboardType: TextInputType.phone),
                                const SizedBox(height: 16),
                                _buildLabel('CNIC'),
                                _buildTextField(_cnicController,
                                    '12345-1234567-1', Icons.credit_card_outlined),
                              ],

                              if (_selectedRole != null) ...[
                                const SizedBox(height: 16),
                                _buildLabel('Password'),
                                _buildTextField(
                                  _passwordController,
                                  'Enter password',
                                  Icons.lock_outline,
                                  isPassword: true,
                                  obscure: _obscurePassword,
                                  onObscureToggle: () => setState(
                                          () => _obscurePassword = !_obscurePassword),
                                ),
                                const SizedBox(height: 16),
                                _buildLabel('Confirm Password'),
                                _buildTextField(
                                  _confirmPasswordController,
                                  'Re-enter password',
                                  Icons.lock_outline,
                                  isPassword: true,
                                  obscure: _obscureConfirmPassword,
                                  onObscureToggle: () => setState(() =>
                                  _obscureConfirmPassword =
                                  !_obscureConfirmPassword),
                                ),
                              ],

                              const SizedBox(height: 20),

                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: Checkbox(
                                      value: _agreedToTerms,
                                      onChanged: (value) =>
                                          setState(() => _agreedToTerms = value!),
                                      activeColor: _kGreen,
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(4)),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        style: TextStyle(
                                            color: Colors.grey[700], fontSize: 13),
                                        children: [
                                          const TextSpan(text: 'I agree to the '),
                                          TextSpan(
                                              text: 'Terms and Conditions',
                                              style: const TextStyle(
                                                  color: _kGreenDark,
                                                  fontWeight: FontWeight.w700,
                                                  decoration:
                                                  TextDecoration.underline),
                                              recognizer: TapGestureRecognizer()
                                                ..onTap = _showTermsAndConditions),
                                          const TextSpan(text: ' and '),
                                          TextSpan(
                                              text: 'Privacy Policy',
                                              style: const TextStyle(
                                                  color: _kGreenDark,
                                                  fontWeight: FontWeight.w700,
                                                  decoration:
                                                  TextDecoration.underline),
                                              recognizer: TapGestureRecognizer()
                                                ..onTap = _showPrivacyPolicy),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 22),

                              authViewModel.isLoading
                                  ? const Center(
                                  child: CircularProgressIndicator(
                                      color: _kGreen, strokeWidth: 2.5))
                                  : SizedBox(
                                width: double.infinity,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [_kGreenLight, _kGreen],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _kGreen.withValues(alpha: 0.35),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: _signup,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 15),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                          BorderRadius.circular(14)),
                                    ),
                                    child: const Text('Sign Up',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 22),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("Already have an account? ",
                                style: TextStyle(color: Colors.grey[700])),
                            TextButton(
                              onPressed: () => Navigator.pushReplacementNamed(
                                  context, '/login_screen'),
                              style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap),
                              child: const Text('Login',
                                  style: TextStyle(
                                      color: _kGreenDark,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),

              // Back Button
              Positioned(
                top: 4,
                left: 4,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: _kGreenDark, size: 26),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text,
        style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700])),
  );

  Widget _buildTextField(
      TextEditingController controller,
      String hint,
      IconData icon, {
        TextInputType? keyboardType,
        bool isPassword = false,
        bool obscure = false,
        VoidCallback? onObscureToggle,
      }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14),
      decoration: _inputDec(
        hint,
        icon,
        suffix: isPassword
            ? IconButton(
          icon: Icon(
              obscure
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: _kGreen,
              size: 20),
          onPressed: onObscureToggle,
        )
            : null,
      ),
      validator: (value) {
        final v = value?.trim() ?? '';
        if (v.isEmpty) return 'This field is required';

        // Email: standard format + local part (before @) must not be
        // all digits (e.g. "0000@gmail.com" is rejected).
        if (hint == 'you@example.com') {
          final emailRegex =
          RegExp(r'^(?=[^@]*[A-Za-z])[\w.+-]+@[\w-]+(\.[\w-]+)+$');
          if (!emailRegex.hasMatch(v)) {
            return 'Enter a valid email (e.g. name@example.com)';
          }
        }

        // Phone: exactly 11 digits, starts with 03, digits only
        // (no dots, dashes or other symbols allowed).
        if (hint == '03xx-xxxxxxx') {
          if (!RegExp(r'^03\d{9}$').hasMatch(v)) {
            return 'Enter a valid 11-digit number (e.g. 03001234567)';
          }
        }

        // CNIC: correct format AND not all zeros.
        if (hint == '12345-1234567-1') {
          if (!RegExp(r'^\d{5}-\d{7}-\d{1}$').hasMatch(v)) {
            return 'CNIC format: 12345-1234567-1';
          }
          final digitsOnly = v.replaceAll('-', '');
          if (RegExp(r'^0+$').hasMatch(digitsOnly)) {
            return 'Enter a valid CNIC number';
          }
        }

        // First / Last Name: letters only (spaces, hyphens and
        // apostrophes allowed for compound names) — no digits or
        // other special symbols.
        if (hint == 'First name' || hint == 'Last name') {
          if (!RegExp(r"^[A-Za-z][A-Za-z\s'-]*$").hasMatch(v)) {
            return 'Only letters are allowed';
          }
        }

        // Password: at least 8 characters, one capital letter and one
        // number. Spaces-only or a single digit will fail this check.
        if (hint == 'Enter password' || hint == 'Re-enter password') {
          if (!RegExp(r'^(?=.*[A-Z])(?=.*\d).{8,}$').hasMatch(v)) {
            return 'Enter a strong password (min 8 chars, 1 capital letter, 1 number)';
          }
        }

        return null;
      },
    );
  }

  InputDecoration _inputDec(String? hint, IconData icon, {Widget? suffix}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
        prefixIcon: Icon(icon, color: _kGreen, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: _kBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _kGreen, width: 1.5),
        ),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );
}