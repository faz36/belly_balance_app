import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:belly_balance/providers/user_provider.dart';

// ═══════════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════════
class FoodItem {
  final String id;
  final String name;
  final String category;
  final int caloriesPerServing;
  final String servingSize;
  final String emoji;
  final List<String> trimesterSuitable;
  final Map<String, double> nutrients;
  final String notes;
  final bool isCustom;

  FoodItem({
    required this.id,
    required this.name,
    required this.category,
    required this.caloriesPerServing,
    required this.servingSize,
    required this.emoji,
    required this.trimesterSuitable,
    required this.nutrients,
    this.notes = '',
    this.isCustom = false,
  });

  factory FoodItem.fromFirestore(DocumentSnapshot doc, {bool isCustom = false}) {
    final d = doc.data() as Map<String, dynamic>;
    return FoodItem(
      id: doc.id,
      name: d['name'] ?? '',
      category: d['category'] ?? '',
      caloriesPerServing: (d['calories_per_serving'] as num?)?.toInt() ?? 0,
      servingSize: d['serving_size'] ?? '',
      emoji: d['emoji'] ?? '🍽️',
      trimesterSuitable:
      List<String>.from(d['trimester_suitable'] ?? ['1', '2', '3']),
      nutrients: Map<String, double>.from(
        (d['nutrients'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, (v as num).toDouble())),
      ),
      notes: d['notes'] ?? '',
      isCustom: isCustom,
    );
  }
}

// Satu hidangan yang disimpan
class MealEntry {
  final String id;
  final DateTime timestamp;
  final List<Map<String, dynamic>> foods;
  final int totalCalories;
  final Map<String, double> totalNutrients;

  MealEntry({
    required this.id,
    required this.timestamp,
    required this.foods,
    required this.totalCalories,
    required this.totalNutrients,
  });

  factory MealEntry.fromMap(Map<String, dynamic> d) {
    return MealEntry(
      id: d['id'] ?? '',
      timestamp: d['timestamp'] is Timestamp
          ? (d['timestamp'] as Timestamp).toDate()
          : DateTime.tryParse(d['timestamp'] ?? '') ?? DateTime.now(),
      foods: List<Map<String, dynamic>>.from(d['foods'] ?? []),
      totalCalories: (d['total_calories'] as num?)?.toInt() ?? 0,
      totalNutrients: Map<String, double>.from(
        (d['total_nutrients'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, (v as num).toDouble())),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// NUTRITION PAGE
// ═══════════════════════════════════════════════════════════════
class NutritionPage extends StatefulWidget {
  final void Function(List<Map<String, dynamic>> foods, int calories)
  onDataUpdated;

  const NutritionPage({super.key, required this.onDataUpdated});

  @override
  State<NutritionPage> createState() => _NutritionPageState();
}

class _NutritionPageState extends State<NutritionPage>
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
  List<FoodItem> _allFoods = [];
  bool _loadingFoods = true;
  bool _isSaving = false;

  // Pilihan semasa (akan reset selepas save)
  final Map<String, int> _selected = {};

  // Hidangan yang dah disimpan hari ni
  List<MealEntry> _todayMeals = [];

  // Daily totals
  int _dailyCalories = 0;
  Map<String, double> _dailyNutrients = {};
  int _calorieTarget = 2200;

  // Search & filter untuk food picker
  String _searchQuery = '';
  String _selectedCategory = 'Semua';
  final _searchCtrl = TextEditingController();

  // Animations
  late AnimationController _fadeCtrl;
  late AnimationController _saveSuccessCtrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _saveSuccessAnim;

  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

  // ── Category metadata ────────────────────────────────────────
  static const Map<String, Map<String, dynamic>> _catMeta = {
    'Semua': {'emoji': '🍽️', 'color': Color(0xFF6BAE75)},
    'Nasi & Bijirin': {'emoji': '🌾', 'color': Color(0xFFE8A838)},
    'Bubur & Sup': {'emoji': '🥣', 'color': Color(0xFFE07B5A)},
    'Roti & Bijirin': {'emoji': '🍞', 'color': Color(0xFFD4A25A)},
    'Mee & Pasta': {'emoji': '🍜', 'color': Color(0xFFE8C542)},
    'Lauk-pauk': {'emoji': '🍛', 'color': Color(0xFFE86B42)},
    'Daging & Protein': {'emoji': '🥩', 'color': Color(0xFFD45A5A)},
    'Ikan & Seafood': {'emoji': '🐟', 'color': Color(0xFF5A9ED4)},
    'Telur': {'emoji': '🥚', 'color': Color(0xFFE8C542)},
    'Tauhu & Tempe': {'emoji': '🟡', 'color': Color(0xFFD4A25A)},
    'Sayur-sayuran': {'emoji': '🥦', 'color': Color(0xFF5AB87A)},
    'Buah-buahan': {'emoji': '🍎', 'color': Color(0xFFE85A7A)},
    'Tenusu & Susu': {'emoji': '🥛', 'color': Color(0xFF8ABBE8)},
    'Kacang-kacangan': {'emoji': '🌰', 'color': Color(0xFFB87A42)},
    'Ubi-ubian': {'emoji': '🍠', 'color': Color(0xFFE8924A)},
    'Minuman': {'emoji': '🥤', 'color': Color(0xFF5AC8E8)},
    'Fast Food Malaysia': {'emoji': '🍔', 'color': Color(0xFFE84242)},
    'Sarapan': {'emoji': '☀️', 'color': Color(0xFFE8B842)},
    'Snek': {'emoji': '🍿', 'color': Color(0xFFD4725A)},
    'Dessert & Kuih': {'emoji': '🍰', 'color': Color(0xFFE87AB8)},
    'Minuman & Pencuci Mulut': {'emoji': '🧋', 'color': Color(0xFF9A7AE8)},
    'Lain-lain': {'emoji': '✨', 'color': Color(0xFF8A8A8A)},
  };

  // ────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _saveSuccessCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _saveSuccessAnim =
        CurvedAnimation(parent: _saveSuccessCtrl, curve: Curves.elasticOut);
    _initData();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _saveSuccessCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    await _loadFoods();
    await _loadTodayMeals();
    _setTarget();
    _fadeCtrl.forward();
  }

  void _setTarget() {
    final tri = context.read<UserProvider>().trimester;
    setState(() {
      if (tri.contains('1'))
        _calorieTarget = 1800;
      else if (tri.contains('2'))
        _calorieTarget = 2200;
      else
        _calorieTarget = 2400;
    });
  }

  Future<void> _loadFoods() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final snap =
      await FirebaseFirestore.instance.collection('foods').get();
      final foods = snap.docs.map((d) => FoodItem.fromFirestore(d)).toList();

      // Load custom foods milik user
      if (uid != null) {
        final customSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('custom_foods')
            .get();
        final customFoods = customSnap.docs
            .map((d) => FoodItem.fromFirestore(d, isCustom: true))
            .toList();
        foods.addAll(customFoods);
      }

      foods.sort((a, b) => a.name.compareTo(b.name));
      setState(() {
        _allFoods = foods;
        _loadingFoods = false;
      });
    } catch (_) {
      setState(() => _loadingFoods = false);
    }
  }

