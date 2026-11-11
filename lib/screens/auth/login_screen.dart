import 'package:flutter/material.dart';
import '../../widgets/language_selector.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/ha_text_field.dart';
import '../admin/admin_dashboard.dart';
import '../teacher/teacher_dashboard.dart';
import '../parent/parent_dashboard.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  // ── Email form ─────────────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _obscurePassword = true;

  // ── Phone form ─────────────────────────────────────────────────────────────
  final _phoneCtrl   = TextEditingController();
  final _otpCtrl     = TextEditingController();
  String? _verificationId;
  int?    _resendToken;
  bool    _otpSent   = false;
  bool    _phoneBusy = false;
  String? _phoneError;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  // ── Phone: send OTP ────────────────────────────────────────────────────────
  Future<void> _sendOtp() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      setState(() => _phoneError = 'Enter your phone number');
      return;
    }
    // Ensure E.164 format
    final e164 = phone.startsWith('+') ? phone : '+$phone';
    setState(() { _phoneBusy = true; _phoneError = null; });

    await context.read<AuthProvider>().verifyPhone(
      phoneNumber: e164,
      resendToken: _resendToken,
      onCodeSent: (vid, token) {
        if (!mounted) return;
        setState(() {
          _verificationId = vid;
          _resendToken    = token;
          _otpSent        = true;
          _phoneBusy      = false;
        });
      },
      onAutoVerified: (credential) async {
        // Auto-verified on Android — sign in immediately
        if (!mounted) return;
        setState(() => _phoneBusy = true);
        final auth = context.read<AuthProvider>();
        final ok = await auth.signInWithOtp(
          verificationId: credential.verificationId!,
          smsCode: credential.smsCode!,
        );
        if (!mounted) return;
        setState(() => _phoneBusy = false);
        if (ok && auth.currentUser != null) {
          _navigateToDashboard(auth.currentUser!.role);
        }
      },
      onFailed: (e) {
        if (!mounted) return;
        setState(() {
          _phoneBusy  = false;
          _phoneError = e.message ?? 'Failed to send OTP. Check the number.';
        });
      },
      onTimeout: (_) {
        if (!mounted) return;
        setState(() => _phoneBusy = false);
      },
    );
  }

  // ── Phone: verify OTP ──────────────────────────────────────────────────────
  Future<void> _verifyOtp() async {
    final code = _otpCtrl.text.trim();
    if (code.length < 6) {
      setState(() => _phoneError = 'Enter the 6-digit code');
      return;
    }
    if (_verificationId == null) return;
    setState(() { _phoneBusy = true; _phoneError = null; });

    final auth = context.read<AuthProvider>();
    final ok = await auth.signInWithOtp(
      verificationId: _verificationId!,
      smsCode: code,
    );

    if (!mounted) return;
    setState(() => _phoneBusy = false);

    if (ok && auth.currentUser != null) {
      _navigateToDashboard(auth.currentUser!.role);
    } else {
      setState(() => _phoneError = auth.errorMessage ?? 'Invalid OTP.');
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final auth = context.read<AuthProvider>();
    final success = await auth.signIn(_emailCtrl.text, _passwordCtrl.text);

    if (!mounted) return;

    if (success && auth.currentUser != null) {
      _navigateToDashboard(auth.currentUser!.role);
    } else if (auth.isAccountDeactivated) {
      auth.clearError();
      _showDeactivatedDialog();
    }
  }

  void _showDeactivatedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: EdgeInsets.zero,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.error.withAlpha(15),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withAlpha(20),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.block_outlined,
                      color: AppColors.error, size: 36),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Account Deactivated',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.error,),
                ),
              ]),
            ),
            // Body
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Column(children: [
                Text(
                  'Your account has been deactivated and you cannot access the platform.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: context.textPrimary,height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.secondary.withOpacity(0.2)),
                  ),
                  child: Row(children: [
                    Icon(Icons.info_outline,
                        size: 18, color: context.brand),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Please contact the administrator to reactivate your account.',
                        style: TextStyle(
                          fontSize: 13,
                          color: context.brand,height: 1.4,
                        ),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size(double.infinity, 46),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('OK',
                        style: TextStyle(fontWeight: FontWeight.bold,
                            fontSize: 15)),
                  ),
                ),
                const SizedBox(height: 16),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToDashboard(UserRole role) {
    Widget screen;
    switch (role) {
      case UserRole.admin:
      case UserRole.subAdmin:
        screen = const AdminDashboard();
        break;
      case UserRole.teacher:
        screen = const TeacherDashboard();
        break;
      case UserRole.student:
        screen = const ParentDashboard();
        break;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 720;

    return Scaffold(
      backgroundColor: context.pageBg,
      body: Row(
        children: [
          if (isWide) _buildLeftPanel(size),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 40,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Language selector
                      const Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: LanguageMenuButton(),
                      ),
                      const SizedBox(height: 8),

                      // Logo (mobile only)
                      Builder(builder: (context) {
                        if (isWide) return const SizedBox.shrink();
                        return Center(
                          child: Column(
                            children: [
                              Image.asset('assets/images/logo.png',
                                  width: 100, height: 100,
                                  fit: BoxFit.contain),
                              const SizedBox(height: 10),
                              Text('Hope Academy Egypt',
                                  style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: context.brand)),
                              const SizedBox(height: 24),
                            ],
                          ),
                        );
                      }),

                      // Title
                      Text('Welcome back',
                          style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: context.textPrimary)),
                      const SizedBox(height: 6),
                      Text('Sign in to your Hope Academy account',
                          style: TextStyle(
                              fontSize: 15,
                              color: context.textSecondary)),
                      const SizedBox(height: 24),

                      // Tab bar (Email / Phone)
                      Container(
                        decoration: BoxDecoration(
                          color: context.softFill,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TabBar(
                          controller: _tabCtrl,
                          labelColor: Colors.white,
                          unselectedLabelColor: context.textSecondary,
                          indicator: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          indicatorSize: TabBarIndicatorSize.tab,
                          dividerColor: Colors.transparent,
                          padding: const EdgeInsets.all(4),
                          tabs: const [
                            Tab(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.email_outlined, size: 16),
                                  SizedBox(width: 6),
                                  Text('Email', style: TextStyle(fontSize: 13)),
                                ],
                              ),
                            ),
                            Tab(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.phone_outlined, size: 16),
                                  SizedBox(width: 6),
                                  Text('Phone', style: TextStyle(fontSize: 13)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Tab content
                      [_buildEmailForm(), _buildPhoneForm()][_tabCtrl.index],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftPanel(Size size) {
    return Container(
      width: size.width * 0.42,
      height: size.height,
      decoration: const BoxDecoration(
        gradient: AppColors.primaryGradient,
      ),
      child: Stack(
        children: [
          // Background pattern
          Positioned.fill(
            child: CustomPaint(painter: _CirclePatternPainter()),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: context.cardBg,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(38),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Hope Academy\nEgypt',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,height: 1.25,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  height: 3,
                  width: 50,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Specialized Academy\nfor Children with Special Needs',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.8),height: 1.6,
                  ),
                ),
                const SizedBox(height: 48),
                ...[
                  _featureTile(Icons.school, 'Personalized Learning Plans'),
                  _featureTile(Icons.psychology, 'Expert Therapists & Teachers'),
                  _featureTile(Icons.family_restroom, 'Parent-Centered Approach'),
                  _featureTile(Icons.auto_awesome, 'AI-Powered Progress Reports'),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _featureTile(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.accent, size: 20),
          ),
          const SizedBox(width: 14),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.9),),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailForm() {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        return Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Error banner
              if (auth.errorMessage != null)
                _buildErrorBanner(auth.errorMessage!, auth),

              // Email
              HaTextField(
                controller: _emailCtrl,
                label: 'Email address',
                hint: 'your.email@hopeacademy.eg',
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                focusNode: _emailFocus,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) =>
                    FocusScope.of(context).requestFocus(_passwordFocus),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Email is required';
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) {
                    return 'Enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),

              // Password
              HaTextField(
                controller: _passwordCtrl,
                label: 'Password',
                hint: '••••••••',
                prefixIcon: Icons.lock_outline,
                obscureText: _obscurePassword,
                focusNode: _passwordFocus,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                suffixWidget: GestureDetector(
                  onTap: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  child: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: context.textSecondary,
                    size: 20,
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Password is required';
                  if (v.length < 6)
                    return 'Password must be at least 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Forgot password
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    auth.clearError();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const ForgotPasswordScreen()),
                    );
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: context.brand,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 36),
                  ),
                  child: const Text('Forgot password?',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 24),

              // Sign In button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: auth.isLoading ? null : _submit,
                  child: auth.isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white))
                      : const Text('Sign In'),
                ),
              ),
              const SizedBox(height: 32),
              _buildRoleInfo(),
            ],
          ),
        );
      },
    );
  }

  // ── Phone sign-in form ─────────────────────────────────────────────────────

  Widget _buildPhoneForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Error banner
        if (_phoneError != null)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: AppColors.error.withOpacity(0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.error_outline,
                  color: AppColors.error, size: 20),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(_phoneError!,
                      style: const TextStyle(
                          color: AppColors.error, fontSize: 13))),
              GestureDetector(
                onTap: () => setState(() => _phoneError = null),
                child: const Icon(Icons.close,
                    color: AppColors.error, size: 18),
              ),
            ]),
          ),

        if (!_otpSent) ...[
          // Phone number input
          HaTextField(
            controller: _phoneCtrl,
            label: 'Phone number',
            hint: '+216 XX XXX XXX',
            prefixIcon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _sendOtp(),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter your number in international format (e.g. +21612345678)',
            style:
                TextStyle(fontSize: 12, color: context.textSecondary),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _phoneBusy ? null : _sendOtp,
              icon: _phoneBusy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.sms_outlined, size: 18),
              label:
                  Text(_phoneBusy ? 'Sending...' : 'Send OTP Code'),
            ),
          ),
        ] else ...[
          // OTP input
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.success.withOpacity(0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.check_circle_outline,
                  color: AppColors.success, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Code sent to ${_phoneCtrl.text.trim()}',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.success),
                ),
              ),
              TextButton(
                onPressed: _phoneBusy
                    ? null
                    : () {
                        setState(() {
                          _otpSent    = false;
                          _otpCtrl.clear();
                          _phoneError = null;
                        });
                      },
                style: TextButton.styleFrom(
                    foregroundColor: context.brand,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 30)),
                child: const Text('Change',
                    style: TextStyle(fontSize: 12)),
              ),
            ]),
          ),
          const SizedBox(height: 20),

          HaTextField(
            controller: _otpCtrl,
            label: '6-digit code',
            hint: '123456',
            prefixIcon: Icons.pin_outlined,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _verifyOtp(),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text("Didn't receive it? ",
                  style: TextStyle(
                      fontSize: 12, color: context.textSecondary)),
              GestureDetector(
                onTap: _phoneBusy
                    ? null
                    : () {
                        setState(() {
                          _otpSent    = false;
                          _otpCtrl.clear();
                          _phoneError = null;
                        });
                        _sendOtp();
                      },
                child: Text('Resend',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: context.brand)),
              ),
            ],
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _phoneBusy ? null : _verifyOtp,
              icon: _phoneBusy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.login_rounded, size: 18),
              label:
                  Text(_phoneBusy ? 'Verifying...' : 'Verify & Sign In'),
            ),
          ),
        ],

        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.info.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.info.withOpacity(0.2)),
          ),
          child: Row(children: [
            Icon(Icons.info_outline, size: 16, color: AppColors.info),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Phone sign-in only works if your phone number is registered by an administrator.',
                style: TextStyle(
                    fontSize: 12, color: context.textSecondary),
              ),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _buildErrorBanner(String message, AuthProvider auth) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 13,),
            ),
          ),
          GestureDetector(
            onTap: auth.clearError,
            child: const Icon(Icons.close, color: AppColors.error, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.secondary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.secondary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: context.brand),
              SizedBox(width: 6),
              Text(
                'Portal Access',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: context.brand,),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _roleInfoRow(Icons.admin_panel_settings, 'Administrator', 'Full platform management'),
          _roleInfoRow(Icons.school, 'Teacher', 'Student tracking & reports'),
          _roleInfoRow(Icons.family_restroom, 'Student', 'View child\'s progress'),
        ],
      ),
    );
  }

  Widget _roleInfoRow(IconData icon, String role, String desc) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: context.textSecondary),
          const SizedBox(width: 6),
          Text(
            '$role — ',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,),
          ),
          Text(
            desc,
            style: TextStyle(
              fontSize: 12,
              color: context.textSecondary,),
          ),
        ],
      ),
    );
  }
}

// ─── Background circle pattern painter ────────────────────────────────────────
class _CirclePatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.15),
      120,
      paint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.1, size.height * 0.75),
      80,
      paint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.9),
      100,
      paint,
    );

    final fillPaint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.15),
      120,
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
