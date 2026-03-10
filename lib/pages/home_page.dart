import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:belly_balance/providers/user_provider.dart';

class HomePage extends StatefulWidget {
  final VoidCallback onGoToNutrition;
  final VoidCallback onGoToHistory;

  const HomePage({
    super.key,
    required this.onGoToNutrition,
    required this.onGoToHistory,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  // ── Tokens ──────────────────────────────────────────────────
  static const _primary = Color(0xFF6BAE75);
  static const _primaryDark = Color(0xFF4A9860);
  static const _bg = Color(0xFFFBF7EE);
  static const _white = Colors.white;
  static const _textDark = Color(0xFF2D2D2D);
  static const _textMid = Color(0xFF7A7A7A);
  static const _textLight = Color(0xFFB8B8B8);

  // ── State ────────────────────────────────────────────────────
  int _todayCalories = 0;
  int _calorieTarget = 2200;
  int _todayMealCount = 0;
  bool _loadingLog = true;

  Stream<DocumentSnapshot>? _todayStream;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

  // ── Trimester tips ───────────────────────────────────────────
  static const Map<String, List<Map<String, String>>> _tips = {
    '1': [
      {'emoji': '🥦', 'tip': 'Makan banyak folat untuk perkembangan otak baby', 'detail': 'Sayur hijau, kekacang, buah sitrus'},
      {'emoji': '🥛', 'tip': 'Tingkatkan pengambilan kalsium setiap hari', 'detail': 'Susu, yogurt, keju, ikan bilis'},
      {'emoji': '💊', 'tip': 'Ambil suplemen asid folik setiap hari', 'detail': 'Sekurang-kurangnya 400mcg sehari'},
      {'emoji': '🚫', 'tip': 'Elakkan makanan mentah & tidak masak', 'detail': 'Sushi, telur separuh masak, daging rare'},
      {'emoji': '🍊', 'tip': 'Vitamin C bantu serap zat besi lebih baik', 'detail': 'Makan buah-buahan setiap hari'},
    ],
    '2': [
      {'emoji': '🥩', 'tip': 'Tingkatkan protein untuk pertumbuhan baby', 'detail': 'Ayam, ikan, telur, tauhu, tempe'},
      {'emoji': '🦴', 'tip': 'Kalsium penting untuk tulang baby yang kuat', 'detail': 'Target 1000mg kalsium sehari'},
      {'emoji': '🩸', 'tip': 'Zat besi mencegah anemia semasa hamil', 'detail': 'Daging merah, bayam, kekacang'},
      {'emoji': '💧', 'tip': 'Minum 8-10 gelas air sehari', 'detail': 'Elakkan minuman manis & berkafein'},
      {'emoji': '🐟', 'tip': 'Omega-3 dari ikan untuk otak baby', 'detail': 'Ikan salmon, sardin, tenggiri'},
    ],
    '3': [
      {'emoji': '🍽️', 'tip': 'Makan dalam kuantiti kecil tapi kerap', 'detail': '5-6 kali sehari lebih selesa'},
      {'emoji': '🌾', 'tip': 'Karbohidrat kompleks bagi tenaga berterusan', 'detail': 'Nasi perang, oat, roti wholemeal'},
      {'emoji': '🥦', 'tip': 'Fiber mencegah sembelit trimester akhir', 'detail': 'Sayur, buah, bijirin penuh'},
      {'emoji': '🦴', 'tip': 'Kalsium kritikal untuk tulang baby terakhir', 'detail': 'Jangan kurangkan susu & tenusu'},
      {'emoji': '⚡', 'tip': 'Kalori tambahan diperlukan pada trimester ini', 'detail': 'Target 2400 kcal sehari'},
    ],
  };

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));

    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    _initStream();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();