  Future<void> _loadTodayMeals() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('nutrition_logs')
          .doc(uid)
          .collection('daily')
          .doc(today)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final meals = List<Map<String, dynamic>>.from(data['meals'] ?? []);
        setState(() {
          _todayMeals = meals.map(MealEntry.fromMap).toList();
          _recalcDaily();
        });
      }
    } catch (_) {}
  }

  void _recalcDaily() {
    int cal = 0;
    final Map<String, double> nutrients = {};
    for (final meal in _todayMeals) {
      cal += meal.totalCalories;
      meal.totalNutrients.forEach((k, v) {
        nutrients[k] = (nutrients[k] ?? 0) + v;
      });
    }
    _dailyCalories = cal;
    _dailyNutrients = nutrients;

    // Notify parent
    final allFoods = _todayMeals
        .expand((m) => m.foods)
        .map((f) => {
      'name': f['name'],
      'calories': f['calories'],
      'emoji': f['emoji'],
    })
        .toList();
    widget.onDataUpdated(allFoods, cal);
  }

  // ── Save hidangan ────────────────────────────────────────────
  Future<void> _saveMeal() async {
    if (_selected.isEmpty) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      // Build meal entry
      final foods = _selected.entries.map((e) {
        final food = _allFoods.firstWhere((f) => f.id == e.key);
        final qty = e.value;
        return {
          'food_id': food.id,
          'name': food.name,
          'emoji': food.emoji,
          'category': food.category,
          'calories': food.caloriesPerServing * qty,
          'quantity': qty,
          'serving_size': food.servingSize,
        };
      }).toList();

      final totalCal =
      foods.fold<int>(0, (s, f) => s + (f['calories'] as int));

      // Nutrients
      final Map<String, double> totalNutrients = {};
      for (final e in _selected.entries) {
        final food = _allFoods.firstWhere((f) => f.id == e.key);
        final qty = e.value;
        food.nutrients.forEach((k, v) {
          totalNutrients[k] = (totalNutrients[k] ?? 0) + v * qty;
        });
      }

      final mealId =
      DateTime.now().millisecondsSinceEpoch.toString();
      final entry = MealEntry(
        id: mealId,
        timestamp: DateTime.now(),
        foods: foods,
        totalCalories: totalCal,
        totalNutrients: totalNutrients,
      );

      // Add to local list
      setState(() {
        _todayMeals.add(entry);
        _recalcDaily();
      });

      // Save to Firestore
      final docRef = FirebaseFirestore.instance
          .collection('nutrition_logs')
          .doc(uid)
          .collection('daily')
          .doc(today);

      final mealsData = _todayMeals
          .map((m) => {
        'id': m.id,
        'timestamp': m.timestamp.toIso8601String(),
        'foods': m.foods,
        'total_calories': m.totalCalories,
        'total_nutrients': m.totalNutrients,
      })
          .toList();

      await docRef.set({
        'date': today,
        'meals': mealsData,
        'total_calories': _dailyCalories,
        'total_nutrients': _dailyNutrients,
        'calorie_target': _calorieTarget,
        'meal_count': _todayMeals.length,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // ✅ Reset selection
      setState(() {
        _selected.clear();
        _searchQuery = '';
        _selectedCategory = 'Semua';
        _searchCtrl.clear();
        _isSaving = false;
      });

      // Success animation
      _saveSuccessCtrl.forward(from: 0);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Text('✅ ', style: TextStyle(fontSize: 16)),
                Text('Hidangan disimpan! +$totalCal kcal',
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ],
            ),
            backgroundColor: _primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ralat: $e'),
            backgroundColor: Colors.red[400],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ── Delete meal ──────────────────────────────────────────────
  Future<void> _deleteMeal(String mealId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    HapticFeedback.mediumImpact();

    setState(() {
      _todayMeals.removeWhere((m) => m.id == mealId);
      _recalcDaily();
    });

    final mealsData = _todayMeals
        .map((m) => {
      'id': m.id,
      'timestamp': m.timestamp.toIso8601String(),
      'foods': m.foods,
      'total_calories': m.totalCalories,
      'total_nutrients': m.totalNutrients,
    })
        .toList();

    await FirebaseFirestore.instance
        .collection('nutrition_logs')
        .doc(uid)
        .collection('daily')
        .doc(today)
        .set({
      'date': today,
      'meals': mealsData,
      'total_calories': _dailyCalories,
      'total_nutrients': _dailyNutrients,
      'calorie_target': _calorieTarget,
      'meal_count': _todayMeals.length,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Computed ─────────────────────────────────────────────────
  int get _selectedCalories => _selected.entries.fold(0, (s, e) {
    final food = _allFoods.firstWhereOrNull((f) => f.id == e.key);
    return s + (food?.caloriesPerServing ?? 0) * e.value;
  });

  List<String> get _categories {
    final cats = _allFoods.map((f) => f.category).toSet().toList()..sort();
    return ['Semua', ...cats];
  }

  List<FoodItem> get _filtered => _allFoods.where((f) {
    final q = _searchQuery.toLowerCase();
    final matchQ = q.isEmpty ||
        f.name.toLowerCase().contains(q) ||
        f.category.toLowerCase().contains(q);
    final matchCat =
        _selectedCategory == 'Semua' || f.category == _selectedCategory;
    return matchQ && matchCat;
  }).toList();

  Color _catColor(String cat) =>
      (_catMeta[cat]?['color'] as Color?) ?? _primary;

  String _catEmoji(String cat) =>
      (_catMeta[cat]?['emoji'] as String?) ?? '🍽️';

  String _timeLabel(DateTime dt) => DateFormat('h:mm a').format(dt);

  // ═══════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (_loadingFoods) return _buildLoading();
    return FadeTransition(
      opacity: _fadeAnim,
      child: Scaffold(
        backgroundColor: _bg,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildAppBar(),
            SliverToBoxAdapter(child: _buildDailySummary()),
            SliverToBoxAdapter(child: _buildTodayMeals()),
            SliverToBoxAdapter(child: _buildFoodPickerSection()),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
        // ── Floating Save Button ──
        floatingActionButton: _selected.isNotEmpty
            ? _buildSaveFAB()
            : null,
        floatingActionButtonLocation:
        FloatingActionButtonLocation.endFloat,
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
            Text('Memuatkan makanan...',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: _textMid)),
          ],
        ),
      ),
    );
  }

  // ── App Bar ──────────────────────────────────────────────────
  Widget _buildAppBar() {
    return SliverAppBar(
      floating: true,
      snap: true,
      backgroundColor: _bg,
      elevation: 0,
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pemakanan',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: _textDark,
                        letterSpacing: -0.5)),
                Text(
                  DateFormat('EEEE, d MMM yyyy').format(DateTime.now()),
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      color: _textMid),
                ),
              ],
            ),
            const Spacer(),
            // Meal count badge
            if (_todayMeals.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${_todayMeals.length} hidangan',
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _primary)),
              ),
          ],
        ),
      ),
    );
  }

  // ── Daily Summary Card ───────────────────────────────────────
  Widget _buildDailySummary() {
    final progress = (_dailyCalories / _calorieTarget).clamp(0.0, 1.0);
    final remaining = _calorieTarget - _dailyCalories;
    final isOver = remaining < 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5BA365), Color(0xFF3E8A4F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: _primary.withOpacity(0.35),
              blurRadius: 20,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Target chip
          Row(
            children: [
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20)),
                child: Text('🎯  Target $_calorieTarget kcal/hari',
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w500)),
              ),
              const Spacer(),
              Text('${_todayMeals.length} hidangan',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.75))),
            ],
          ),

          const SizedBox(height: 16),

          // Main calorie display
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$_dailyCalories',
                        style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 52,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.0,
                            letterSpacing: -2)),
                    Text('kalori hari ini',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.75))),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                    color: isOver
                        ? Colors.orange.withOpacity(0.25)
                        : Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: [
                    Text(isOver ? '⚠️' : '📉',
                        style: const TextStyle(fontSize: 22)),
                    const SizedBox(height: 2),
                    Text('${remaining.abs()}',
                        style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                    Text(isOver ? 'kcal lebih' : 'kcal lagi',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 9,
                            color: Colors.white.withOpacity(0.8))),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Progress bar
          Stack(
            children: [
              Container(
                height: 10,
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(10)),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOut,
                height: 10,
                width: (MediaQuery.of(context).size.width - 84) * progress,
                decoration: BoxDecoration(
                    color: isOver ? Colors.orange : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.white.withOpacity(0.4),
                          blurRadius: 6)
                    ]),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Macros
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                _macroCol('💪', 'Protein',
                    '${(_dailyNutrients['protein'] ?? 0).toStringAsFixed(1)}g'),
                _div(),
                _macroCol('🌾', 'Karbo',
                    '${(_dailyNutrients['carbs'] ?? 0).toStringAsFixed(1)}g'),
                _div(),
                _macroCol('🫒', 'Lemak',
                    '${(_dailyNutrients['fat'] ?? 0).toStringAsFixed(1)}g'),
                _div(),
                _macroCol('🌿', 'Fiber',
                    '${(_dailyNutrients['fiber'] ?? 0).toStringAsFixed(1)}g'),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Pregnancy nutrients
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                _pregNutrient('🦴', 'Kalsium',
                    _dailyNutrients['calcium'] ?? 0, 1000, 'mg'),
                _div(),
                _pregNutrient('🩸', 'Zat Besi',
                    _dailyNutrients['iron'] ?? 0, 27, 'mg'),
                _div(),
                _pregNutrient('🧬', 'Folat',
                    _dailyNutrients['folate'] ?? 0, 600, 'mcg'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _macroCol(String emoji, String label, String val) => Expanded(
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

  Widget _pregNutrient(
      String emoji, String label, double val, int target, String unit) {
    final pct = (val / target).clamp(0.0, 1.0);
    final done = val >= target;
    return Expanded(
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
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

  Widget _div() =>
      Container(width: 1, height: 32, color: Colors.white.withOpacity(0.2));

  // ── Today's Meals List ───────────────────────────────────────
  Widget _buildTodayMeals() {
    if (_todayMeals.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Row(
            children: [
              const Text('Hidangan Hari Ini',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _textDark)),
              const Spacer(),
              Text('${_todayMeals.length} hidangan',
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: _textMid)),
            ],
          ),
        ),
        ...List.generate(_todayMeals.length, (i) {
          final meal = _todayMeals[i];
          return _buildMealCard(meal, i + 1);
        }),
      ],
    );
  }

  Widget _buildMealCard(MealEntry meal, int index) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [_primary, _primaryDark]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text('$index',
                        style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _white)),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_timeLabel(meal.timestamp),
                        style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _textDark)),
                    Text('${meal.foods.length} jenis makanan',
                        style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            color: _textMid)),
                  ],
                ),
                const Spacer(),
                // Calorie badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: _primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10)),
                  child: Text('🔥 ${meal.totalCalories} kcal',
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _primary)),
                ),
                const SizedBox(width: 8),
                // Delete
                GestureDetector(
                  onTap: () => _confirmDeleteMeal(meal),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.delete_outline_rounded,
                        size: 16, color: Colors.red),
                  ),
                ),
              ],
            ),
          ),

          // Divider
          Divider(
              color: Colors.grey.withOpacity(0.1),
              height: 0,
              thickness: 1),

          // Foods list
          Padding(
            padding: const EdgeInsets.all(14),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: meal.foods.map((f) {
                final qty = f['quantity'] as int? ?? 1;
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                      color: _bg,
                      borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(f['emoji'] as String? ?? '🍽️',
                          style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text(
                        qty > 1
                            ? '${f['name']} x$qty'
                            : '${f['name']}',
                        style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: _textDark),
                      ),
                      const SizedBox(width: 4),
                      Text('${f['calories']} kcal',
                          style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 10,
                              color: _textMid)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteMeal(MealEntry meal) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _white,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Padam Hidangan?',
            style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
                color: _textDark)),
        content: Text(
            'Hidangan ini (${meal.totalCalories} kcal) akan dipadam.',
            style: const TextStyle(
                fontFamily: 'Poppins', fontSize: 13, color: _textMid)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal',
                style: TextStyle(
                    fontFamily: 'Poppins', color: _textMid)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteMeal(meal.id);
            },
            child: const Text('Padam',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.red,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ── Food Picker Section ──────────────────────────────────────
  Widget _buildFoodPickerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
          child: Row(
            children: [
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: _selected.isEmpty
                        ? _primary.withOpacity(0.1)
                        : _primary,
                    borderRadius: BorderRadius.circular(20)),
                child: Row(
                  children: [
                    Text(_selected.isEmpty ? '🍽️' : '✅',
                        style: const TextStyle(fontSize: 13)),
                    const SizedBox(width: 6),
                    Text(
                      _selected.isEmpty
                          ? 'Pilih Makanan'
                          : '${_selected.length} dipilih · $_selectedCalories kcal',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _selected.isEmpty ? _primary : _white),
                    ),
                  ],
                ),
              ),
              if (_selected.isNotEmpty) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _selected.clear()),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20)),
                    child: const Text('Reset',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.red)),
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Tambah Makanan Sendiri button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GestureDetector(
            onTap: _showAddCustomFoodSheet,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF7B61FF).withOpacity(0.07),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF7B61FF).withOpacity(0.25),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFF7B61FF).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.add_rounded,
                        size: 16, color: Color(0xFF7B61FF)),
                  ),
                  const SizedBox(width: 10),
                  const Text('Tambah Makanan Sendiri',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF7B61FF))),
                  const SizedBox(width: 6),
                  const Text('✏️', style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 14),

        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _buildSearchBar(),
        ),

        const SizedBox(height: 12),

        // Category chips
        _buildCategoryChips(),

        const SizedBox(height: 14),

        // Food grid
        _buildFoodGrid(),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 3))
        ],
      ),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _searchQuery = v),
        style: const TextStyle(
            fontFamily: 'Poppins', fontSize: 13.5, color: _textDark),
        decoration: InputDecoration(
          prefixIcon:
          const Icon(Icons.search_rounded, color: _primary, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.close_rounded,
                size: 16, color: _textLight),
            onPressed: () {
              _searchCtrl.clear();
              setState(() => _searchQuery = '');
            },
          )
              : null,
          hintText: 'Cari makanan...',
          hintStyle: const TextStyle(
              fontFamily: 'Poppins', color: _textLight, fontSize: 13.5),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none),
          filled: true,
          fillColor: _white,
          contentPadding:
          const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final cat = _categories[i];
          final selected = cat == _selectedCategory;
          final color = _catColor(cat);
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedCategory = cat);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? color : _white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: selected
                          ? color.withOpacity(0.3)
                          : Colors.black.withOpacity(0.04),
                      blurRadius: selected ? 8 : 4,
                      offset: const Offset(0, 2))
                ],
              ),
              child: Row(
                children: [
                  Text(_catEmoji(cat),
                      style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 5),
                  Text(cat,
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: selected ? _white : _textMid)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFoodGrid() {
    final foods = _filtered;
    if (foods.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 40),
        child: Center(
          child: Column(
            children: [
              Text('🔍', style: TextStyle(fontSize: 40)),
              SizedBox(height: 8),
              Text('Tiada makanan dijumpai',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      color: _textMid)),
            ],
          ),
        ),
      );
    }

    // Group by category
    final grouped = <String, List<FoodItem>>{};
    for (final f in foods) {
      grouped.putIfAbsent(f.category, () => []).add(f);
    }
    final keys = grouped.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: keys.map((cat) {
        final items = grouped[cat]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                        color: _catColor(cat).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(_catEmoji(cat),
                        style: const TextStyle(fontSize: 14)),
                  ),
                  const SizedBox(width: 8),
                  Text(cat,
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _catColor(cat))),
                  const Spacer(),
                  Text('${items.length} item',
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          color: _textLight)),
                ],
              ),
            ),
            // Food tiles
            ...items.map((food) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: _buildFoodTile(food),
            )),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildFoodTile(FoodItem food) {
    final isSelected = _selected.containsKey(food.id);
    final qty = _selected[food.id] ?? 1;
    final catColor = _catColor(food.category);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          if (isSelected) {
            _selected.remove(food.id);
          } else {
            _selected[food.id] = 1;
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: isSelected ? catColor.withOpacity(0.07) : _white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isSelected
                  ? catColor.withOpacity(0.35)
                  : Colors.transparent,
              width: 1.5),
          boxShadow: [
            BoxShadow(
                color: isSelected
                    ? catColor.withOpacity(0.1)
                    : Colors.black.withOpacity(0.04),
                blurRadius: isSelected ? 12 : 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            // Emoji
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  color:
                  isSelected ? catColor.withOpacity(0.14) : _bg,
                  borderRadius: BorderRadius.circular(13)),
              child: Center(
                  child: Text(food.emoji,
                      style: const TextStyle(fontSize: 24))),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(food.name,
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? catColor : _textDark)),
                      ),
                      if (food.isCustom) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7B61FF).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('Saya',
                              style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF7B61FF))),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(food.servingSize,
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          color: _textMid)),
                  const SizedBox(height: 6),
                  Row(children: [
                    _pill(
                        '🔥 ${food.caloriesPerServing * (isSelected ? qty : 1)} kcal',
                        isSelected ? catColor : _textLight,
                        isSelected
                            ? catColor.withOpacity(0.1)
                            : _bg),
                    const SizedBox(width: 5),
                    _pill(
                        'P ${food.nutrients['protein']?.toStringAsFixed(1)}g',
                        const Color(0xFF5A9ED4),
                        const Color(0xFF5A9ED4).withOpacity(0.1)),
                  ]),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Check + qty + info + edit/delete for custom
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Info button — semua makanan
                GestureDetector(
                  onTap: () => _showFoodDetail(food),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _bg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 11, color: _textMid),
                        const SizedBox(width: 3),
                        Text('Info',
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: _textMid)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isSelected
                        ? LinearGradient(
                        colors: [catColor, catColor.withOpacity(0.7)])
                        : null,
                    color: isSelected ? null : Colors.grey.shade100,
                    boxShadow: isSelected
                        ? [
                      BoxShadow(
                          color: catColor.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 3))
                    ]
                        : null,
                  ),
                  child: Icon(
                    isSelected
                        ? Icons.check_rounded
                        : Icons.add_rounded,
                    size: 16,
                    color: isSelected
                        ? _white
                        : Colors.grey.shade400,
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    _qtyBtn(Icons.remove_rounded, qty > 1, () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        final cur = _selected[food.id]!;
                        _selected[food.id] = (cur - 1).clamp(1, 10);
                      });
                    }),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 7),
                      child: Text('$qty',
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: catColor)),
                    ),
                    _qtyBtn(Icons.add_rounded, qty < 10, () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        final cur = _selected[food.id]!;
                        _selected[food.id] = (cur + 1).clamp(1, 10);
                      });
                    }),
                  ]),
                ],
                if (food.isCustom) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () => _showEditCustomFoodSheet(food),
                        child: Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: const Color(0xFF7B61FF).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.edit_outlined,
                              size: 14, color: Color(0xFF7B61FF)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () async {
                          HapticFeedback.mediumImpact();
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              backgroundColor: _white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20)),
                              title: const Text('Padam Makanan?',
                                  style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontWeight: FontWeight.w700,
                                      color: _textDark)),
                              content: Text(
                                  'Padam "${food.name}" daripada senarai?',
                                  style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 13,
                                      color: _textMid)),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Batal',
                                      style: TextStyle(
                                          fontFamily: 'Poppins',
                                          color: _textMid)),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Padam',
                                      style: TextStyle(
                                          fontFamily: 'Poppins',
                                          color: Colors.red,
                                          fontWeight: FontWeight.w600)),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) await _deleteCustomFood(food);
                        },
                        child: Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.delete_outline_rounded,
                              size: 14, color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String text, Color textColor, Color bgColor) =>
      Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
            color: bgColor, borderRadius: BorderRadius.circular(8)),
        child: Text(text,
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: textColor)),
      );

  Widget _qtyBtn(IconData icon, bool enabled, VoidCallback onTap) =>
      GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
              color: enabled
                  ? _primary.withOpacity(0.12)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6)),
          child: Icon(icon,
              size: 13,
              color: enabled ? _primary : Colors.grey.shade300),
        ),
      );

  // ── Floating Save Button ─────────────────────────────────────
  Widget _buildSaveFAB() {
    return FloatingActionButton.extended(
      onPressed: _isSaving ? null : _saveMeal,
      backgroundColor: _isSaving ? Colors.grey.shade400 : _primary,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
      icon: _isSaving
          ? const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
            color: _white, strokeWidth: 2.5),
      )
          : const Text('💾', style: TextStyle(fontSize: 18)),
      label: Text(
        _isSaving ? 'Menyimpan...' : '$_selectedCalories kcal',
        style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: _white),
      ),
    );
  }

  // ── Food Detail Bottom Sheet ─────────────────────────────────
  void _showFoodDetail(FoodItem food) {
    final catColor = _catColor(food.category);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        decoration: const BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.all(Radius.circular(28))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Row(children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                    color: catColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16)),
                child: Center(
                    child: Text(food.emoji,
                        style: const TextStyle(fontSize: 30))),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(food.name,
                          style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: _textDark)),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: catColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8)),
                        child: Text(food.category,
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 10,
                                color: catColor,
                                fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(height: 2),
                      Text(food.servingSize,
                          style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: _textMid)),
                    ]),
              ),
            ]),
            if (food.notes.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: catColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  Icon(Icons.tips_and_updates_outlined,
                      size: 14, color: catColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(food.notes,
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: catColor.withOpacity(0.9))),
                  ),
                ]),
              ),
            ],
            const SizedBox(height: 18),
            // Calorie box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                  gradient:
                  LinearGradient(colors: [catColor, _primaryDark]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: catColor.withOpacity(0.3),
                        blurRadius: 14,
                        offset: const Offset(0, 5))
                  ]),
              child: Column(children: [
                const Text('🔥', style: TextStyle(fontSize: 22)),
                const SizedBox(height: 4),
                Text('${food.caloriesPerServing} kcal',
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: _white)),
                Text('per ${food.servingSize}',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: _white.withOpacity(0.8))),
              ]),
            ),
            const SizedBox(height: 18),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Nilai Nutrisi',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _textDark)),
            ),
            const SizedBox(height: 10),
            _buildNutriGrid(food),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    if (_selected.containsKey(food.id)) {
                      _selected.remove(food.id);
                    } else {
                      _selected[food.id] = 1;
                    }
                  });
                  Navigator.pop(context);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                      gradient: _selected.containsKey(food.id)
                          ? const LinearGradient(colors: [
                        Color(0xFFE57373),
                        Color(0xFFEF5350)
                      ])
                          : LinearGradient(
                          colors: [catColor, _primaryDark]),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                            color: (_selected.containsKey(food.id)
                                ? Colors.red
                                : catColor)
                                .withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 5))
                      ]),
                  child: Center(
                    child: Text(
                      _selected.containsKey(food.id)
                          ? '✕  Buang dari pilihan'
                          : '✓  Pilih makanan ini',
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _white),
                    ),
                  ),
                ),
              ),
            ),
            // Delete — hanya untuk custom food
            if (food.isCustom) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: () async {
                    Navigator.pop(context);
                    await _deleteCustomFood(food);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.red.withOpacity(0.2)),
                    ),
                    child: const Center(
                      child: Text('🗑️  Padam makanan ini',
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.red)),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Delete custom food ──────────────────────────────────────
  Future<void> _deleteCustomFood(FoodItem food) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('custom_foods')
          .doc(food.id)
          .delete();
      setState(() {
        _allFoods.removeWhere((f) => f.id == food.id);
        _selected.remove(food.id);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${food.name} dipadam',
                style: const TextStyle(fontFamily: 'Poppins')),
            backgroundColor: Colors.red[400],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (_) {}
  }

  // ── Add Custom Food Sheet ────────────────────────────────────
  void _showAddCustomFoodSheet() {
    final nameCtrl = TextEditingController();
    final servingCtrl = TextEditingController(text: '1 hidangan');
    final calCtrl = TextEditingController();
    final proteinCtrl = TextEditingController(text: '0');
    final carbsCtrl = TextEditingController(text: '0');
    final fatCtrl = TextEditingController(text: '0');
    final fiberCtrl = TextEditingController(text: '0');
    final calciumCtrl = TextEditingController(text: '0');
    final ironCtrl = TextEditingController(text: '0');
    final folateCtrl = TextEditingController(text: '0');
    final formKey = GlobalKey<FormState>();
    String selectedEmoji = '🍽️';
    bool isSaving = false;

    const emojiList = ['🍽️','🍚','🍜','🍛','🥘','🥗','🍗','🥩','🐟','🥚','🧀','🥛','🍞','🥦','🍎','🍌','🧁','🍰','🥤','🧃','🍵','☕'];
    const purpleColor = Color(0xFF7B61FF);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.92,
            ),
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              decoration: const BoxDecoration(
                color: _white,
                borderRadius: BorderRadius.all(Radius.circular(28)),
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Handle
                      Center(
                        child: Container(
                          width: 40, height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Title
                      Row(children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: purpleColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.add_rounded, color: purpleColor, size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Text('Tambah Makanan Sendiri',
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: _textDark)),
                      ]),
                      const SizedBox(height: 20),

                      // Emoji picker
                      const Text('Pilih Ikon',
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _textDark)),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 44,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: emojiList.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 6),
                          itemBuilder: (_, i) {
                            final em = emojiList[i];
                            final picked = selectedEmoji == em;
                            return GestureDetector(
                              onTap: () => setModalState(() => selectedEmoji = em),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width: 42, height: 42,
                                decoration: BoxDecoration(
                                  color: picked ? purpleColor.withOpacity(0.15) : _bg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: picked ? purpleColor : Colors.transparent,
                                    width: 1.5,
                                  ),
                                ),
                                child: Center(child: Text(em, style: const TextStyle(fontSize: 20))),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Nama makanan
                      _customFormField(
                        controller: nameCtrl,
                        label: 'Nama Makanan *',
                        hint: 'contoh: Nasi Goreng Ibu',
                        validator: (v) => (v == null || v.isEmpty) ? 'Diperlukan' : null,
                      ),
                      const SizedBox(height: 12),

                      // Saiz hidangan
                      _customFormField(
                        controller: servingCtrl,
                        label: 'Saiz Hidangan',
                        hint: 'contoh: 1 pinggan (200g)',
                      ),
                      const SizedBox(height: 12),

                      // Kalori — wajib
                      _customFormField(
                        controller: calCtrl,
                        label: 'Kalori (kcal) *',
                        hint: 'contoh: 350',
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Diperlukan';
                          if (int.tryParse(v) == null) return 'Nombor sahaja';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Nutrisi header
                      Row(children: [
                        const Text('Nilai Nutrisi',
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _textDark)),
                        const SizedBox(width: 6),
                        Text('(pilihan)',
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                color: _textMid.withOpacity(0.7))),
                      ]),
                      const SizedBox(height: 10),

                      // Nutrisi grid — 2 column
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        childAspectRatio: 2.8,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        children: [
                          _nutriField('💪 Protein (g)', proteinCtrl),
                          _nutriField('🌾 Karbo (g)', carbsCtrl),
                          _nutriField('🫒 Lemak (g)', fatCtrl),
                          _nutriField('🌿 Fiber (g)', fiberCtrl),
                          _nutriField('🦴 Kalsium (mg)', calciumCtrl),
                          _nutriField('🩸 Zat Besi (mg)', ironCtrl),
                          _nutriField('🧬 Folat (mcg)', folateCtrl),
                        ],
                      ),

                      const SizedBox(height: 22),

                      // Save button
                      SizedBox(
                        width: double.infinity,
                        child: GestureDetector(
                          onTap: isSaving ? null : () async {
                            if (!formKey.currentState!.validate()) return;
                            setModalState(() => isSaving = true);

                            final uid = FirebaseAuth.instance.currentUser?.uid;
                            if (uid == null) return;

                            final docRef = FirebaseFirestore.instance
                                .collection('users')
                                .doc(uid)
                                .collection('custom_foods')
                                .doc();

                            final data = {
                              'name': nameCtrl.text.trim(),
                              'category': 'Lain-lain',
                              'calories_per_serving': int.tryParse(calCtrl.text) ?? 0,
                              'serving_size': servingCtrl.text.trim(),
                              'emoji': selectedEmoji,
                              'trimester_suitable': ['1', '2', '3'],
                              'nutrients': {
                                'protein': double.tryParse(proteinCtrl.text) ?? 0,
                                'carbs': double.tryParse(carbsCtrl.text) ?? 0,
                                'fat': double.tryParse(fatCtrl.text) ?? 0,
                                'fiber': double.tryParse(fiberCtrl.text) ?? 0,
                                'calcium': double.tryParse(calciumCtrl.text) ?? 0,
                                'iron': double.tryParse(ironCtrl.text) ?? 0,
                                'folate': double.tryParse(folateCtrl.text) ?? 0,
                              },
                              'notes': '',
                              'isCustom': true,
                              'createdAt': FieldValue.serverTimestamp(),
                            };

                            try {
                              await docRef.set(data);
                              final newFood = FoodItem(
                                id: docRef.id,
                                name: nameCtrl.text.trim(),
                                category: 'Lain-lain',
                                caloriesPerServing: int.tryParse(calCtrl.text) ?? 0,
                                servingSize: servingCtrl.text.trim(),
                                emoji: selectedEmoji,
                                trimesterSuitable: ['1', '2', '3'],
                                nutrients: {
                                  'protein': double.tryParse(proteinCtrl.text) ?? 0,
                                  'carbs': double.tryParse(carbsCtrl.text) ?? 0,
                                  'fat': double.tryParse(fatCtrl.text) ?? 0,
                                  'fiber': double.tryParse(fiberCtrl.text) ?? 0,
                                  'calcium': double.tryParse(calciumCtrl.text) ?? 0,
                                  'iron': double.tryParse(ironCtrl.text) ?? 0,
                                  'folate': double.tryParse(folateCtrl.text) ?? 0,
                                },
                                isCustom: true,
                              );
                              final savedName = nameCtrl.text.trim();
                              setState(() => _allFoods.add(newFood));
                              // Tutup form dulu
                              Navigator.of(ctx).pop();
                              // Tunjuk snackbar
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(children: [
                                      const Text('✅ ', style: TextStyle(fontSize: 16)),
                                      Text('$savedName ditambah!',
                                          style: const TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600)),
                                    ]),
                                    backgroundColor: purpleColor,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12)),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            } catch (_) {
                              setModalState(() => isSaving = false);
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            decoration: BoxDecoration(
                              gradient: isSaving
                                  ? LinearGradient(colors: [
                                Colors.grey.shade400,
                                Colors.grey.shade500,
                              ])
                                  : const LinearGradient(
                                colors: [Color(0xFF9B7FFF), Color(0xFF7B61FF)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: purpleColor.withOpacity(0.35),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Center(
                              child: isSaving
                                  ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(
                                    color: _white, strokeWidth: 2.5),
                              )
                                  : const Text('Simpan Makanan',
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
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Edit Custom Food Sheet ──────────────────────────────────
  void _showEditCustomFoodSheet(FoodItem food) {
    final nameCtrl = TextEditingController(text: food.name);
    final servingCtrl = TextEditingController(text: food.servingSize);
    final calCtrl = TextEditingController(text: food.caloriesPerServing.toString());
    final proteinCtrl = TextEditingController(text: (food.nutrients['protein'] ?? 0).toString());
    final carbsCtrl = TextEditingController(text: (food.nutrients['carbs'] ?? 0).toString());
    final fatCtrl = TextEditingController(text: (food.nutrients['fat'] ?? 0).toString());
    final fiberCtrl = TextEditingController(text: (food.nutrients['fiber'] ?? 0).toString());
    final calciumCtrl = TextEditingController(text: (food.nutrients['calcium'] ?? 0).toString());
    final ironCtrl = TextEditingController(text: (food.nutrients['iron'] ?? 0).toString());
    final folateCtrl = TextEditingController(text: (food.nutrients['folate'] ?? 0).toString());
    final formKey = GlobalKey<FormState>();
    String selectedEmoji = food.emoji;
    bool isSaving = false;

    const emojiList = ['🍽️','🍚','🍜','🍛','🥘','🥗','🍗','🥩','🐟','🥚','🧀','🥛','🍞','🥦','🍎','🍌','🧁','🍰','🥤','🧃','🍵','☕'];
    const purpleColor = Color(0xFF7B61FF);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.92,
            ),
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              decoration: const BoxDecoration(
                color: _white,
                borderRadius: BorderRadius.all(Radius.circular(28)),
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40, height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: purpleColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.edit_outlined, color: purpleColor, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Text('Edit Makanan',
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: _textDark)),
                      ]),
                      const SizedBox(height: 20),

                      // Emoji picker
                      const Text('Pilih Ikon',
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _textDark)),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 44,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: emojiList.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 6),
                          itemBuilder: (_, i) {
                            final em = emojiList[i];
                            final picked = selectedEmoji == em;
                            return GestureDetector(
                              onTap: () => setModalState(() => selectedEmoji = em),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width: 42, height: 42,
                                decoration: BoxDecoration(
                                  color: picked ? purpleColor.withOpacity(0.15) : _bg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: picked ? purpleColor : Colors.transparent,
                                    width: 1.5,
                                  ),
                                ),
                                child: Center(child: Text(em, style: const TextStyle(fontSize: 20))),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      _customFormField(
                        controller: nameCtrl,
                        label: 'Nama Makanan *',
                        hint: 'contoh: Nasi Goreng Ibu',
                        validator: (v) => (v == null || v.isEmpty) ? 'Diperlukan' : null,
                      ),
                      const SizedBox(height: 12),
                      _customFormField(
                        controller: servingCtrl,
                        label: 'Saiz Hidangan',
                        hint: 'contoh: 1 pinggan (200g)',
                      ),
                      const SizedBox(height: 12),
                      _customFormField(
                        controller: calCtrl,
                        label: 'Kalori (kcal) *',
                        hint: 'contoh: 350',
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Diperlukan';
                          if (int.tryParse(v) == null) return 'Nombor sahaja';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      Row(children: [
                        const Text('Nilai Nutrisi',
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _textDark)),
                        const SizedBox(width: 6),
                        Text('(pilihan)',
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                color: _textMid.withOpacity(0.7))),
                      ]),
                      const SizedBox(height: 10),

                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        childAspectRatio: 2.8,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        children: [
                          _nutriField('💪 Protein (g)', proteinCtrl),
                          _nutriField('🌾 Karbo (g)', carbsCtrl),
                          _nutriField('🫒 Lemak (g)', fatCtrl),
                          _nutriField('🌿 Fiber (g)', fiberCtrl),
                          _nutriField('🦴 Kalsium (mg)', calciumCtrl),
                          _nutriField('🩸 Zat Besi (mg)', ironCtrl),
                          _nutriField('🧬 Folat (mcg)', folateCtrl),
                        ],
                      ),

                      const SizedBox(height: 22),

                      SizedBox(
                        width: double.infinity,
                        child: GestureDetector(
                          onTap: isSaving ? null : () async {
                            if (!formKey.currentState!.validate()) return;
                            setModalState(() => isSaving = true);

                            final uid = FirebaseAuth.instance.currentUser?.uid;
                            if (uid == null) return;

                            final data = {
                              'name': nameCtrl.text.trim(),
                              'category': 'Lain-lain',
                              'calories_per_serving': int.tryParse(calCtrl.text) ?? 0,
                              'serving_size': servingCtrl.text.trim(),
                              'emoji': selectedEmoji,
                              'trimester_suitable': ['1', '2', '3'],
                              'nutrients': {
                                'protein': double.tryParse(proteinCtrl.text) ?? 0,
                                'carbs': double.tryParse(carbsCtrl.text) ?? 0,
                                'fat': double.tryParse(fatCtrl.text) ?? 0,
                                'fiber': double.tryParse(fiberCtrl.text) ?? 0,
                                'calcium': double.tryParse(calciumCtrl.text) ?? 0,
                                'iron': double.tryParse(ironCtrl.text) ?? 0,
                                'folate': double.tryParse(folateCtrl.text) ?? 0,
                              },
                              'notes': '',
                              'isCustom': true,
                            };

                            try {
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(uid)
                                  .collection('custom_foods')
                                  .doc(food.id)
                                  .update(data);

                              final updated = FoodItem(
                                id: food.id,
                                name: nameCtrl.text.trim(),
                                category: 'Lain-lain',
                                caloriesPerServing: int.tryParse(calCtrl.text) ?? 0,
                                servingSize: servingCtrl.text.trim(),
                                emoji: selectedEmoji,
                                trimesterSuitable: ['1', '2', '3'],
                                nutrients: {
                                  'protein': double.tryParse(proteinCtrl.text) ?? 0,
                                  'carbs': double.tryParse(carbsCtrl.text) ?? 0,
                                  'fat': double.tryParse(fatCtrl.text) ?? 0,
                                  'fiber': double.tryParse(fiberCtrl.text) ?? 0,
                                  'calcium': double.tryParse(calciumCtrl.text) ?? 0,
                                  'iron': double.tryParse(ironCtrl.text) ?? 0,
                                  'folate': double.tryParse(folateCtrl.text) ?? 0,
                                },
                                isCustom: true,
                              );

                              setState(() {
                                final idx = _allFoods.indexWhere((f) => f.id == food.id);
                                if (idx != -1) _allFoods[idx] = updated;
                              });

                              Navigator.of(ctx).pop();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(children: [
                                      const Text('✅ ', style: TextStyle(fontSize: 16)),
                                      Text('${nameCtrl.text.trim()} dikemaskini!',
                                          style: const TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600)),
                                    ]),
                                    backgroundColor: purpleColor,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12)),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            } catch (_) {
                              setModalState(() => isSaving = false);
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            decoration: BoxDecoration(
                              gradient: isSaving
                                  ? LinearGradient(colors: [
                                Colors.grey.shade400,
                                Colors.grey.shade500,
                              ])
                                  : const LinearGradient(
                                colors: [Color(0xFF9B7FFF), Color(0xFF7B61FF)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: purpleColor.withOpacity(0.35),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Center(
                              child: isSaving
                                  ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(
                                    color: _white, strokeWidth: 2.5),
                              )
                                  : const Text('Simpan Perubahan',
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
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _customFormField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: _textDark)),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: _textDark),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: _textMid.withOpacity(0.5)),
            filled: true,
            fillColor: _bg,
            contentPadding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF7B61FF), width: 1.5)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.red.shade300, width: 1.5)),
            errorStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 10),
          ),
        ),
      ],
    );
  }

  Widget _nutriField(String label, TextEditingController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontFamily: 'Poppins', fontSize: 9.5, fontWeight: FontWeight.w600, color: _textMid)),
        const SizedBox(height: 3),
        TextFormField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: _textDark),
          decoration: InputDecoration(
            filled: true,
            fillColor: _bg,
            contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
            isDense: true,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF7B61FF), width: 1.5)),
          ),
        ),
      ],
    );
  }

  Widget _buildNutriGrid(FoodItem food) {
    final items = [
      {'e': '💪', 'l': 'Protein', 'k': 'protein', 'u': 'g', 'c': const Color(0xFF5A9ED4)},
      {'e': '🌾', 'l': 'Karbo', 'k': 'carbs', 'u': 'g', 'c': const Color(0xFFE8B842)},
      {'e': '🫒', 'l': 'Lemak', 'k': 'fat', 'u': 'g', 'c': const Color(0xFFE87A42)},
      {'e': '🌿', 'l': 'Fiber', 'k': 'fiber', 'u': 'g', 'c': const Color(0xFF5AB87A)},
      {'e': '🦴', 'l': 'Kalsium', 'k': 'calcium', 'u': 'mg', 'c': const Color(0xFF8A7AE8)},
      {'e': '🩸', 'l': 'Zat Besi', 'k': 'iron', 'u': 'mg', 'c': const Color(0xFFE85A7A)},
      {'e': '🧬', 'l': 'Folat', 'k': 'folate', 'u': 'mcg', 'c': const Color(0xFF42B8E8)},
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          childAspectRatio: 0.9,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final n = items[i];
        final val = food.nutrients[n['k'] as String] ?? 0.0;
        final color = n['c'] as Color;
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(n['e'] as String,
                  style: const TextStyle(fontSize: 17)),
              const SizedBox(height: 4),
              Text(
                val < 10
                    ? '${val.toStringAsFixed(1)}${n['u']}'
                    : '${val.toStringAsFixed(0)}${n['u']}',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color),
              ),
              Text(n['l'] as String,
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 9,
                      color: _textMid),
                  textAlign: TextAlign.center),
            ],
          ),
        );
      },
    );
  }
}

// ── Extension helper ─────────────────────────────────────────
extension ListExtension<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}