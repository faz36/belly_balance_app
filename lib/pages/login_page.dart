import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:belly_balance/services/auth_service.dart';
import 'package:belly_balance/pages/signup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final AuthService _authService = AuthService();

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoadingGoogle = false;
  bool _isLoadingEmail = false;
  bool _obscurePassword = true;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  // ── Tokens ───────────────────────────────────────────────────
  static const _primary = Color(0xFF6BAE75);
  static const _primaryDark = Color(0xFF4A9860);
  static const _bg = Color(0xFFFBF7EE);
  static const _soft = Color(0xFFA8D5B0);
  static const _white = Colors.white;
  static const _textDark = Color(0xFF3A3A3A);
  static const _textMid = Color(0xFF7A7A7A);

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnim =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ── Google login ──────────────────────────────────────────────
  Future<void> _loginWithGoogle() async {
    setState(() => _isLoadingGoogle = true);
    try {
      await _authService.signInWithGoogle();
      // MainWrapper will auto-redirect via authStateChanges
    } catch (e) {
      _showError('Log masuk Google gagal. Cuba lagi.');
    } finally {
      if (mounted) setState(() => _isLoadingGoogle = false);
    }
  }

  // ── Email login ───────────────────────────────────────────────
  Future<void> _loginWithEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoadingEmail = true);
    try {
      await _authService.signInWithEmail(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
      );
      // MainWrapper will auto-redirect via authStateChanges
    } on Exception catch (e) {
      final msg = e.toString();
      if (msg.contains('user-not-found') || msg.contains('wrong-password') ||
          msg.contains('invalid-credential')) {
        _showError('Email atau kata laluan tidak betul.');
      } else if (msg.contains('invalid-email')) {
        _showError('Format email tidak sah.');
      } else if (msg.contains('too-many-requests')) {
        _showError('Terlalu banyak percubaan. Cuba lagi sebentar.');
      } else {
        _showError('Log masuk gagal. Cuba lagi.');
      }
    } finally {
      if (mounted) setState(() => _isLoadingEmail = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Poppins')),
        backgroundColor: Colors.red[400],
        behavior: SnackBarBehavior.floating,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  String? _validateEmail(String? v) {
    if (v == null || v.isEmpty) return 'Email diperlukan';
    final emailRegex = RegExp(r'^[\w.-]+@[\w.-]+\.\w+$');
    if (!emailRegex.hasMatch(v)) return 'Format email tidak sah';
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Kata laluan diperlukan';
    if (v.length < 6) return 'Sekurang-kurangnya 6 aksara';
    if (!RegExp(r'[A-Z]').hasMatch(v)) return 'Mesti ada huruf besar (A-Z)';
    if (!RegExp(r'[a-z]').hasMatch(v)) return 'Mesti ada huruf kecil (a-z)';
    if (!RegExp(r'[0-9]').hasMatch(v)) return 'Mesti ada nombor (0-9)';
    if (!RegExp(r'[!@#\$%^&*()_\-]').hasMatch(v)) return r'Mesti ada simbol (!@#$%^&*()_-)';
    return null;
  }

  // ═══════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          Positioned(
            top: -80, right: -60,
            child: Container(
              width: 240, height: 240,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _soft.withOpacity(0.35)),
            ),
          ),
          Positioned(
            bottom: -60, left: -60,
            child: Container(
              width: 200, height: 200,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _primary.withOpacity(0.1)),
            ),
          ),

          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Logo
                    Align(
                      alignment: const Alignment(0.15, 0),
                      child: SvgPicture.asset(
                        'assets/images/bb_logo.svg',
                        width: 160,
                        height: 186,
                      ),
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      'Selamat Kembali',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: _textDark,
                          letterSpacing: -0.5),
                    ),

                    const SizedBox(height: 6),

                    const Text(
                      'Log masuk untuk teruskan\nperjalanan kehamilan anda',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          color: _textMid,
                          height: 1.6),
                    ),

                    const SizedBox(height: 28),

                    // ── Email Form ──────────────────────────────
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _buildField(
                            controller: _emailCtrl,
                            label: 'Alamat Email',
                            hint: 'contoh@email.com',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: _validateEmail,
                          ),

                          const SizedBox(height: 14),

                          _buildField(
                            controller: _passwordCtrl,
                            label: 'Kata Laluan',
                            hint: 'Min. 6 aksara, huruf, nombor & simbol',
                            icon: Icons.lock_outline_rounded,
                            obscure: _obscurePassword,
                            validator: _validatePassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: _textMid,
                                size: 20,
                              ),
                              onPressed: () => setState(() =>
                              _obscurePassword = !_obscurePassword),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Log Masuk button
                          SizedBox(
                            width: double.infinity,
                            child: GestureDetector(
                              onTap: _isLoadingEmail
                                  ? null
                                  : _loginWithEmail,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding:
                                const EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  gradient: _isLoadingEmail
                                      ? LinearGradient(colors: [
                                    Colors.grey.shade400,
                                    Colors.grey.shade500,
                                  ])
                                      : const LinearGradient(
                                      colors: [_primary, _primaryDark],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                        color: _primary.withOpacity(0.35),
                                        blurRadius: 14,
                                        offset: const Offset(0, 6))
                                  ],
                                ),
                                child: Center(
                                  child: _isLoadingEmail
                                      ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        color: _white,
                                        strokeWidth: 2.5),
                                  )
                                      : const Text('Log Masuk',
                                      style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: _white)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Divider ─────────────────────────────────
                    Row(children: [
                      Expanded(
                          child: Divider(
                              color: Colors.grey.withOpacity(0.25),
                              thickness: 1)),
                      Padding(
                        padding:
                        const EdgeInsets.symmetric(horizontal: 14),
                        child: Text('atau',
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                color: _textMid.withOpacity(0.7))),
                      ),
                      Expanded(
                          child: Divider(
                              color: Colors.grey.withOpacity(0.25),
                              thickness: 1)),
                    ]),

                    const SizedBox(height: 20),

                    // ── Google button ───────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: GestureDetector(
                        onTap:
                        _isLoadingGoogle ? null : _loginWithGoogle,
                        child: Container(
                          padding:
                          const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: _white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: Colors.grey.withOpacity(0.2),
                                width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4))
                            ],
                          ),
                          child: _isLoadingGoogle
                              ? const Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  color: _primary,
                                  strokeWidth: 2.5),
                            ),
                          )
                              : Row(
                            mainAxisAlignment:
                            MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                  'assets/images/google_logo.png',
                                  width: 22,
                                  height: 22),
                              const SizedBox(width: 10),
                              const Text('Teruskan dengan Google',
                                  style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: _textDark)),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Signup link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Belum ada akaun? ',
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13,
                                color: _textMid)),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const SignupPage()),
                          ),
                          child: const Text('Daftar sekarang',
                              style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _primary)),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    String? Function(String?)? validator,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: _textDark)),
        const SizedBox(height: 7),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(
              fontFamily: 'Poppins', fontSize: 14, color: _textDark),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: _textMid.withOpacity(0.6)),
            prefixIcon: Icon(icon, color: _primary, size: 20),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: _white,
            contentPadding: const EdgeInsets.symmetric(
                vertical: 14, horizontal: 16),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                BorderSide(color: Colors.grey.withOpacity(0.2))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                BorderSide(color: Colors.grey.withOpacity(0.2))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                const BorderSide(color: _primary, width: 1.5)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                    color: Colors.red.shade300, width: 1.5)),
            focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                    color: Colors.red.shade400, width: 1.5)),
            errorStyle:
            const TextStyle(fontFamily: 'Poppins', fontSize: 11),
          ),
        ),
      ],
    );
  }
}