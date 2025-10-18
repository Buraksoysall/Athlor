import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'splash_screen.dart';
import 'login_page.dart';
import 'home_page.dart';
import 'profile_page.dart';
import 'message_page.dart';
import 'users_page.dart';
import 'add_activity_page.dart';
import 'user_status_service.dart';
import 'privacy_policy_page.dart';
import 'leaderboard_page.dart';
import 'auth_service.dart';
import 'email_verification_page.dart';
import 'terms_of_use_page.dart';
import 'admin_moderation_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (kIsWeb) {
    // Web için Firebase konfigürasyonu
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyBz9mS1IoHj_I0N28Futch91PnXyjYyT70",
        authDomain: "athlor-27900.firebaseapp.com",
        projectId: "athlor-27900",
        storageBucket: "athlor-27900.firebasestorage.app",
        messagingSenderId: "426946717348",
        appId: "1:426946717348:web:15d75f73ae52f8a83ba831",
        measurementId: "G-WJJDXCD77J",
      ),
    );
  } else {
    // Mobile için varsayılan konfigürasyon
    await Firebase.initializeApp();
  }
  // Email doğrulama ve diğer şablonlar için dil ayarı (Türkçe)
  try {
    await FirebaseAuth.instance.setLanguageCode('tr');
  } catch (_) {
    // Dil ayarı başarısız olsa bile uygulama çalışmaya devam eder
  }
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final UserStatusService _userStatusService = UserStatusService();
  final AuthService _authService = AuthService();
  // Global navigator key for navigation from auth listeners
  static final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupAuthStateListener();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    _userStatusService.handleAppLifecycleState(state);
  }

  void _setupAuthStateListener() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      if (user != null) {
        // Email doğrulama kontrolü yap
        final canLogin = await _authService.canUserLogin(user);
        
        if (!canLogin) {
          // Email doğrulanmamışsa burada signOut yapma.
          // Kullanıcı EmailVerificationPage üzerinden doğrulamayı tamamlayacak.
          return;
        }
        
        // Kullanıcı giriş yaptı - gizlilik politikası kontrolü yap
        await _checkPrivacyPolicyAcceptance(user);
        _userStatusService.setUserOnline();
      } else {
        // Kullanıcı çıkış yaptı
        _userStatusService.setUserOffline();
      }
    });
  }

  Future<void> _checkPrivacyPolicyAcceptance(User user) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data();
        final privacyPolicyAccepted = data?['privacyPolicyAccepted'] ?? false;
        final eulaAccepted = data?['eulaAccepted'] ?? false;
        
        if (!privacyPolicyAccepted || !eulaAccepted) {
          // Oturumu bozmadan terms sayfasına yönlendir
          _navKey.currentState?.pushNamedAndRemoveUntil('/terms', (route) => false);
          return;
        }
      } else {
        // Kullanıcı belgesi yoksa terms sayfasına yönlendir (oturumu bozma)
        _navKey.currentState?.pushNamedAndRemoveUntil('/terms', (route) => false);
        return;
      }
    } catch (e) {
      print('Gizlilik politikası ve EULA kontrolü hatası: $e');
      // Hata durumunda oturumu bozmadan terms sayfasına yönlendir
      _navKey.currentState?.pushNamedAndRemoveUntil('/terms', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fit Match App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      navigatorKey: _navKey,
      home: const SplashScreen(),
      routes: {
        '/home': (context) => const HomePage(),
        '/profile': (context) => const ProfilePage(),
        '/message': (context) => const MessagePage(),
        '/users': (context) => const UsersPage(),
        '/add_activity': (context) => const AddActivityPage(),
        '/leaderboard': (context) => const LeaderboardPage(),
        '/email_verification': (context) => const EmailVerificationPage(),
        '/terms': (context) => const TermsOfUsePage(),
        '/admin_moderation': (context) => const AdminModerationPage(),
      },
    );
  }
}

class KayitSayfasi extends StatefulWidget {
  const KayitSayfasi({super.key});

  @override
  State<KayitSayfasi> createState() => _KayitSayfasiState();
}

