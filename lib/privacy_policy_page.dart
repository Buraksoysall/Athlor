import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'interest_selection_page.dart';
import 'auth_service.dart';
import 'email_verification_page.dart';
import 'login_page.dart';
import 'terms_of_use_page.dart';

class PrivacyPolicyPage extends StatefulWidget {
  final Map<String, String>? registrationData;
  
  const PrivacyPolicyPage({super.key, this.registrationData});

  @override
  State<PrivacyPolicyPage> createState() => _PrivacyPolicyPageState();
}

class _PrivacyPolicyPageState extends State<PrivacyPolicyPage> {
  bool _isAccepted = false;
  bool _isLoading = false;
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Gizlilik Politikası',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.black,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Başlık
            Text(
              'FitMatch Gizlilik Politikası',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 24,
                color: const Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Son güncelleme: 06.09.2025',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF666666),
              ),
            ),
            const SizedBox(height: 24),
            
            // Açıklama
            Text(
              'Bu gizlilik politikası, FitMatch ("uygulama") tarafından sunulan hizmetleri kullanan kullanıcıların kişisel verilerinin nasıl toplandığını, kullanıldığını ve korunduğunu açıklar. Uygulamayı kullanarak bu politikayı kabul etmiş olursunuz.',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: const Color(0xFF333333),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),

            // Bölüm 1
            _buildSection(
              '1. Toplanan Bilgiler',
              'FitMatch uygulaması kullanıcıdan aşağıdaki verileri toplar:\n\n'
              '• E-posta adresi (kayıt ve giriş işlemleri için)\n'
              '• Profil bilgileri: isim, kullanıcı adı, biyografi, profil fotoğrafı\n'
              '• Kullanıcı tarafından yüklenen fotoğraflar (postlar)\n'
              '• İlgi alanları (örneğin futbol, voleybol)\n'
              '• Aktivite bilgileri (ör. katıldığı etkinlikler, takipçi sayısı, takip ettiği kişiler)\n'
              '• Çevrim içi durumu ve son görülme zamanı',
            ),

            // Bölüm 2
            _buildSection(
              '2. Verilerin Kullanımı',
              'Toplanan veriler şu amaçlarla kullanılır:\n\n'
              '• Hesap oluşturma ve kullanıcı giriş işlemlerinin sağlanması\n'
              '• Kullanıcı profili oluşturulması\n'
              '• Kullanıcının kendi isteğiyle fotoğraf, gönderi ve profil bilgisini paylaşabilmesi\n'
              '• Uygulamanın performans ve güvenliğini geliştirmek',
            ),

            // Bölüm 3
            _buildSection(
              '3. Verilerin Paylaşımı',
              'Kullanıcı verileri hiçbir şekilde üçüncü taraflarla paylaşılmaz.\n\n'
              'Paylaşım yalnızca kullanıcının kendi tercihleri doğrultusunda gerçekleşir (örneğin, kullanıcı gönderi paylaşırsa bu diğer kullanıcılar tarafından görülebilir).',
            ),

            // Bölüm 4
            _buildSection(
              '4. Veri Güvenliği',
              'Veriler, Firebase altyapısında güvenli şekilde saklanmaktadır.\n\n'
              'Yetkisiz erişimi önlemek için gerekli teknik ve idari tedbirler alınmaktadır.',
            ),

            // Bölüm 5
            _buildSection(
              '5. Kullanıcı Hakları',
              'Kullanıcı, istediği zaman hesabını silebilir.\n\n'
              'Hesap silindiğinde tüm kişisel veriler kalıcı olarak kaldırılır.\n\n'
              'Kullanıcı, verilerinin silinmesini veya güncellenmesini talep edebilir.',
            ),

            // Bölüm 6
            _buildSection(
              '6. Üçüncü Taraf Servisler',
              'FitMatch, Firebase (Google) altyapısını kullanmaktadır. Firebase\'in gizlilik politikası için: https://firebase.google.com/support/privacy',
            ),

            // Bölüm 7
            _buildSection(
              '7. İletişim',
              'Gizlilik politikası ile ilgili sorularınız için bizimle iletişime geçebilirsiniz:\n\n'
              '📧 buraksoysal08@gmail.com',
            ),

            const SizedBox(height: 32),

            // Kabul checkbox'ı
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isAccepted ? Colors.green : const Color(0xFFE5E5E5),
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _isAccepted,
                    onChanged: (value) {
                      setState(() {
                        _isAccepted = value ?? false;
                      });
                    },
                    activeColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'FitMatch Gizlilik Politikası\'nı okudum ve kabul ediyorum.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: const Color(0xFF333333),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Butonlar
            Column(
              children: [
                // Devam et butonu
                Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _isAccepted ? Colors.green : const Color(0xFFE5E5E5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ElevatedButton(
                    onPressed: _isAccepted && !_isLoading ? _continueToInterests : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isAccepted ? Colors.green : const Color(0xFFE5E5E5),
                      foregroundColor: _isAccepted ? Colors.white : const Color(0xFF999999),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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
                        : Text(
                            'Devam Et',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                // Reddet butonu
                Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: ElevatedButton(
                    onPressed: !_isLoading ? _rejectAndDeleteAccount : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.red,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      widget.registrationData != null 
                          ? 'Kabul Etmiyorum - Kayıt İptal'
                          : 'Kabul Etmiyorum - Hesabımı Sil',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: const Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          content,
          style: GoogleFonts.inter(
            fontSize: 16,
            color: const Color(0xFF333333),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Future<void> _continueToInterests() async {
    if (!_isAccepted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Eğer kayıt verisi varsa, önce Firebase Auth ile kayıt yap
      if (widget.registrationData != null) {
        await _createUserAccount();
        
        // Kayıt sonrası EULA (Kullanım Şartları) sayfasına yönlendir
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const TermsOfUsePage(),
            ),
          );
        }
      } else {
        // Mevcut kullanıcı için gizlilik politikası kabulünü güncelle
        await _updateExistingUserPrivacyPolicy();
        
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const InterestSelectionPage(),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bir hata oluştu: $e'),
            backgroundColor: Colors.red,
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

  Future<void> _createUserAccount() async {
    final data = widget.registrationData!;
    
    try {
      // AuthService kullanarak kayıt ol (email doğrulama maili otomatik gönderilir)
      final UserCredential userCredential = await _authService.registerWithEmailAndPassword(
        email: data['email']!,
        password: data['password']!,
        name: data['name']!,
        username: data['username']!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kayıt başarılı! E-posta doğrulama linki gönderildi.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Bir hata oluştu';
      if (e.code == 'email-already-in-use') {
        errorMessage = 'Bu e-posta adresi zaten kullanılıyor. Lütfen giriş yapın.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Geçersiz e-posta adresi.';
      } else if (e.code == 'weak-password') {
        errorMessage = 'Şifre çok zayıf. Lütfen daha güçlü bir şifre belirleyin.';
      } else if (e.message != null && e.message!.isNotEmpty) {
        errorMessage = e.message!;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );

        // Eğer e-posta zaten kullanılıyorsa, kullanıcıya Login'e gitme seçeneği sun
        if (e.code == 'email-already-in-use') {
          final goLogin = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('E-posta Kullanımda'),
              content: const Text('Bu e-posta ile daha önce bir hesap oluşturulmuş. Giriş yapmaya gitmek ister misiniz?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('İptal'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Giriş Yap'),
                ),
              ],
            ),
          );

          if (goLogin == true && mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const LoginPage(),
              ),
            );
          }
        }
      }

      throw Exception(errorMessage);
    }
  }

  Future<void> _updateExistingUserPrivacyPolicy() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Önce kullanıcı belgesinin var olup olmadığını kontrol et
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        // Belge varsa güncelle
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'privacyPolicyAccepted': true,
          'privacyPolicyAcceptedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Belge yoksa oluştur
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
          'uid': user.uid,
          'userId': user.uid,
          'displayName': user.displayName ?? '',
          'email': user.email ?? '',
          'privacyPolicyAccepted': true,
          'privacyPolicyAcceptedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  Future<void> _rejectAndDeleteAccount() async {
    // Onay dialogu göster
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            widget.registrationData != null ? 'Kayıt İptal' : 'Hesabı Sil',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
          content: Text(
            widget.registrationData != null 
                ? 'Gizlilik politikasını kabul etmediğiniz için kayıt işlemi iptal edilecek. Emin misiniz?'
                : 'Gizlilik politikasını kabul etmediğiniz için hesabınız silinecek. Bu işlem geri alınamaz. Emin misiniz?',
            style: GoogleFonts.inter(
              fontSize: 16,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'İptal',
                style: GoogleFonts.inter(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                widget.registrationData != null ? 'Evet, İptal Et' : 'Evet, Sil',
                style: GoogleFonts.inter(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        if (widget.registrationData != null) {
          // Yeni kayıt işlemi iptal edildi, sadece login sayfasına dön
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Kayıt işlemi iptal edildi.'),
                backgroundColor: Colors.orange,
              ),
            );

            // Login sayfasına yönlendir
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/',
              (route) => false,
            );
          }
        } else {
          // Mevcut hesabı sil
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            // Firestore'dan kullanıcı belgesini sil
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .delete();

            // Firebase Auth'dan kullanıcıyı sil
            await user.delete();
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Hesabınız başarıyla silindi.'),
                backgroundColor: Colors.green,
              ),
            );

            // Login sayfasına yönlendir
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/',
              (route) => false,
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('İşlem sırasında hata oluştu: $e'),
              backgroundColor: Colors.red,
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
}
