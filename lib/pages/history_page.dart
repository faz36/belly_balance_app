import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// ═══════════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════════
class DailyLog {
  final String date;
  final int totalCalories;
  final int calorieTarget;
  final int mealCount;
  final Map<String, double> totalNutrients;
  final List<MealLog> meals;

  DailyLog({
    required this.date,
    required this.totalCalories,
    required this.calorieTarget,
    required this.mealCount,
    required this.totalNutrients,
    required this.meals,
  });

  factory DailyLog.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final mealsRaw =
    List<Map<String, dynamic>>.from(d['meals'] ?? []);
    return DailyLog(
      date: d['date'] ?? doc.id,
      totalCalories: (d['total_calories'] as num?)?.toInt() ?? 0,
      calorieTarget: (d['calorie_target'] as num?)?.toInt() ?? 2200,
      mealCount: (d['meal_count'] as num?)?.toInt() ?? mealsRaw.length,
      totalNutrients: Map<String, double>.from(
        (d['total_nutrients'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, (v as num).toDouble())),
      ),
      meals: mealsRaw.map(MealLog.fromMap).toList(),
    );
  }

  double get progress =>
      calorieTarget > 0 ? (totalCalories / calorieTarget).clamp(0.0, 1.0) : 0;

  bool get isOver => totalCalories > calorieTarget;

  DateTime get dateTime =>
      DateTime.tryParse(date) ?? DateTime.now();
}

class MealLog {
  final String id;
  final DateTime timestamp;
  final List<Map<String, dynamic>> foods;
  final int totalCalories;

  MealLog({
    required this.id,
    required this.timestamp,
    required this.foods,
    required this.totalCalories,
  });

