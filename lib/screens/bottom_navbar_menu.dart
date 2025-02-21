import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/home_screen.dart';
import '../widgets/appointment_screen.dart';
import '../widgets/my_appointment_screen.dart';
import '../widgets/admin_appointment_screen.dart';
import '../widgets/profile_screen.dart';
import '../widgets/admin_appointment_settings_screen.dart';
import 'login_screen.dart';

class BottomNavbarMenu extends StatefulWidget {
  const BottomNavbarMenu({Key? key}) : super(key: key);

  @override
  _BottomNavbarMenuState createState() => _BottomNavbarMenuState();
}

class _BottomNavbarMenuState extends State<BottomNavbarMenu> {
  int _currentIndex = 0;
  bool _isAdmin = false;
  bool _isLoading = true;

  late final List<Widget> _adminScreens;
  late final List<Widget> _userScreens;

  @override
  void initState() {
    super.initState();
    _initializeScreens();
  }

  Future<void> _initializeScreens() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;

      if (uid == null) {
        // Kullanıcı oturumu kapalı, giriş ekranına yönlendir
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
        return;
      }

      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      setState(() {
        _isAdmin = userDoc.data()?['isAdmin'] ?? false;

        _adminScreens = [
          const HomeScreen(),
          const AppointmentScreen(),
          const AdminAppointmentSettingsScreen(),
          const AdminAppointmentScreen(),
          ProfileScreen(),
        ];

        _userScreens = [
          const HomeScreen(),
          const AppointmentScreen(),
          const MyAppointmentScreen(),
          ProfileScreen(),
        ];

        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bir hata oluştu: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final screens = _isAdmin ? _adminScreens : _userScreens;

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: Colors.black87,
        selectedItemColor: const Color.fromARGB(255, 251, 251, 251),
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: const TextStyle(color: Colors.black),
        unselectedLabelStyle: const TextStyle(color: Colors.grey),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        items: _isAdmin
            ? const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home),
                  label: 'Ana Sayfa',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.calendar_today),
                  label: 'Randevular',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings),
                  label: 'Admin Ayarları',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.schedule),
                  label: 'Admin Randevuları',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  label: 'Profil',
                ),
              ]
            : const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home),
                  label: 'Ana Sayfa',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.calendar_today),
                  label: 'Randevular',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.history),
                  label: 'Geçmiş',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  label: 'Profil',
                ),
              ],
      ),
    );
  }
}
