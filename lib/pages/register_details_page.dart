import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:belly_balance/pages/main_wrapper.dart';
import 'package:belly_balance/providers/user_provider.dart';

class RegisterDetailsPage extends StatefulWidget {
  const RegisterDetailsPage({super.key});

  @override
  State<RegisterDetailsPage> createState() => _RegisterDetailsPageState();
}

class _RegisterDetailsPageState extends State<RegisterDetailsPage>
    with TickerProviderStateMixin {
  final usernameController = TextEditingController();
  final ageController = TextEditingController();
  final weightController = TextEditingController();
  final heightController = TextEditingController();
  final medicalController = TextEditingController();

  String? selectedTrimester;
  String? estimatedDueDate;
  double? bmi;
  bool _isSaving = false;

  final _formKey = GlobalKey<FormState>();
  bool _isButtonPressed = false;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _slideController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    usernameController.dispose();
    ageController.dispose();
    weightController.dispose();
    heightController.dispose();
    medicalController.dispose();
    super.dispose();
  }

  void calculateBMI() {
    final weight = double.tryParse(weightController.text);
    final height = double.tryParse(heightController.text);
    if (weight != null && height != null && height > 0) {
      final heightInMeter = height / 100;
      final bmiCalc = weight / (heightInMeter * heightInMeter);
      setState(() {
        bmi = double.parse(bmiCalc.toStringAsFixed(1));
      });
    } else {
      setState(() => bmi = null);
    }
  }

  String getBmiCategory() {
    if (bmi == null) return '';
    if (bmi! < 18.5) return 'Kurang Berat';
    if (bmi! < 25) return 'Normal';
    if (bmi! < 30) return 'Lebih Berat';
    return 'Obes';
  }

  Color getBmiColor() {
    if (bmi == null) return Colors.transparent;
    if (bmi! < 18.5) return const Color(0xFF64B5F6);
    if (bmi! < 25) return const Color(0xFF81C784);
    if (bmi! < 30) return const Color(0xFFFFB74D);
    return const Color(0xFFE57373);
  }

  Future<void> selectDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 100)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF6BAE75),
              onPrimary: Colors.white,
              surface: Color(0xFFFBF7EE),
              onSurface: Color(0xFF3D3D3D),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        estimatedDueDate = DateFormat('dd MMM yyyy').format(picked);
      });
    }
  }

  String? validateNumericInput(String? value) {
    if (value == null || value.isEmpty) return 'Ruangan ini diperlukan';
    if (double.tryParse(value) == null) return 'Sila masukkan nombor yang sah';
    return null;
  }

  Future<void> _saveAndNavigate() async {
    setState(() => _isButtonPressed = true);

    if (!_formKey.currentState!.validate() || estimatedDueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Sila lengkapkan semua maklumat'),
          backgroundColor: const Color(0xFF6BAE75),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Save ke Provider + Firestore
      await context.read<UserProvider>().saveUserData(
        username: usernameController.text.trim(),
        age: ageController.text.trim(),
        weight: weightController.text.trim(),
        height: heightController.text.trim(),
        trimester: selectedTrimester ?? '',
        dueDate: estimatedDueDate ?? '',
        medicalCondition: medicalController.text.trim(),
        bmi: bmi,
      );

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainWrapper()),
              (_) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ralat: $e'),
            backgroundColor: Colors.red[400],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color bg = Color(0xFFFBF7EE);
    const Color primary = Color(0xFF6BAE75);
    const Color soft = Color(0xFFA8D5B0);
    const Color textDark = Color(0xFF3A3A3A);
    const Color textMid = Color(0xFF7A7A7A);

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          Positioned(
            top: -60, right: -60,
            child: Container(
              width: 220, height: 220,
              decoration: BoxDecoration(
                  shape: BoxShape.circle, color: soft.withOpacity(0.35)),
            ),
          ),
          Positioned(
            top: 60, right: 80,
            child: Container(
              width: 90, height: 90,
              decoration: BoxDecoration(
                  shape: BoxShape.circle, color: primary.withOpacity(0.15)),
            ),
          ),
          Positioned(
            bottom: 100, left: -40,
            child: Container(
              width: 160, height: 160,
              decoration: BoxDecoration(
                  shape: BoxShape.circle, color: soft.withOpacity(0.2)),
            ),
          ),
          SafeArea(
            bottom: false,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),

                        // Header
                        Center(
                          child: Column(
                            children: [
                              Container(
                                width: 70, height: 70,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF6BAE75), Color(0xFFA8D5B0)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                        color: primary.withOpacity(0.3),
                                        blurRadius: 20,
                                        offset: const Offset(0, 8)),
                                  ],
                                ),
                                child: const Icon(Icons.favorite_rounded,
                                    color: Colors.white, size: 32),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                "Maklumat Anda",
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  color: textDark,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                "Bantu kami menjaga anda & si kecil 🌿",
                                style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 13,
                                    color: textMid),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),
                        _sectionLabel("👤  Maklumat Peribadi", textMid),
                        const SizedBox(height: 12),
                        _buildField(
                          controller: usernameController,
                          hint: "Nama Pengguna",
                          icon: Icons.person_outline_rounded,
                          primary: primary,
                          validator: (v) =>
                          v!.isEmpty ? "Nama diperlukan" : null,
                        ),
                        const SizedBox(height: 14),
                        _buildField(
                          controller: ageController,
                          hint: "Umur (tahun)",
                          icon: Icons.cake_outlined,
                          primary: primary,
                          keyboardType: TextInputType.number,
                          validator: validateNumericInput,
                        ),

                        const SizedBox(height: 24),
                        _sectionLabel("📏  Maklumat Fizikal", textMid),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildField(
                                controller: weightController,
                                hint: "Berat (kg)",
                                icon: Icons.monitor_weight_outlined,
                                primary: primary,
                                keyboardType: TextInputType.number,
                                validator: validateNumericInput,
                                onChanged: (_) => calculateBMI(),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildField(
                                controller: heightController,
                                hint: "Tinggi (cm)",
                                icon: Icons.height_rounded,
                                primary: primary,
                                keyboardType: TextInputType.number,
                                validator: validateNumericInput,
                                onChanged: (_) => calculateBMI(),
                              ),
                            ),
                          ],
                        ),

                        if (bmi != null) ...[
                          const SizedBox(height: 16),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOut,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 14),
                            decoration: BoxDecoration(
                              color: getBmiColor().withOpacity(0.12),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: getBmiColor().withOpacity(0.4),
                                  width: 1.5),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Indeks Jisim Badan (BMI)",
                                        style: TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 11,
                                            color: textMid)),
                                    const SizedBox(height: 2),
                                    Text(bmi.toString(),
                                        style: TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 24,
                                            fontWeight: FontWeight.w700,
                                            color: getBmiColor())),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: getBmiColor().withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(getBmiCategory(),
                                      style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: getBmiColor())),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),
                        _sectionLabel("🌸  Maklumat Kehamilan", textMid),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3))
                            ],
                          ),
                          child: DropdownButtonFormField<String>(
                            value: selectedTrimester,
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded),
                            dropdownColor: Colors.white,
                            items: [
                              '1st Trimester (Minggu 1–12)',
                              '2nd Trimester (Minggu 13–26)',
                              '3rd Trimester (Minggu 27–40)',
                            ].map((String t) {
                              return DropdownMenuItem<String>(
                                value: t,
                                child: Text(t,
                                    style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 13.5,
                                        color: textDark)),
                              );
                            }).toList(),
                            onChanged: (value) =>
                                setState(() => selectedTrimester = value),
                            decoration: InputDecoration(
                              prefixIcon: Icon(
                                  Icons.pregnant_woman_rounded,
                                  color: primary),
                              hintText: "Pilih Trimester",
                              hintStyle: TextStyle(
                                  fontFamily: 'Poppins',
                                  color: Colors.grey[400],
                                  fontSize: 13.5),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 16, horizontal: 16),
                            ),
                            validator: (v) =>
                            v == null ? "Sila pilih trimester" : null,
                          ),
                        ),

                        const SizedBox(height: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: selectDueDate,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3))
                                  ],
                                  border: (_isButtonPressed &&
                                      estimatedDueDate == null)
                                      ? Border.all(
                                      color: Colors.red.shade300,
                                      width: 1.5)
                                      : Border.all(color: Colors.transparent),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.calendar_month_rounded,
                                        color: primary, size: 22),
                                    const SizedBox(width: 12),
                                    Text(
                                      estimatedDueDate ??
                                          "Tarikh Jangkaan Bersalin",
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 13.5,
                                        color: estimatedDueDate == null
                                            ? Colors.grey[400]
                                            : textDark,
                                      ),
                                    ),
                                    const Spacer(),
                                    Icon(Icons.arrow_forward_ios_rounded,
                                        size: 14, color: Colors.grey[400]),
                                  ],
                                ),
                              ),
                            ),
                            if (_isButtonPressed && estimatedDueDate == null)
                              Padding(
                                padding:
                                const EdgeInsets.only(left: 12, top: 6),
                                child: Text(
                                  "Sila pilih tarikh jangkaan bersalin",
                                  style: TextStyle(
                                      fontFamily: 'Poppins',
                                      color: Colors.red[400],
                                      fontSize: 11.5),
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 24),
                        _sectionLabel("🏥  Status Kesihatan", textMid),
                        const SizedBox(height: 12),
                        _buildField(
                          controller: medicalController,
                          hint: "Penyakit / Kondisi Kesihatan (Jika Ada)",
                          icon: Icons.medical_information_outlined,
                          primary: primary,
                          maxLines: 3,
                          validator: (_) => null,
                        ),

                        const SizedBox(height: 36),

                        SizedBox(
                          width: double.infinity,
                          child: GestureDetector(
                            onTap: _isSaving ? null : _saveAndNavigate,
                            child: Container(
                              padding:
                              const EdgeInsets.symmetric(vertical: 18),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: _isSaving
                                      ? [Colors.grey.shade400, Colors.grey.shade500]
                                      : [const Color(0xFF6BAE75), const Color(0xFF4E9A5B)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                      color: const Color(0xFF6BAE75)
                                          .withOpacity(0.4),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8)),
                                ],
                              ),
                              child: Center(
                                child: _isSaving
                                    ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5),
                                )
                                    : const Text(
                                  "Simpan Maklumat  ✨",
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        SizedBox(
                            height: MediaQuery.of(context).padding.bottom + 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label, Color color) {
    return Text(label,
        style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: color,
            letterSpacing: 0.5));
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required Color primary,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
    void Function(String)? onChanged,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        onChanged: onChanged,
        validator: validator,
        maxLines: maxLines,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        style: const TextStyle(
            fontFamily: 'Poppins', fontSize: 13.5, color: Color(0xFF3A3A3A)),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: primary, size: 20),
          hintText: hint,
          hintStyle: TextStyle(
              fontFamily: 'Poppins', color: Colors.grey[400], fontSize: 13.5),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
          const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: primary, width: 1.8)),
          errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.red.shade300, width: 1.5)),
          focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.red.shade400, width: 1.8)),
          errorStyle: const TextStyle(
              fontFamily: 'Poppins', fontSize: 11, color: Colors.red),
        ),
      ),
    );
  }
}