import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:belly_balance/pages/login_page.dart';
import 'package:belly_balance/providers/user_provider.dart';
import 'package:belly_balance/main.dart';

class MainWrapper extends StatelessWidget {
  const MainWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }
        if (snapshot.hasData && snapshot.data != null) {
          return _DataLoader();
        }
        return const LoginPage();
      },
    );
  }
}

class _DataLoader extends StatefulWidget {
  @override
  State<_DataLoader> createState() => _DataLoaderState();
}

class _DataLoaderState extends State<_DataLoader> {
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await context.read<UserProvider>().loadUserData();
    if (mounted) setState(() => _loaded = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const _LoadingScreen();
    return const MainPage();
  }
}

class _LoadingScreen extends StatefulWidget {
  const _LoadingScreen();

  @override
  State<_LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<_LoadingScreen>
    with TickerProviderStateMixin {
  static const _primary = Color(0xFF6BAE75);
  static const _bg = Color(0xFFFBF7EE);

  late List<AnimationController> _dotControllers;
  late List<Animation<double>> _dotAnims;

  @override
  void initState() {
    super.initState();
    _dotControllers = List.generate(
      3,
          (i) => AnimationController(
          vsync: this, duration: const Duration(milliseconds: 600)),
    );
    _dotAnims = _dotControllers
        .map((c) => Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: c, curve: Curves.easeInOut)))
        .toList();

    Future.delayed(const Duration(milliseconds: 0),
            () => _startLoop(0));
    Future.delayed(const Duration(milliseconds: 180),
            () => _startLoop(1));
    Future.delayed(const Duration(milliseconds: 360),
            () => _startLoop(2));
  }

  void _startLoop(int i) {
    if (!mounted) return;
    _dotControllers[i].repeat(reverse: true);
  }

  @override
  void dispose() {
    for (final c in _dotControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            SvgPicture.asset(
              'assets/images/bb_logo.svg',
              width: 160,
              height: 186,
            ),

            const SizedBox(height: 32),

            // Animated dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                return AnimatedBuilder(
                  animation: _dotAnims[i],
                  builder: (_, __) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    child: Transform.translate(
                      offset: Offset(0, -8 * _dotAnims[i].value),
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _primary.withOpacity(
                              0.4 + 0.6 * _dotAnims[i].value),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),

            const SizedBox(height: 16),

            Text(
              'Memuatkan...',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: _primary.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}