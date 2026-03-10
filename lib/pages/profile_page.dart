import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:belly_balance/providers/user_provider.dart';
import 'package:belly_balance/services/auth_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _cardController;
  late Animation<double> _fadeAnim;
  late List<Animation<Offset>> _cardSlideAnims;
  final AuthService _authService = AuthService();

  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  bool _editingWeight = false;
  bool _editingHeight = false;
  bool _isSaving = false;

  final int _cardCount = 4;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _cardController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));

    _fadeAnim =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);

    _cardSlideAnims = List.generate(_cardCount, (i) {
      return Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
          .animate(CurvedAnimation(
        parent: _cardController,
        curve: Interval(i * 0.15, 0.6 + i * 0.1, curve: Curves.easeOut),
      ));
    });

    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _cardController.forward();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _cardController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  String calculateCurrentTrimester(String dueDateStr) {
    try {
      final dueDate = DateFormat('dd MMM yyyy').parse(dueDateStr);
      final conceptionDate = dueDate.subtract(const Duration(days: 280));
      final weeksPregnant =
          DateTime.now().difference(conceptionDate).inDays ~/ 7;
      if (weeksPregnant <= 12) return '1st Trimester (Minggu 1–12)';
      if (weeksPregnant <= 26) return '2nd Trimester (Minggu 13–26)';
      return '3rd Trimester (Minggu 27–40)';
    } catch (_) {
      return '';
    }
  }

  int calculateWeeksPregnant(String dueDateStr) {
    try {
      final dueDate = DateFormat('dd MMM yyyy').parse(dueDateStr);
      final conceptionDate = dueDate.subtract(const Duration(days: 280));
      return DateTime.now().difference(conceptionDate).inDays ~/ 7;
    } catch (_) {
      return 0;
    }
  }

  int calculateDaysLeft(String dueDateStr) {
    try {
      final dueDate = DateFormat('dd MMM yyyy').parse(dueDateStr);
      return dueDate.difference(DateTime.now()).inDays;
    } catch (_) {
      return 0;
    }
  }

  double recalculateBMI(String weight, String height) {
    final w = double.tryParse(weight);
    final h = double.tryParse(height);
    if (w != null && h != null && h > 0) {
      final hm = h / 100;
      return double.parse((w / (hm * hm)).toStringAsFixed(1));
    }
    return 0;
  }

  Future<void> _saveWeightHeight(UserProvider user) async {
    setState(() => _isSaving = true);
    final newWeight = _weightController.text.trim();
    final newHeight = _heightController.text.trim();

    final w = double.tryParse(newWeight);
    final h = double.tryParse(newHeight);

    if (w == null || h == null || w <= 0 || h <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Sila masukkan nilai yang sah'),
          backgroundColor: Colors.red[400],
          behavior: SnackBarBehavior.floating,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      setState(() => _isSaving = false);
      return;
    }

    final newBmi = recalculateBMI(newWeight, newHeight);
    final currentTrimester = calculateCurrentTrimester(user.dueDate);

    await user.saveUserData(
      username: user.username,
      age: user.age,
      weight: newWeight,
      height: newHeight,
      trimester:
      currentTrimester.isNotEmpty ? currentTrimester : user.trimester,
      dueDate: user.dueDate,
      medicalCondition: user.medicalCondition,
      bmi: newBmi,
    );

    setState(() {
      _editingWeight = false;
      _editingHeight = false;
      _isSaving = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Maklumat dikemaskini ✓'),
          backgroundColor: const Color(0xFF6BAE75),
          behavior: SnackBarBehavior.floating,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFBF7EE),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Log Keluar?',
            style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
                color: Color(0xFF3A3A3A))),
        content: const Text(
            'Adakah anda pasti ingin log keluar dari akaun ini?',
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: Color(0xFF7A7A7A))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal',
                style: TextStyle(
                    fontFamily: 'Poppins', color: Color(0xFF7A7A7A))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log Keluar',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.red,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      context.read<UserProvider>().clearData();
      await _authService.signOut();
      // MainWrapper auto redirect ke LoginPage via authStateChanges stream
    }
  }

  Color getBmiColor(double? bmi) {
    if (bmi == null) return const Color(0xFF9E9E9E);
    if (bmi < 18.5) return const Color(0xFF64B5F6);
    if (bmi < 25) return const Color(0xFF6BAE75);
    if (bmi < 30) return const Color(0xFFFFB74D);
    return const Color(0xFFE57373);
  }

  String getBmiCategory(double? bmi) {
    if (bmi == null) return 'Tidak Dikira';
    if (bmi < 18.5) return 'Kurang Berat';
    if (bmi < 25) return 'Normal ✓';
    if (bmi < 30) return 'Lebih Berat';
    return 'Obes';
  }

  @override
  Widget build(BuildContext context) {
    const Color bg = Color(0xFFFBF7EE);
    const Color primary = Color(0xFF6BAE75);
    const Color soft = Color(0xFFA8D5B0);
    const Color textDark = Color(0xFF3A3A3A);
    const Color textMid = Color(0xFF7A7A7A);

    final user = context.watch<UserProvider>();

    if (user.hasData && user.dueDate.isNotEmpty) {
      final autoTrimester = calculateCurrentTrimester(user.dueDate);
      if (autoTrimester.isNotEmpty && autoTrimester != user.trimester) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          user.saveUserData(
            username: user.username,
            age: user.age,
            weight: user.weight,
            height: user.height,
            trimester: autoTrimester,
            dueDate: user.dueDate,
            medicalCondition: user.medicalCondition,
            bmi: user.bmi,
          );
        });
      }
    }

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          Positioned(
            top: -80, left: -50,
            child: Container(
              width: 250, height: 250,
              decoration: BoxDecoration(
                  shape: BoxShape.circle, color: soft.withOpacity(0.3)),
            ),
          ),
          Positioned(
            top: 120, right: -30,
            child: Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primary.withOpacity(0.1)),
            ),
          ),
          Positioned(
            bottom: 80, right: -60,
            child: Container(
              width: 200, height: 200,
              decoration: BoxDecoration(
                  shape: BoxShape.circle, color: soft.withOpacity(0.2)),
            ),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: user.hasData
                  ? _buildProfile(
                  context, user, primary, soft, textDark, textMid)
                  : _buildEmpty(context, primary, textMid),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, Color primary, Color textMid) {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: primary.withOpacity(0.1)),
                    child: Icon(Icons.person_outline_rounded,
                        size: 48, color: primary.withOpacity(0.5)),
                  ),
                  const SizedBox(height: 24),
                  const Text('Profil Belum Lengkap',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF3A3A3A))),
                  const SizedBox(height: 8),
                  Text('Sila lengkapkan maklumat anda terlebih dahulu',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          color: textMid)),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: _logoutButton(),
        ),
      ],
    );
  }

  Widget _buildProfile(BuildContext context, UserProvider user, Color primary,
      Color soft, Color textDark, Color textMid) {
    final weeks = calculateWeeksPregnant(user.dueDate);
    final daysLeft = calculateDaysLeft(user.dueDate);
    final currentTrimester = calculateCurrentTrimester(user.dueDate);
    final displayTrimester =
    currentTrimester.isNotEmpty ? currentTrimester : user.trimester;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Profil Saya',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: textMid)),
            ],
          ),

          const SizedBox(height: 24),

          // Avatar — no emoji, just initial letter
          Center(
            child: Column(
              children: [
                Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6BAE75), Color(0xFFA8D5B0)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                          color: primary.withOpacity(0.35),
                          blurRadius: 24,
                          offset: const Offset(0, 10))
                    ],
                  ),
                  child: Center(
                    child: Text(
                      user.username.isNotEmpty
                          ? user.username[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 38,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(user.username,
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF3A3A3A))),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                      color: primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    displayTrimester,
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6BAE75)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Card: Peribadi
          _animatedCard(
            index: 1,
            child: _infoCard(
              title: 'Maklumat Peribadi',
              icon: Icons.person_outline_rounded,
              items: [
                _infoRow(Icons.person_outline_rounded, 'Nama', user.username),
                _divider(),
                _infoRow(Icons.cake_outlined, 'Umur', '${user.age} tahun'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Card: Fizikal
          _animatedCard(
            index: 2,
            child: _physicalCard(user, primary),
          ),
          const SizedBox(height: 16),

          // Card: Kesihatan
          _animatedCard(
            index: 3,
            child: _infoCard(
              title: 'Status Kesihatan',
              icon: Icons.medical_information_outlined,
              items: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color:
                            const Color(0xFF6BAE75).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10)),
                        child: const Icon(
                            Icons.medical_information_outlined,
                            color: Color(0xFF6BAE75),
                            size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Penyakit / Kondisi',
                                style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 12,
                                    color: Color(0xFF7A7A7A))),
                            const SizedBox(height: 4),
                            Text(user.medicalCondition,
                                style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF3A3A3A))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          _logoutButton(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _physicalCard(UserProvider user, Color primary) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                      color: const Color(0xFF6BAE75).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(9)),
                  child: const Icon(Icons.monitor_weight_outlined,
                      color: Color(0xFF6BAE75), size: 16),
                ),
                const SizedBox(width: 8),
                const Text('Maklumat Fizikal',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF7A7A7A),
                        letterSpacing: 0.3)),
              ]),
              if (!_editingWeight && !_editingHeight)
                GestureDetector(
                  onTap: () {
                    _weightController.text = user.weight;
                    _heightController.text = user.height;
                    setState(() {
                      _editingWeight = true;
                      _editingHeight = true;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6BAE75).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.edit_outlined,
                            size: 13, color: Color(0xFF6BAE75)),
                        SizedBox(width: 4),
                        Text('Edit',
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6BAE75))),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _editableRow(
            icon: Icons.monitor_weight_outlined,
            label: 'Berat',
            value: '${user.weight} kg',
            controller: _weightController,
            isEditing: _editingWeight,
            suffix: 'kg',
            primary: primary,
          ),
          _divider(),
          _editableRow(
            icon: Icons.height_rounded,
            label: 'Tinggi',
            value: '${user.height} cm',
            controller: _heightController,
            isEditing: _editingHeight,
            suffix: 'cm',
            primary: primary,
          ),
          _divider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: getBmiColor(user.bmi).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.analytics_outlined,
                      color: getBmiColor(user.bmi), size: 18),
                ),
                const SizedBox(width: 12),
                const Text('BMI',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        color: Color(0xFF7A7A7A))),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      user.bmi != null ? user.bmi.toString() : '-',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: getBmiColor(user.bmi)),
                    ),
                    Text(
                      getBmiCategory(user.bmi),
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10.5,
                          color: getBmiColor(user.bmi),
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_editingWeight || _editingHeight) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _editingWeight = false;
                      _editingHeight = false;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text('Batal',
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF7A7A7A))),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap:
                    _isSaving ? null : () => _saveWeightHeight(user),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF6BAE75),
                            Color(0xFF4E9A5B)
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: _isSaving
                            ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                            : const Text('Simpan',
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _editableRow({
    required IconData icon,
    required String label,
    required String value,
    required TextEditingController controller,
    required bool isEditing,
    required String suffix,
    required Color primary,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: const Color(0xFF6BAE75).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child:
            Icon(icon, color: const Color(0xFF6BAE75), size: 18),
          ),
          const SizedBox(width: 12),
          Text(label,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: Color(0xFF7A7A7A))),
          const Spacer(),
          if (isEditing)
            SizedBox(
              width: 90,
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.right,
                autofocus: true,
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3A3A3A)),
                decoration: InputDecoration(
                  suffix: Text(' $suffix',
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: Color(0xFF7A7A7A))),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 6, horizontal: 8),
                  filled: true,
                  fillColor:
                  const Color(0xFF6BAE75).withOpacity(0.08),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                      BorderSide(color: primary, width: 1.5)),
                ),
              ),
            )
          else
            Text(value,
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3A3A3A))),
        ],
      ),
    );
  }

  Widget _pregnancyStat(String label, String value, String unit) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Colors.white)),
        Text(unit,
            style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                color: Colors.white60)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.white70)),
      ],
    );
  }

  Widget _logoutButton() {
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: _logout,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.shade200, width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: Colors.red.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout_rounded, color: Colors.red[400], size: 20),
              const SizedBox(width: 10),
              Text('Log Keluar',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.red[400])),
            ],
          ),
        ),
      ),
    );
  }

  Widget _animatedCard({required int index, required Widget child}) {
    return SlideTransition(
      position: _cardSlideAnims[index % _cardCount],
      child: FadeTransition(opacity: _fadeAnim, child: child),
    );
  }

  Widget _infoCard({
    required String title,
    required IconData icon,
    required List<Widget> items,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                  color: const Color(0xFF6BAE75).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(9)),
              child:
              Icon(icon, color: const Color(0xFF6BAE75), size: 16),
            ),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF7A7A7A),
                    letterSpacing: 0.3)),
          ]),
          const SizedBox(height: 12),
          ...items,
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: const Color(0xFF6BAE75).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child:
            Icon(icon, color: const Color(0xFF6BAE75), size: 18),
          ),
          const SizedBox(width: 12),
          Text(label,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: Color(0xFF7A7A7A))),
          const Spacer(),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3A3A3A))),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Divider(
      color: Colors.grey.withOpacity(0.12), thickness: 1, height: 0);
}