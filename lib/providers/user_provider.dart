import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProvider extends ChangeNotifier {
  String _username = '';
  String _age = '';
  String _weight = '';
  String _height = '';
  String _trimester = '';
  String _dueDate = '';
  String _medicalCondition = '';
  double? _bmi;
  bool _isLoading = false;

  // Getters
  String get username => _username;
  String get age => _age;
  String get weight => _weight;
  String get height => _height;
  String get trimester => _trimester;
  String get dueDate => _dueDate;
  String get medicalCondition => _medicalCondition;
  double? get bmi => _bmi;
  bool get isLoading => _isLoading;
  bool get hasData => _username.isNotEmpty;

  // ─── Save ke Firestore ────────────────────────────────────────
  Future<void> saveUserData({
    required String username,
    required String age,
    required String weight,
    required String height,
    required String trimester,
    required String dueDate,
    required String medicalCondition,
    double? bmi,
  }) async {
    _username = username;
    _age = age;
    _weight = weight;
    _height = height;
    _trimester = trimester;
    _dueDate = dueDate;
    _medicalCondition = medicalCondition.isEmpty ? 'Tiada' : medicalCondition;
    _bmi = bmi;
    notifyListeners();

    // Save ke Firestore
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'username': username,
        'age': age,
        'weight': weight,
        'height': height,
        'trimester': trimester,
        'dueDate': dueDate,
        'medicalCondition': medicalCondition.isEmpty ? 'Tiada' : medicalCondition,
        'bmi': bmi,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // ─── Load dari Firestore ──────────────────────────────────────
  Future<void> loadUserData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _username = data['username'] ?? '';
        _age = data['age'] ?? '';
        _weight = data['weight'] ?? '';
        _height = data['height'] ?? '';
        _trimester = data['trimester'] ?? '';
        _dueDate = data['dueDate'] ?? '';
        _medicalCondition = data['medicalCondition'] ?? 'Tiada';
        _bmi = data['bmi'] != null ? (data['bmi'] as num).toDouble() : null;
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── Clear data ───────────────────────────────────────────────
  void clearData() {
    _username = '';
    _age = '';
    _weight = '';
    _height = '';
    _trimester = '';
    _dueDate = '';
    _medicalCondition = '';
    _bmi = null;
    notifyListeners();
  }
}