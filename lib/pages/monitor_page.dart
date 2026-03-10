import 'package:flutter/material.dart';

class MonitorPage extends StatelessWidget {
  final List<Map<String, dynamic>> dailyFoods;
  final int totalCalories;

  const MonitorPage({Key? key, required this.dailyFoods, required this.totalCalories}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Monitor'),
        centerTitle: true,
        backgroundColor: Colors.green[700],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Total Calories: $totalCalories kcal',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            SizedBox(height: 20),
            Text(
              'Nutrition Comparison (Today vs Recommended)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Table(
              border: TableBorder.all(),
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.green[100]),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text('Nutrient', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text('Today'),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text('Recommended'),
                    ),
                  ],
                ),
                _buildTableRow('Calories', '$totalCalories kcal', '1800 kcal'),
                _buildTableRow('Protein', '35 g', '60 g'),
                _buildTableRow('Iron', '10 mg', '27 mg'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  TableRow _buildTableRow(String label, String today, String recommended) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(label),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(today),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(recommended),
        ),
      ],
    );
  }
}
