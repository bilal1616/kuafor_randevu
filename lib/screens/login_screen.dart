import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'register_screen.dart';
import 'bottom_navbar_menu.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _passwordVisible = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

    if (isLoggedIn) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const BottomNavbarMenu()),
      );
    }
  }

  Future<void> _loginUser() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Firebase Authentication ile giriş
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        String? fcmToken = await FirebaseMessaging.instance.getToken();
        // Kullanıcı token'ını güncelle
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({'fcmToken': fcmToken});
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const BottomNavbarMenu()),
        );
      } on FirebaseAuthException catch (e) {
        _emailController.clear();
        _passwordController.clear();
        String errorMessage = 'Bir hata oluştu. Tekrar deneyin.';
        if (e.code == 'user-not-found') {
          errorMessage = 'Kullanıcı bulunamadı. Lütfen kaydolun.';
        } else if (e.code == 'wrong-password') {
          errorMessage = 'Hatalı şifre. Lütfen tekrar deneyin.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showPasswordResetDialog() async {
    final TextEditingController emailController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Şifre Sıfırlama'),
          content: TextField(
            controller: emailController,
            decoration: const InputDecoration(
                hintText: 'E-mail adresinizi girin',
                hintStyle: TextStyle(color: Colors.grey)),
            keyboardType: TextInputType.emailAddress,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('İptal'),
            ),
            ElevatedButton(
              style: const ButtonStyle(
                  backgroundColor: WidgetStatePropertyAll(Color(0xFF156612))),
              onPressed: () async {
                final email = emailController.text.trim();
                if (email.isEmpty || !email.contains('@')) {
                  _showSnackbar('Geçerli bir e-posta adresi girin.');
                  return;
                }
                await _resetPassword(email);
                Navigator.of(context).pop();
              },
              child: const Text(
                'Şifre Sıfırla',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _resetPassword(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _showSnackbar(
          'Şifre sıfırlama bağlantısı e-posta adresinize gönderildi.');
    } catch (e) {
      _showSnackbar('Şifre sıfırlama işlemi sırasında bir hata oluştu.');
    }
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(115, 74, 73, 71),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(115, 184, 0, 31),
        automaticallyImplyLeading: false,
        title: Text(
          'Giriş Yap',
          style: GoogleFonts.poppins(
            color: const Color.fromARGB(255, 251, 251, 251),
          ),
        ),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            color: const Color(0xFFD9D9D9),
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'E-mail',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || !value.contains('@')) {
                          return 'Geçerli bir e-mail girin';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'Şifre',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _passwordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _passwordVisible = !_passwordVisible;
                            });
                          },
                        ),
                      ),
                      obscureText: !_passwordVisible,
                      validator: (value) {
                        if (value == null || value.length < 6) {
                          return 'Şifre en az 6 karakter olmalı';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    _isLoading
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF156612),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 12,
                              ),
                            ),
                            onPressed: _loginUser,
                            child: const Text(
                              'Giriş Yap',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _showPasswordResetDialog,
                      child: const Text(
                        'Şifremi Unuttum',
                        style:
                            TextStyle(color: Color(0xFFB8001F), fontSize: 15),
                      ),
                    ),
                    const SizedBox(height: 5),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const RegisterScreen()),
                        );
                      },
                      child: const Text(
                        'Kaydınız yoksa önce kayıt olun',
                        style: TextStyle(color: Colors.black, fontSize: 16),
                      )
                          .animate(
                            onPlay: (controller) =>
                                controller.repeat(reverse: true),
                          )
                          .fadeIn(duration: 800.ms)
                          .tint(
                              color: Color.fromARGB(115, 184, 0, 31),
                              duration: 800.ms)
                          .then(delay: 100.ms)
                          .tint(
                              color: Color.fromARGB(255, 21, 102, 18),
                              duration: 800.ms)
                          .tint(
                              color: const Color.fromARGB(255, 3, 39, 68),
                              duration: 800.ms),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
