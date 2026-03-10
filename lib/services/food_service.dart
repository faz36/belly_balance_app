import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_storage/firebase_storage.dart';

class FoodService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final String apiUrl = 'https://world.openfoodfacts.org/data/products.json';

  // Fetch food data from Open Food Facts API
  Future<List<Map<String, dynamic>>> fetchFoodData() async {
    final response = await http.get(Uri.parse('$apiUrl?fields=product_name,calories,nutriments,ingredients_text'));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data['products'] ?? []);
    } else {
      throw Exception('Failed to load food data from Open Food Facts');
    }
  }

  // Upload fetched data to Firebase Storage
  Future<void> uploadJsonToFirebase(List<Map<String, dynamic>> foodData) async {
    try {
      final jsonString = json.encode(foodData);
      final ref = _storage.ref().child('foods.json');  // Firebase Storage path
      final uploadTask = ref.putString(jsonString);  // No format argument needed

      await uploadTask.whenComplete(() => print('Data uploaded to Firebase'));
    } catch (e) {
      print('Error uploading to Firebase: $e');
    }
  }

  // Fetch JSON data from Firebase Storage (if needed)
  Future<List<Map<String, dynamic>>> getFoodDataFromFirebase() async {
    try {
      final ref = FirebaseStorage.instance.ref().child('foods.json');
      final downloadUrl = await ref.getDownloadURL();
      final response = await http.get(Uri.parse(downloadUrl));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['products'] ?? []);
      } else {
        throw Exception('Failed to load data from Firebase');
      }
    } catch (e) {
      print('Error fetching data from Firebase: $e');
      return [];
    }
  }
}
