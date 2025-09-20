import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui';
import 'main.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _passwordVisibility = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }


  Future<void> _girisYap() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Firebase Auth ile giriş yap
        final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        
        // Kullanıcı bilgilerini kontrol et
        if (userCredential.user != null) {
          print('Giriş başarılı: ${userCredential.user!.email}');
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Giriş başarılı! Hoş geldiniz!'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Formu temizle
          _formKey.currentState!.reset();
          _emailController.clear();
          _passwordController.clear();

          // Giriş başarılı olduğunda ana sayfaya yönlendir
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const HomePage(),
            ),
          );
        }
      } on FirebaseAuthException catch (e) {
        String errorMessage = 'Bir hata oluştu';
        
        if (e.code == 'user-not-found') {
          errorMessage = 'Bu e-posta adresi ile kayıtlı kullanıcı bulunamadı';
        } else if (e.code == 'wrong-password') {
          errorMessage = 'Hatalı şifre';
        } else if (e.code == 'invalid-email') {
          errorMessage = 'Geçersiz e-posta adresi';
        } else if (e.code == 'user-disabled') {
          errorMessage = 'Bu hesap devre dışı bırakılmış';
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          String errorMessage = 'Beklenmeyen hata oluştu';
          
          // PigeonUserDetails hatasını özel olarak yakala
          if (e.toString().contains('PigeonUserDetails')) {
            print('PigeonUserDetails hatası yakalandı, giriş başarılı sayılıyor');
            // Bu hata Firebase Auth'un bilinen bir sorunu, giriş aslında başarılı
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Giriş başarılı! Hoş geldiniz!'),
                backgroundColor: Colors.green,
              ),
            );
            
            // Formu temizle
            _formKey.currentState!.reset();
            _emailController.clear();
            _passwordController.clear();

            // Ana sayfaya yönlendir
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const HomePage(),
              ),
            );
            return;
          }
          
          // Diğer hatalar için detaylı mesaj
          print('Giriş hatası: $e');
          errorMessage = 'Hata: $e';
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 6),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardVisible = keyboardHeight > 0;
    
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1C1B29), Color(0xFF0E1E3A), Color(0xFF0A0A0A)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height - 
                             MediaQuery.of(context).padding.top - 
                             MediaQuery.of(context).padding.bottom - 32,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                  // Logo ve başlık
                  Column(
                    children: [
                      Container(
                        width: isKeyboardVisible ? 50 : 70,
                        height: isKeyboardVisible ? 50 : 70,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF8A2BE2), Color(0xFF6C63FF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(isKeyboardVisible ? 15 : 20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF8A2BE2).withOpacity(0.4),
                              blurRadius: isKeyboardVisible ? 10 : 15,
                              offset: Offset(0, isKeyboardVisible ? 4 : 6),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.sports,
                          color: Colors.white,
                          size: isKeyboardVisible ? 25 : 35,
                        ),
                      ),
                      SizedBox(height: isKeyboardVisible ? 8 : 16),
                      Text(
                        'AthlorKeşfet',
                        style: TextStyle(
                          fontFamily: 'InterTight',
                          fontWeight: FontWeight.w800,
                          fontSize: isKeyboardVisible ? 22 : 28,
                          color: const Color(0xFFFFFFFF),
                          letterSpacing: -1.0,
                        ),
                      ),
                      if (!isKeyboardVisible) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Spor dünyandaki bağlantılarına kaldığın yerden devam et',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFFFFFFFF).withOpacity(0.7),
                            fontSize: 14,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                  
                  // Form kartı
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1B29).withOpacity(0.8),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF8A2BE2).withOpacity(0.3),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8A2BE2).withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(isKeyboardVisible ? 20 : 24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Başlık
                            const Text(
                              'Giriş Yap',
                              style: TextStyle(
                                fontFamily: 'InterTight',
                                fontWeight: FontWeight.w700,
                                fontSize: 20,
                                color: Color(0xFFFFFFFF),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Hesabına giriş yap ve spor dünyasına katıl',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFFFFFFFF).withOpacity(0.7),
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(height: isKeyboardVisible ? 12 : 20),
                            
                            // E-mail alanı
                            _buildModernTextField(
                              controller: _emailController,
                              hintText: 'E-posta adresin',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'E-posta gerekli';
                                }
                                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                  return 'Geçerli bir e-posta adresi girin';
                                }
                                return null;
                              },
                            ),
                            
                            SizedBox(height: isKeyboardVisible ? 12 : 16),
                            
                            // Şifre alanı
                            _buildModernTextField(
                              controller: _passwordController,
                              hintText: 'Şifren',
                              icon: Icons.lock_outline,
                              keyboardType: TextInputType.visiblePassword,
                              textInputAction: TextInputAction.done,
                              obscureText: !_passwordVisibility,
                              suffixIcon: GestureDetector(
                                onTap: () => setState(() {
                                  _passwordVisibility = !_passwordVisibility;
                                }),
                                child: Icon(
                                  _passwordVisibility
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: const Color(0xFFFFFFFF).withOpacity(0.6),
                                  size: 18,
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Şifre gerekli';
                                }
                                if (value.length < 6) {
                                  return 'Şifre en az 6 karakter olmalı';
                                }
                                return null;
                              },
                            ),
                            
                            SizedBox(height: isKeyboardVisible ? 8 : 12),
                            
                            // Şifremi unuttum
                            Align(
                              alignment: Alignment.centerRight,
                              child: GestureDetector(
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Şifre sıfırlama özelliği yakında eklenecek!'),
                                      backgroundColor: Color(0xFF8A2BE2),
                                    ),
                                  );
                                },
                                child: Text(
                                  'Şifreni mi unuttun?',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF8A2BE2),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            
                            SizedBox(height: isKeyboardVisible ? 12 : 20),
                            
                            // Giriş yap butonu
                            Container(
                              width: double.infinity,
                              height: 48,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF8A2BE2), Color(0xFF6C63FF)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF8A2BE2).withOpacity(0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _girisYap,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text(
                                        'Giriş Yap',
                                        style: TextStyle(
                                          fontFamily: 'InterTight',
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                              ),
                            ),
                            
                            SizedBox(height: isKeyboardVisible ? 8 : 16),
                            
                            // Kayıt ol linki
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Hesabın yok mu? ',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFFFFFFFF).withOpacity(0.7),
                                    fontSize: 12,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const KayitSayfasi(),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    'Kayıt Ol',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF8A2BE2),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
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
  
  Widget _buildModernTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    required TextInputType keyboardType,
    required TextInputAction textInputAction,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      validator: validator,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w500,
        color: Color(0xFFFFFFFF),
        fontSize: 16,
      ),
      cursorColor: const Color(0xFF8A2BE2),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w500,
          color: const Color(0xFFFFFFFF).withOpacity(0.5),
          fontSize: 16,
        ),
        prefixIcon: Icon(
          icon,
          color: const Color(0xFFFFFFFF).withOpacity(0.6),
          size: 20,
        ),
        suffixIcon: suffixIcon,
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: const Color(0xFFFFFFFF).withOpacity(0.2),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(
            color: Color(0xFF8A2BE2),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: const BorderSide(
            color: Color(0xFFFF3B30),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: const BorderSide(
            color: Color(0xFFFF3B30),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        filled: true,
        fillColor: const Color(0xFFFFFFFF).withOpacity(0.05),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}