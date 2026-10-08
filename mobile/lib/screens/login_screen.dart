import 'package:flutter/material.dart';
import '../services/session_service.dart';
import '../services/api_service.dart';

class ThemeColors {
  static const primary = Color(0xFFFF2D95);
  static const secondary = Color(0xFFFF73B8);
  static const background = Color(0xFFFFF8FC);
  static const heading = Color(0xFF14142B);
  static const subtitle = Color(0xFF7D6B82);
  static const border = Color(0xFFFFD3E7);
}

class WelcomePill extends StatelessWidget {
  const WelcomePill({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ThemeColors.border),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_user_outlined,
              size: 16, color: ThemeColors.primary),
          SizedBox(width: 6),
          Text(
            'Registered Patient Access',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: ThemeColors.heading,
            ),
          ),
        ],
      ),
    );
  }
}

class WelcomeHeading extends StatelessWidget {
  const WelcomeHeading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Text(
          'Sign In',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: ThemeColors.heading,
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Enter the details your doctor registered',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: ThemeColors.subtitle),
        ),
      ],
    );
  }
}

class CardHeader extends StatelessWidget {
  const CardHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [ThemeColors.primary, ThemeColors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: ThemeColors.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Icon(Icons.person, size: 28, color: Colors.white),
    );
  }
}

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType keyboardType;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(
        fontSize: 15,
        color: ThemeColors.heading,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: ThemeColors.subtitle,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(icon, color: ThemeColors.primary, size: 20),
        filled: true,
        fillColor: ThemeColors.background,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: ThemeColors.border.withValues(alpha: 0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: ThemeColors.border.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: ThemeColors.primary, width: 1.5),
        ),
      ),
    );
  }
}

class GradientButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool busy;

  const GradientButton({super.key, required this.onPressed, this.busy = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [ThemeColors.primary, Color(0xFFD946A8), ThemeColors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: ThemeColors.primary.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: busy ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
            : const Text(
                'Sign In',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }
}

class TrustMessage extends StatelessWidget {
  const TrustMessage({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Divider(
            thickness: 1,
            color: ThemeColors.border.withValues(alpha: 0.5),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(Icons.shield, size: 13, color: ThemeColors.subtitle.withValues(alpha: 0.6)),
              const SizedBox(width: 4),
              Text(
                'Trusted by 10,000+ mothers',
                style: TextStyle(
                  fontSize: 11,
                  color: ThemeColors.subtitle.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Divider(
            thickness: 1,
            color: ThemeColors.border.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}

class FeatureChips extends StatelessWidget {
  const FeatureChips({super.key});

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _chip(Icons.lock_outline, 'Safe & Secure'),
          const SizedBox(width: 8),
          _chip(Icons.auto_awesome, 'AI Powered'),
          const SizedBox(width: 8),
          _chip(Icons.devices, 'IoT Enabled'),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ThemeColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ThemeColors.border.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: ThemeColors.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: ThemeColors.subtitle,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _serverController = TextEditingController();
  bool _checking = true;
  bool _busy = false;
  bool _showServer = false;

  @override
  void initState() {
    super.initState();
    _autoLogin();
  }

  Future<void> _autoLogin() async {
    await ApiService.loadBase();
    _serverController.text = await SessionService.loadServerIp();
    final loggedIn = await SessionService.isLoggedIn();
    if (!mounted) return;
    if (loggedIn) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      setState(() => _checking = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _serverController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      _showError('Please enter your name and phone number');
      return;
    }
    if (phone.replaceAll(RegExp(r'\D'), '').length < 10) {
      _showError('Please enter a valid 10-digit phone number');
      return;
    }
    final ip = _serverController.text.trim();
    if (ip.isNotEmpty) {
      await SessionService.saveServerIp(ip);
      await ApiService.loadBase();
    }
    setState(() => _busy = true);

    // Enrolment-gated: only patients registered by the doctor can sign in.
    final res = await ApiService.login(name, phone);
    if (!mounted) return;
    setState(() => _busy = false);

    if (res['ok'] != true) {
      _showError((res['error'] as String?) ?? 'Login failed');
      return;
    }

    final patientId = (res['patient_id'] as String?) ?? 'P001';
    final existing = await SessionService.loadProfile();
    await SessionService.saveProfile(
      name: (res['name'] as String?) ?? name,
      phone: (res['phone'] as String?) ?? phone,
      week: (res['gestational_week'] as num?)?.toInt() ??
          (existing['week'] as int? ?? 28),
      due: _formatDue((res['due_date'] as String?) ?? ''),
      emergency: existing['emergency'] as String? ?? '',
      age: (res['age'] as num?)?.toInt() ?? (existing['age'] as int? ?? 27),
      bloodGroup: (res['blood_group'] as String?) ??
          (existing['bloodGroup'] as String? ?? ''),
      patientId: patientId,
    );
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/home');
  }

  static String _formatDue(String iso) {
    if (iso.isEmpty) return 'Sep 15, 2026';
    try {
      final d = DateTime.parse(iso);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${d.day} ${months[d.month - 1]}, ${d.year}';
    } catch (_) {
      return iso;
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFFD32F2F),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: ThemeColors.primary),
        ),
      );
    }
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/loginbg.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: 0.1),
                Colors.white.withValues(alpha: 0.4),
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const WelcomePill(),
                    const SizedBox(height: 20),
                    const WelcomeHeading(),
                    const SizedBox(height: 28),
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(36),
                        border: Border.all(
                          color: ThemeColors.border.withValues(alpha: 0.3),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: ThemeColors.primary.withValues(alpha: 0.06),
                            blurRadius: 40,
                            spreadRadius: 10,
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const CardHeader(),
                          const SizedBox(height: 20),
                          CustomTextField(
                            controller: _nameController,
                            label: 'Full Name',
                            icon: Icons.person_outline,
                          ),
                          const SizedBox(height: 16),
                          CustomTextField(
                            controller: _phoneController,
                            label: 'Phone Number',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () =>
                                  setState(() => _showServer = !_showServer),
                              icon: Icon(
                                _showServer
                                    ? Icons.expand_less
                                    : Icons.dns_outlined,
                                size: 16,
                                color: ThemeColors.subtitle,
                              ),
                              label: const Text(
                                'Server settings',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: ThemeColors.subtitle,
                                ),
                              ),
                            ),
                          ),
                          if (_showServer) ...[
                            const SizedBox(height: 4),
                            CustomTextField(
                              controller: _serverController,
                              label: 'Server IP (no port)',
                              icon: Icons.lan_outlined,
                            ),
                            const SizedBox(height: 8),
                          ],
                          const SizedBox(height: 12),
                          GradientButton(
                              onPressed: _busy ? () {} : _login,
                              busy: _busy),
                          const SizedBox(height: 12),
                          const TrustMessage(),
                          const SizedBox(height: 10),
                          Text(
                            'New here? Ask your doctor to register you — '
                            'accounts are created by the clinic.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: ThemeColors.subtitle,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const FeatureChips(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