  factory MealLog.fromMap(Map<String, dynamic> d) {
    return MealLog(
      id: d['id'] ?? '',
      timestamp: d['timestamp'] is String
          ? DateTime.tryParse(d['timestamp']) ?? DateTime.now()
          : DateTime.now(),
      foods: List<Map<String, dynamic>>.from(d['foods'] ?? []),
      totalCalories: (d['total_calories'] as num?)?.toInt() ?? 0,
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// HISTORY PAGE
// ═══════════════════════════════════════════════════════════════
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage>
    with TickerProviderStateMixin {
  // ── Tokens ──────────────────────────────────────────────────
  static const _primary = Color(0xFF6BAE75);
  static const _primaryDark = Color(0xFF4A9860);
  static const _bg = Color(0xFFFBF7EE);
  static const _white = Colors.white;
  static const _textDark = Color(0xFF2D2D2D);
  static const _textMid = Color(0xFF7A7A7A);
  static const _textLight = Color(0xFFB8B8B8);
  static const _soft = Color(0xFFE8F5EA);

  // ── State ────────────────────────────────────────────────────
  List<DailyLog> _logs = [];
  bool _loading = true;
  DailyLog? _selectedLog; // untuk detail view
  DateTime _focusedMonth = DateTime.now();

  late AnimationController _fadeCtrl;
  late AnimationController _detailCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _detailSlide;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _detailCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));

    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _detailSlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _detailCtrl, curve: Curves.easeOut));

    _loadLogs();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _detailCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final snap = await FirebaseFirestore.instance
          .collection('nutrition_logs')
          .doc(uid)
          .collection('daily')
          .orderBy('date', descending: true)
          .limit(60)
          .get();

      final logs =
      snap.docs.map(DailyLog.fromFirestore).toList();

      setState(() {
        _logs = logs;
        _loading = false;
        // Auto-select today if exists
        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        _selectedLog = logs.firstWhereOrNull((l) => l.date == today) ??
            (logs.isNotEmpty ? logs.first : null);
      });

      _fadeCtrl.forward();
      if (_selectedLog != null) _detailCtrl.forward();
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _selectLog(DailyLog log) {
    HapticFeedback.selectionClick();
    setState(() => _selectedLog = log);
    _detailCtrl.forward(from: 0);
  }

  // ── Helpers ──────────────────────────────────────────────────
  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));
      if (dateStr == DateFormat('yyyy-MM-dd').format(today))
        return 'Hari Ini';
      if (dateStr == DateFormat('yyyy-MM-dd').format(yesterday))
        return 'Semalam';
      return DateFormat('EEE, d MMM yyyy').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  String _formatDateShort(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('d MMM').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  String _formatTime(DateTime dt) => DateFormat('h:mm a').format(dt);

  Color _calorieColor(DailyLog log) {
    final pct = log.totalCalories / log.calorieTarget;
    if (pct < 0.6) return const Color(0xFF64B5F6); // kurang
    if (pct <= 1.0) return _primary; // okay
    return const Color(0xFFFFB74D); // lebih
  }

  String _calorieStatus(DailyLog log) {
    final pct = log.totalCalories / log.calorieTarget;
    if (pct < 0.6) return 'Kurang';
    if (pct <= 1.0) return 'Baik';
    return 'Lebih';
  }

  // Compute weekly average from logs
  Map<String, double> get _weeklyAvg {
    final week = _logs.take(7).toList();
    if (week.isEmpty) return {};
    final avg = <String, double>{};
    for (final log in week) {
      log.totalNutrients.forEach((k, v) {
        avg[k] = (avg[k] ?? 0) + v;
      });
    }
    avg.forEach((k, v) => avg[k] = v / week.length);
    return avg;
  }

  int get _weeklyAvgCal {
    final week = _logs.take(7).toList();
    if (week.isEmpty) return 0;
    return (week.fold<int>(0, (s, l) => s + l.totalCalories) /
        week.length)
        .round();
  }

  int get _streak {
    if (_logs.isEmpty) return 0;
    int count = 0;
    DateTime check = DateTime.now();
    for (final log in _logs) {
      final logDate = log.dateTime;
      final diff = check
          .difference(DateTime(logDate.year, logDate.month, logDate.day))
          .inDays;
      if (diff <= 1) {
        count++;
        check = logDate;
      } else {
        break;
      }
    }
    return count;
  }

  // ═══════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (_loading) return _buildLoading();

    return Scaffold(
      backgroundColor: _bg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: _logs.isEmpty ? _buildEmpty() : _buildMain(),
      ),
    );
  }

  Widget _buildLoading() {
    return const Scaffold(
      backgroundColor: _bg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: _primary, strokeWidth: 2.5),
            SizedBox(height: 14),
            Text('Memuatkan rekod...',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: _textMid)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _primary.withOpacity(0.1)),
                      child: const Center(
                          child: Text('📋',
                              style: TextStyle(fontSize: 44))),
                    ),
                    const SizedBox(height: 20),
                    const Text('Tiada Rekod Lagi',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: _textDark)),
                    const SizedBox(height: 8),
                    const Text(
                      'Mulakan log makanan anda\ndi halaman Pemakanan',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          color: _textMid),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMain() {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: SafeArea(child: _buildHeader())),
        SliverToBoxAdapter(child: _buildStatsRow()),
        SliverToBoxAdapter(child: _buildWeekStrip()),
        if (_selectedLog != null)
          SliverToBoxAdapter(child: _buildDetailCard()),
        SliverToBoxAdapter(child: _buildLogList()),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  // ── Header ───────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Rekod Pemakanan',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: _textDark,
                      letterSpacing: -0.5)),
              Text('${_logs.length} hari direkodkan',
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      color: _textMid)),
            ],
          ),
          const Spacer(),
          // Streak badge
          if (_streak > 0)
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFFFF9800), Color(0xFFFF5722)]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: Colors.orange.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ],
              ),
              child: Row(
                children: [
                  const Text('🔥',
                      style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 5),
                  Text('$_streak hari',
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _white)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Stats Row ────────────────────────────────────────────────
  Widget _buildStatsRow() {
    final avgCal = _weeklyAvgCal;
    final totalDays = _logs.length;
    final goodDays =
        _logs.where((l) => !l.isOver && l.totalCalories > 0).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: [
          _statCard('📅', 'Jumlah Hari', '$totalDays hari',
              const Color(0xFF5A9ED4)),
          const SizedBox(width: 10),
          _statCard('🔥', 'Purata/Hari', '$avgCal kcal', _primary),
          const SizedBox(width: 10),
          _statCard('✅', 'Hari Baik', '$goodDays hari',
              const Color(0xFF5AB87A)),
        ],
      ),
    );
  }

  Widget _statCard(
      String emoji, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 3))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: color)),
            Text(label,
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10,
                    color: _textMid)),
          ],
        ),
      ),
    );
  }

  // ── Week Strip (7 hari terakhir) ─────────────────────────────
  Widget _buildWeekStrip() {
    final recent = _logs.take(7).toList().reversed.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Text('7 Hari Terakhir',
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _textDark)),
        ),
        SizedBox(
          height: 90,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: recent.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final log = recent[i];
              final isSelected = _selectedLog?.date == log.date;
              final color = _calorieColor(log);
              return GestureDetector(
                onTap: () => _selectLog(log),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 62,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? color : _white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? color
                          : Colors.transparent,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                          color: isSelected
                              ? color.withOpacity(0.3)
                              : Colors.black.withOpacity(0.05),
                          blurRadius: isSelected ? 12 : 6,
                          offset: const Offset(0, 3))
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _dayLabel(log.date),
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? _white.withOpacity(0.85)
                                : _textMid),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _dateNum(log.date),
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? _white : _textDark),
                      ),
                      const SizedBox(height: 4),
                      // Mini bar
                      Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                            color: isSelected
                                ? _white.withOpacity(0.3)
                                : color.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(2)),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: log.progress,
                          child: Container(
                            decoration: BoxDecoration(
                                color: isSelected ? _white : color,
                                borderRadius: BorderRadius.circular(2)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _dayLabel(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      final today = DateTime.now();
      if (dateStr == DateFormat('yyyy-MM-dd').format(today)) return 'Hari ini';
      return DateFormat('EEE').format(dt);
    } catch (_) {
      return '';
    }
  }

  String _dateNum(String dateStr) {
    try {
      return DateFormat('d').format(DateTime.parse(dateStr));
    } catch (_) {
      return '';
    }
  }

  // ── Detail Card ──────────────────────────────────────────────
  Widget _buildDetailCard() {
    final log = _selectedLog!;
    final color = _calorieColor(log);
    final status = _calorieStatus(log);

    return SlideTransition(
      position: _detailSlide,
      child: FadeTransition(
        opacity: _detailCtrl,
        child: Container(
          margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withOpacity(0.75)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                  color: color.withOpacity(0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8))
            ],
          ),
          child: Column(
            children: [
              // Top section
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date + status
                    Row(
                      children: [
                        Text(_formatDate(log.date),
                            style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12)),
                          child: Text(status,
                              style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white)),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Calories
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${log.totalCalories}',
                                style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 48,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    height: 1.0,
                                    letterSpacing: -2)),
                            Text('/ ${log.calorieTarget} kcal',
                                style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 13,
                                    color:
                                    Colors.white.withOpacity(0.75))),
                          ],
                        ),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${log.mealCount}',
                                style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white)),
                            Text('kali makan',
                                style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 11,
                                    color: Colors.white
                                        .withOpacity(0.75))),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Progress bar
                    Stack(children: [
                      Container(
                          height: 8,
                          decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4))),
                      FractionallySizedBox(
                        widthFactor: log.progress,
                        child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: [
                                  BoxShadow(
                                      color:
                                      Colors.white.withOpacity(0.5),
                                      blurRadius: 6)
                                ])),
                      ),
                    ]),

                    const SizedBox(height: 16),

                    // Macros
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(14)),
                      child: Row(children: [
                        _detailMacro('💪', 'Protein',
                            '${(log.totalNutrients['protein'] ?? 0).toStringAsFixed(1)}g'),
                        _dDiv(),
                        _detailMacro('🌾', 'Karbo',
                            '${(log.totalNutrients['carbs'] ?? 0).toStringAsFixed(1)}g'),
                        _dDiv(),
                        _detailMacro('🫒', 'Lemak',
                            '${(log.totalNutrients['fat'] ?? 0).toStringAsFixed(1)}g'),
                        _dDiv(),
                        _detailMacro('🌿', 'Fiber',
                            '${(log.totalNutrients['fiber'] ?? 0).toStringAsFixed(1)}g'),
                      ]),
                    ),

                    const SizedBox(height: 10),

                    // Pregnancy nutrients
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(14)),
                      child: Row(children: [
                        _pregDetail('🦴', 'Kalsium',
                            log.totalNutrients['calcium'] ?? 0,
                            1000, 'mg'),
                        _dDiv(),
                        _pregDetail('🩸', 'Zat Besi',
                            log.totalNutrients['iron'] ?? 0, 27, 'mg'),
                        _dDiv(),
                        _pregDetail('🧬', 'Folat',
                            log.totalNutrients['folate'] ?? 0,
                            600, 'mcg'),
                      ]),
                    ),
                  ],
                ),
              ),

              // Meals list dalam detail card
              if (log.meals.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Divider(
                          color: Colors.white.withOpacity(0.2),
                          height: 20),
                      Text('Senarai Makan',
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withOpacity(0.85))),
                      const SizedBox(height: 10),
                      ...log.meals.map((meal) =>
                          _buildMealRow(meal)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMealRow(MealLog meal) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time + calories
          Row(children: [
            Text(_formatTime(meal.timestamp),
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withOpacity(0.9))),
            const Spacer(),
            Text('🔥 ${meal.totalCalories} kcal',
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
          ]),
          const SizedBox(height: 8),
          // Food chips
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: meal.foods.map((f) {
              final qty = (f['quantity'] as int?) ?? 1;
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(8)),
                child: Text(
                  qty > 1
                      ? '${f['emoji']} ${f['name']} x$qty'
                      : '${f['emoji']} ${f['name']}',
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      color: Colors.white),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _detailMacro(String emoji, String label, String val) =>
      Expanded(
        child: Column(children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 3),
          Text(val,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
          Text(label,
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 9,
                  color: Colors.white.withOpacity(0.7))),
        ]),
      );

  Widget _pregDetail(
      String emoji, String label, double val, int target, String unit) {
    final pct = (val / target).clamp(0.0, 1.0);
    final done = val >= target;
    return Expanded(
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 3),
          Text(
            val < 10
                ? '${val.toStringAsFixed(1)}$unit'
                : '${val.toStringAsFixed(0)}$unit',
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: done ? Colors.greenAccent : Colors.white),
          ),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: Colors.white.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(
                done ? Colors.greenAccent : Colors.white),
            minHeight: 4,
          ),
        ),
        const SizedBox(height: 3),
        Text('$label/$target$unit',
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 9,
                color: Colors.white.withOpacity(0.65))),
      ]),
    );
  }

  Widget _dDiv() =>
      Container(width: 1, height: 30, color: Colors.white.withOpacity(0.2));

  // ── Full Log List ────────────────────────────────────────────
  Widget _buildLogList() {
    if (_logs.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Text('Semua Rekod',
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _textDark)),
        ),
        ..._logs.map((log) => _buildLogTile(log)),
      ],
    );
  }

  Widget _buildLogTile(DailyLog log) {
    final isSelected = _selectedLog?.date == log.date;
    final color = _calorieColor(log);
    final status = _calorieStatus(log);

    return GestureDetector(
      onTap: () => _selectLog(log),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.08) : _white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: isSelected ? color.withOpacity(0.35) : Colors.transparent,
              width: 1.5),
          boxShadow: [
            BoxShadow(
                color: isSelected
                    ? color.withOpacity(0.12)
                    : Colors.black.withOpacity(0.04),
                blurRadius: isSelected ? 12 : 6,
                offset: const Offset(0, 3))
          ],
        ),
        child: Row(
          children: [
            // Date box
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isSelected ? color : color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _dateNum(log.date),
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isSelected ? _white : color),
                  ),
                  Text(
                    _monthShort(log.date),
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 9,
                        color: isSelected
                            ? _white.withOpacity(0.8)
                            : color.withOpacity(0.8)),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_formatDate(log.date),
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? color : _textDark)),
                  const SizedBox(height: 3),
                  Text('${log.mealCount} kali makan',
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          color: _textMid)),
                  const SizedBox(height: 6),
                  // Mini progress bar
                  Stack(children: [
                    Container(
                        height: 4,
                        decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(2))),
                    FractionallySizedBox(
                      widthFactor: log.progress,
                      child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(2))),
                    ),
                  ]),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Calories + status
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${log.totalCalories}',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: color)),
                Text('kcal',
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        color: _textMid)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(status,
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: color)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _monthShort(String dateStr) {
    try {
      return DateFormat('MMM').format(DateTime.parse(dateStr));
    } catch (_) {
      return '';
    }
  }
}

// ── Extension ────────────────────────────────────────────────
extension ListExt<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}