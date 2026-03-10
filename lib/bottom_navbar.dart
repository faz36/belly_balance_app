import 'package:flutter/material.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      selectedItemColor: Colors.green.shade700,
      unselectedItemColor: Colors.grey,
      backgroundColor: Colors.white,
      currentIndex: currentIndex,
      type: BottomNavigationBarType.fixed,
      elevation: 10,
      onTap: onTap,  // This will trigger the onTap function passed from MainPage
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.health_and_safety), label: 'Nutrition'),
        BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),  // Add History tab
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),  // Add Profile tab
      ],
    );
  }
}