class _KayitSayfasiState extends State<KayitSayfasi> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _passwordVisibility = false;
  bool _confirmPasswordVisibility = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _kayitOl() async {
    if (_formKey.currentState!.validate()) {
      if (_passwordController.text != _confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Şifreler eşleşmiyor!'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Form verilerini gizlilik politikası sayfasına gönder
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => PrivacyPolicyPage(
            registrationData: {
              'name': _nameController.text.trim(),
              'username': _usernameController.text.trim(),
              'email': _emailController.text.trim(),
              'password': _passwordController.text,
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  
                  // Logo ve başlık
                  Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF8A2BE2), Color(0xFF6C63FF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF8A2BE2).withOpacity(0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.sports,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'AthlorKeşfet',
                        style: TextStyle(
                          fontFamily: 'InterTight',
                          fontWeight: FontWeight.w800,
                          fontSize: 32,
                          color: Color(0xFFFFFFFF),
                          letterSpacing: -1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Rakiplerini belirle, takımını kur, birlikte sporun tadını çıkar',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFFFFFFFF).withOpacity(0.7),
                          fontSize: 16,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Form kartı
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1B29).withOpacity(0.8),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color(0xFF8A2BE2).withOpacity(0.3),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8A2BE2).withOpacity(0.1),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Başlık
                            const Text(
                              'Hesap Oluştur',
                              style: TextStyle(
                                fontFamily: 'InterTight',
                                fontWeight: FontWeight.w700,
                                fontSize: 24,
                                color: Color(0xFFFFFFFF),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Spor dünyasına katıl ve yeni arkadaşlar edin',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFFFFFFFF).withOpacity(0.7),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 32),
                            
                            // İsim alanı
                            _buildModernTextField(
                              controller: _nameController,
                              hintText: 'Adın Soyadın',
                              icon: Icons.person_outline,
                              keyboardType: TextInputType.name,
                              textInputAction: TextInputAction.next,
                              textCapitalization: TextCapitalization.words,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'İsim gerekli';
                                }
                                return null;
                              },
                            ),
                            
                            const SizedBox(height: 20),
                            
                            // Kullanıcı adı alanı
                            _buildModernTextField(
                              controller: _usernameController,
                              hintText: 'Kullanıcı Adın',
                              icon: Icons.alternate_email,
                              keyboardType: TextInputType.text,
                              textInputAction: TextInputAction.next,
                              textCapitalization: TextCapitalization.none,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Kullanıcı adı gerekli';
                                }
                                if (value.length < 3) {
                                  return 'Kullanıcı adı en az 3 karakter olmalı';
                                }
                                return null;
                              },
                            ),
                            
                            const SizedBox(height: 20),
                            
                            // E-mail alanı
                            _buildModernTextField(
                              controller: _emailController,
                              hintText: 'E-posta adresin',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              textCapitalization: TextCapitalization.none,
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
                            
                            const SizedBox(height: 20),
                            
                            // Şifre alanı
                            _buildModernTextField(
                              controller: _passwordController,
                              hintText: 'Şifren',
                              icon: Icons.lock_outline,
                              keyboardType: TextInputType.visiblePassword,
                              textInputAction: TextInputAction.next,
                              textCapitalization: TextCapitalization.none,
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
                                  size: 20,
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
                            
                            const SizedBox(height: 20),
                            
                            // Şifre tekrar alanı
                            _buildModernTextField(
                              controller: _confirmPasswordController,
                              hintText: 'Şifreni tekrar gir',
                              icon: Icons.lock_outline,
                              keyboardType: TextInputType.visiblePassword,
                              textInputAction: TextInputAction.done,
                              textCapitalization: TextCapitalization.none,
                              obscureText: !_confirmPasswordVisibility,
                              suffixIcon: GestureDetector(
                                onTap: () => setState(() {
                                  _confirmPasswordVisibility = !_confirmPasswordVisibility;
                                }),
                                child: Icon(
                                  _confirmPasswordVisibility
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: const Color(0xFFFFFFFF).withOpacity(0.6),
                                  size: 20,
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Şifre tekrarı gerekli';
                                }
                                if (value != _passwordController.text) {
                                  return 'Şifreler eşleşmiyor';
                                }
                                return null;
                              },
                            ),
                            
                            const SizedBox(height: 32),
                            
                            // Kayıt ol butonu
                            Container(
                              width: double.infinity,
                              height: 56,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF8A2BE2), Color(0xFF6C63FF)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF8A2BE2).withOpacity(0.4),
                                    blurRadius: 15,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _kayitOl,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text(
                                        'Hesap Oluştur',
                                        style: TextStyle(
                                          fontFamily: 'InterTight',
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                        ),
                                      ),
                              ),
                            ),
                            
                            const SizedBox(height: 32),
                            
                            // Giriş yap linki
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Zaten hesabın var mı? ',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFFFFFFFF).withOpacity(0.7),
                                    fontSize: 14,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const LoginPage(),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    'Giriş Yap',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF8A2BE2),
                                      fontSize: 14,
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
                  
                  const SizedBox(height: 40),
                ],
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
    required TextCapitalization textCapitalization,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),
    );
  }
}