    super.dispose();
  }

  void _initStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _loadingLog = false);
      _fadeCtrl.forward();
      return;
    }
    final stream = FirebaseFirestore.instance
        .collection('nutrition_logs')
        .doc(uid)
        .collection('daily')
        .doc(today)
        .snapshots();

    setState(() => _todayStream = stream);

    stream.listen((doc) {
      if (!mounted) return;
      if (doc.exists && doc.data() != null) {
        final d = doc.data()!;
        setState(() {
          _todayCalories = (d['total_calories'] as num?)?.toInt() ?? 0;
          _calorieTarget = (d['calorie_target'] as num?)?.toInt() ?? 2200;
          _todayMealCount = (d['meal_count'] as num?)?.toInt() ?? 0;
          _loadingLog = false;
        });
      } else {
        setState(() {
          _todayCalories = 0;
          _calorieTarget = 2200;
          _todayMealCount = 0;
          _loadingLog = false;
        });
      }
      if (!_fadeCtrl.isCompleted) _fadeCtrl.forward();
    });
  }

  // ── Helpers ──────────────────────────────────────────────────


  String _greetingText() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Selamat Pagi';
    if (hour < 17) return 'Selamat Tengahari';
    return 'Selamat Petang';
  }



  List<Map<String, String>> _getTips(String tri) =>
      _tips[tri] ?? _tips['2']!;

  // ═══════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final tri = user.trimester.isNotEmpty ? user.trimester.replaceAll('Trimester ', '') : '2';
    final tips = _getTips(tri);

    return Scaffold(
      backgroundColor: _bg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeroCard(user, tri)),
            SliverToBoxAdapter(child: _buildCalorieCard()),
            SliverToBoxAdapter(child: _buildShortcuts()),
            SliverToBoxAdapter(child: _buildTipsSection(tips, tri)),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  // ── Hero Card ────────────────────────────────────────────────
  Widget _buildHeroCard(UserProvider user, String tri) {
    final name = user.username.isNotEmpty
        ? user.username.split(' ').first
        : 'Mama';

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 60, 20, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5BA365), Color(0xFF3A8A4E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
              color: _primary.withOpacity(0.4),
              blurRadius: 24,
              offset: const Offset(0, 10))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_greetingText(),
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.8))),
                    const SizedBox(height: 2),
                    Text(name,
                        style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5)),
                  ],
                ),
              ),
              // Trimester badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12)),
                child: Text('Trimester $tri',
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ],
          ),

        ],
      ),
    );
  }

  // ── Calorie Summary Card ─────────────────────────────────────
  Widget _buildCalorieCard() {
    final progress =
    (_todayCalories / _calorieTarget).clamp(0.0, 1.0);
    final remaining = _calorieTarget - _todayCalories;
    final isOver = remaining < 0;
    final pct = (progress * 100).toInt();

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('Kalori Hari Ini',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _textDark)),
            const Spacer(),
            if (_todayMealCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: _primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: Text('$_todayMealCount kali makan',
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _primary)),
              ),
          ]),

          const SizedBox(height: 16),

          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Circular progress
              SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 8,
                        backgroundColor:
                        _primary.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(
                            isOver
                                ? Colors.orange
                                : _primary),
                      ),
                    ),
                    Center(
                      child: Text('$pct%',
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isOver
                                  ? Colors.orange
                                  : _primary)),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 20),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                              text: '$_todayCalories',
                              style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  color: isOver
                                      ? Colors.orange
                                      : _textDark,
                                  letterSpacing: -1)),
                          const TextSpan(
                              text: ' kcal',
                              style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 14,
                                  color: _textMid)),
                        ],
                      ),
                    ),
                    Text(
                      isOver
                          ? '⚠️ ${(-remaining)} kcal melebihi target'
                          : _todayCalories == 0
                          ? 'Belum log makanan hari ini'
                          : '$remaining kcal lagi untuk target',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: isOver
                              ? Colors.orange
                              : _textMid),
                    ),
                    const SizedBox(height: 4),
                    Text('Target: $_calorieTarget kcal/hari',
                        style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            color: _textLight)),
                  ],
                ),
              ),
            ],
          ),

          if (_todayCalories == 0) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: _primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Text('💡', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Log makanan anda untuk pantau pemakanan hari ini',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11.5,
                        color: _primary),
                  ),
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  // ── Shortcuts ────────────────────────────────────────────────
  Widget _buildShortcuts() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: _shortcutCard(
              emoji: '🥗',
              title: 'Log Makanan',
              subtitle: 'Rekod pemakanan hari ini',
              gradient: const [Color(0xFF6BAE75), Color(0xFF4A9860)],
              onTap: widget.onGoToNutrition,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _shortcutCard(
              emoji: '📋',
              title: 'Rekod Lepas',
              subtitle: 'Lihat sejarah pemakanan',
              gradient: const [Color(0xFF5A9ED4), Color(0xFF3A7AB8)],
              onTap: widget.onGoToHistory,
            ),
          ),
        ],
      ),
    );
  }

  Widget _shortcutCard({
    required String emoji,
    required String title,
    required String subtitle,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: gradient[0].withOpacity(0.35),
                blurRadius: 14,
                offset: const Offset(0, 6))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 10),
            Text(title,
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10.5,
                    color: Colors.white.withOpacity(0.8))),
          ],
        ),
      ),
    );
  }

  // ── Tips Section ─────────────────────────────────────────────
  Widget _buildTipsSection(List<Map<String, String>> tips, String tri) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
          child: Row(children: [
            const Text('💡 Tips Pemakanan',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _textDark)),
            const SizedBox(width: 8),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: _primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Text('Trimester $tri',
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _primary)),
            ),
          ]),
        ),
        ...tips.map((tip) => _buildTipCard(tip)),
      ],
    );
  }

  Widget _buildTipCard(Map<String, String> tip) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: _primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12)),
            child: Center(
                child: Text(tip['emoji']!,
                    style: const TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tip['tip']!,
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _textDark)),
                const SizedBox(height: 3),
                Text(tip['detail']!,
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: _textMid)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}