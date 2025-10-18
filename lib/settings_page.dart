import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'login_page.dart';
import 'user_status_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isLoading = false;
  String _userBio = '';
  List<String> _selectedInterests = [];
  final UserStatusService _userStatusService = UserStatusService();

  // 6 branş kategorisi
  final List<Map<String, dynamic>> _interestCategories = [
    {'id': 'tennis', 'name': 'Tenis', 'icon': Icons.sports_tennis, 'color': const Color(0xFF22C55E)},
    {'id': 'football', 'name': 'Futbol', 'icon': Icons.sports_soccer, 'color': const Color(0xFF007AFF)},
    {'id': 'basketball', 'name': 'Basketbol', 'icon': Icons.sports_basketball, 'color': const Color(0xFFFF6B35)},
    {'id': 'volleyball', 'name': 'Voleybol', 'icon': Icons.sports_volleyball, 'color': const Color(0xFF8A2BE2)},
    {'id': 'boxing', 'name': 'Boks', 'icon': Icons.sports_mma, 'color': const Color(0xFFFF3B30)},
    {'id': 'fitness', 'name': 'Fitness', 'icon': Icons.fitness_center, 'color': const Color(0xFF06B6D4)},
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data();
        setState(() {
          _userBio = userData?['bio'] ?? '';
          _selectedInterests = List<String>.from(userData?['interests'] ?? []);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kullanıcı bilgileri yüklenirken hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        automaticallyImplyLeading: false,
        leading: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 0),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8A2BE2), Color(0xFF6C63FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8A2BE2).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: IconButton(
              onPressed: () {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/home',
                  (route) => false,
                );
              },
              icon: const Icon(
                Icons.arrow_back_ios,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
        title: Text(
          'Ayarlar',
          style: GoogleFonts.interTight(
            fontWeight: FontWeight.w600,
            fontSize: 24,
            color: const Color(0xFFFFFFFF),
          ),
        ),
        centerTitle: false,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hesap Ayarları
            _buildSectionTitle('Hesap Ayarları'),
            const SizedBox(height: 16),
            
            // Bio Düzenle
            _buildSettingsItem(
              icon: Icons.edit_note,
              title: 'Bio Düzenle',
              subtitle: 'Kendinizi tanıtın',
              onTap: _editBio,
            ),
            
            const SizedBox(height: 8),
            
            // İlgi Alanları
            _buildSettingsItem(
              icon: Icons.favorite_outline,
              title: 'İlgi Alanları',
              subtitle: 'Hangi branşlarla ilgilendiğinizi seçin',
              onTap: _selectInterests,
            ),
            
            const SizedBox(height: 8),
            
            // Şifre Değiştir
            _buildSettingsItem(
              icon: Icons.lock_outline,
              title: 'Şifre Değiştir',
              subtitle: 'Hesap şifrenizi güncelleyin',
              onTap: _changePassword,
            ),
            
            const SizedBox(height: 32),

            // Yönetim (yalnızca admin)
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(FirebaseAuth.instance.currentUser?.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                final data = snapshot.data!.data() as Map<String, dynamic>?;
                final isAdmin = data != null && (data['isAdmin'] == true);
                if (!isAdmin) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('Yönetim'),
                    const SizedBox(height: 16),
                    _buildSettingsItem(
                      icon: Icons.admin_panel_settings,
                      title: 'Moderasyon Paneli',
                      subtitle: 'Raporları görüntüle ve işlem yap',
                      onTap: () => Navigator.pushNamed(context, '/admin_moderation'),
                    ),
                    const SizedBox(height: 32),
                  ],
                );
              },
            ),

            // Tehlikeli Bölge
            _buildSectionTitle('Tehlikeli Bölge'),
            const SizedBox(height: 16),
            
            // Hesabı Sil
            _buildSettingsItem(
              icon: Icons.delete_forever_outlined,
              title: 'Hesabı Sil',
              subtitle: 'Hesabınızı kalıcı olarak silin',
              onTap: _deleteAccount,
              isDangerous: true,
            ),
            
            const SizedBox(height: 32),
            
            // Çıkış Yap
            _buildSettingsItem(
              icon: Icons.logout,
              title: 'Çıkış Yap',
              subtitle: 'Hesabınızdan güvenli şekilde çıkış yapın',
              onTap: _signOut,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.interTight(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: const Color(0xFFFFFFFF),
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDangerous = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1C1B29), Color(0xFF0E1E3A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDangerous 
              ? const Color(0xFFFF3B30).withOpacity(0.3)
              : const Color(0xFF8A2BE2).withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDangerous 
                ? const Color(0xFFFF3B30).withOpacity(0.1)
                : const Color(0xFF8A2BE2).withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: isDangerous 
                ? const LinearGradient(
                    colors: [Color(0xFFFF3B30), Color(0xFFFF6B6B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : const LinearGradient(
                    colors: [Color(0xFF8A2BE2), Color(0xFF6C63FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: isDangerous 
                    ? const Color(0xFFFF3B30).withOpacity(0.3)
                    : const Color(0xFF8A2BE2).withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDangerous ? const Color(0xFFFF3B30) : const Color(0xFFFFFFFF),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xFFFFFFFF).withOpacity(0.7),
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: const Color(0xFFFFFFFF).withOpacity(0.5),
          size: 16,
        ),
        onTap: _isLoading ? null : onTap,
      ),
    );
  }

  Future<void> _editBio() async {
    final TextEditingController bioController = TextEditingController(text: _userBio);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1B29),
        title: const Text(
          'Bio Düzenle',
          style: TextStyle(color: Color(0xFFFFFFFF)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: bioController,
              maxLines: 4,
              maxLength: 150,
              style: const TextStyle(color: Color(0xFFFFFFFF)),
              decoration: InputDecoration(
                hintText: 'Kendinizi tanıtın...',
                hintStyle: TextStyle(color: const Color(0xFFFFFFFF).withOpacity(0.5)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: const Color(0xFF8A2BE2).withOpacity(0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: const Color(0xFF8A2BE2).withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF8A2BE2)),
                ),
                filled: true,
                fillColor: const Color(0xFF0E1E3A),
                counterText: '',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${bioController.text.length}/150',
              style: TextStyle(
                color: const Color(0xFFFFFFFF).withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'İptal',
              style: TextStyle(color: Color(0xFFFFFFFF)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8A2BE2),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context);
              await _updateBio(bioController.text);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateBio(String newBio) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Firestore'da bio'yu güncelle
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({
        'bio': newBio,
        'bioUpdatedAt': FieldValue.serverTimestamp(),
      });

      // Başarı mesajı
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bio başarıyla güncellendi!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Bio'yu güncelle
      setState(() {
        _userBio = newBio;
      });

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bio güncellenirken hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectInterests() async {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1C1B29),
            title: const Text(
              'İlgi Alanlarınızı Seçin',
              style: TextStyle(color: Color(0xFFFFFFFF)),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _interestCategories.map((category) {
                  final isSelected = _selectedInterests.contains(category['id']);
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      gradient: isSelected 
                          ? LinearGradient(
                              colors: [
                                category['color'].withOpacity(0.2),
                                category['color'].withOpacity(0.1),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected 
                          ? Border.all(color: category['color'].withOpacity(0.5))
                          : Border.all(color: const Color(0xFF8A2BE2).withOpacity(0.2)),
                    ),
                    child: CheckboxListTile(
                      title: Text(
                        category['name'],
                        style: const TextStyle(color: Color(0xFFFFFFFF)),
                      ),
                      subtitle: Text(
                        '${category['name']} branşı ile ilgileniyorum',
                        style: TextStyle(color: const Color(0xFFFFFFFF).withOpacity(0.7)),
                      ),
                      value: isSelected,
                      activeColor: category['color'],
                      checkColor: Colors.white,
                      onChanged: (bool? value) {
                        setDialogState(() {
                          if (value == true) {
                            _selectedInterests.add(category['id']);
                          } else {
                            _selectedInterests.remove(category['id']);
                          }
                        });
                      },
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: category['color'].withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          category['icon'],
                          color: category['color'],
                          size: 20,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'İptal',
                  style: TextStyle(color: Color(0xFFFFFFFF)),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8A2BE2),
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  Navigator.pop(context);
                  await _updateInterests();
                },
                child: const Text('Kaydet'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _updateInterests() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Firestore'da ilgi alanlarını güncelle
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({
        'interests': _selectedInterests,
        'interestsUpdatedAt': FieldValue.serverTimestamp(),
      });

      // Başarı mesajı
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('İlgi alanları başarıyla güncellendi!'),
            backgroundColor: Colors.green,
          ),
        );
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('İlgi alanları güncellenirken hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _changePassword() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kullanıcı girişi yapılmamış'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Şifre değiştirme dialog'u
    final TextEditingController currentPasswordController = TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1B29),
        title: const Text(
          'Şifre Değiştir',
          style: TextStyle(color: Color(0xFFFFFFFF)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPasswordController,
              obscureText: true,
              style: const TextStyle(color: Color(0xFFFFFFFF)),
              decoration: InputDecoration(
                labelText: 'Mevcut Şifre',
                labelStyle: const TextStyle(color: Color(0xFFFFFFFF)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: const Color(0xFF8A2BE2).withOpacity(0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: const Color(0xFF8A2BE2).withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF8A2BE2)),
                ),
                filled: true,
                fillColor: const Color(0xFF0E1E3A),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: newPasswordController,
              obscureText: true,
              style: const TextStyle(color: Color(0xFFFFFFFF)),
              decoration: InputDecoration(
                labelText: 'Yeni Şifre',
                labelStyle: const TextStyle(color: Color(0xFFFFFFFF)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: const Color(0xFF8A2BE2).withOpacity(0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: const Color(0xFF8A2BE2).withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF8A2BE2)),
                ),
                filled: true,
                fillColor: const Color(0xFF0E1E3A),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmPasswordController,
              obscureText: true,
              style: const TextStyle(color: Color(0xFFFFFFFF)),
              decoration: InputDecoration(
                labelText: 'Yeni Şifre Tekrar',
                labelStyle: const TextStyle(color: Color(0xFFFFFFFF)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: const Color(0xFF8A2BE2).withOpacity(0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: const Color(0xFF8A2BE2).withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF8A2BE2)),
                ),
                filled: true,
                fillColor: const Color(0xFF0E1E3A),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'İptal',
              style: TextStyle(color: Color(0xFFFFFFFF)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8A2BE2),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (newPasswordController.text != confirmPasswordController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Yeni şifreler eşleşmiyor'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              if (newPasswordController.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Şifre en az 6 karakter olmalıdır'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.pop(context);
              await _updatePassword(currentPasswordController.text, newPasswordController.text);
            },
            child: const Text('Değiştir'),
          ),
        ],
      ),
    );
  }

  Future<void> _updatePassword(String currentPassword, String newPassword) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Mevcut şifreyi doğrula
      final credential = EmailAuthProvider.credential(
        email: currentUser.email!,
        password: currentPassword,
      );

      await currentUser.reauthenticateWithCredential(credential);

      // Şifreyi güncelle
      await currentUser.updatePassword(newPassword);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Şifre başarıyla güncellendi!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Şifre güncellenirken hata oluştu';
        
        if (e.toString().contains('wrong-password')) {
          errorMessage = 'Mevcut şifre yanlış';
        } else if (e.toString().contains('weak-password')) {
          errorMessage = 'Şifre çok zayıf';
        } else if (e.toString().contains('requires-recent-login')) {
          errorMessage = 'Güvenlik için tekrar giriş yapmanız gerekiyor';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteAccount() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kullanıcı girişi yapılmamış'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Onay dialog'u
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1B29),
        title: const Text(
          'Hesabı Sil',
          style: TextStyle(color: Color(0xFFFFFFFF)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bu işlem geri alınamaz!',
              style: TextStyle(color: Color(0xFFFF3B30), fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Hesabınız ve tüm verileriniz kalıcı olarak silinecektir:',
              style: TextStyle(color: const Color(0xFFFFFFFF).withOpacity(0.9)),
            ),
            const SizedBox(height: 8),
            Text('• Profil bilgileri', style: TextStyle(color: const Color(0xFFFFFFFF).withOpacity(0.8))),
            Text('• Paylaştığınız fotoğraflar', style: TextStyle(color: const Color(0xFFFFFFFF).withOpacity(0.8))),
            Text('• Mesajlar', style: TextStyle(color: const Color(0xFFFFFFFF).withOpacity(0.8))),
            Text('• Takipçi/takip listeleri', style: TextStyle(color: const Color(0xFFFFFFFF).withOpacity(0.8))),
            const SizedBox(height: 16),
            Text(
              'Devam etmek için "HESABI SİL" yazın:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: const Color(0xFFFFFFFF).withOpacity(0.9),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'İptal',
              style: TextStyle(color: Color(0xFFFFFFFF)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF3B30),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              _showDeleteConfirmation();
            },
            child: const Text('Devam Et'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation() {
    final TextEditingController confirmationController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1B29),
        title: const Text(
          'Son Onay',
          style: TextStyle(color: Color(0xFFFFFFFF)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Hesabınızı silmek için "HESABI SİL" yazın:',
              style: TextStyle(color: const Color(0xFFFFFFFF).withOpacity(0.9)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmationController,
              style: const TextStyle(color: Color(0xFFFFFFFF)),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: const Color(0xFFFF3B30).withOpacity(0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: const Color(0xFFFF3B30).withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFFF3B30)),
                ),
                hintText: 'HESABI SİL',
                hintStyle: TextStyle(color: const Color(0xFFFFFFFF).withOpacity(0.5)),
                filled: true,
                fillColor: const Color(0xFF0E1E3A),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'İptal',
              style: TextStyle(color: Color(0xFFFFFFFF)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF3B30),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (confirmationController.text == 'HESABI SİL') {
                Navigator.pop(context);
                _performAccountDeletion();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Lütfen "HESABI SİL" yazın'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Hesabı Sil'),
          ),
        ],
      ),
    );
  }

  Future<void> _performAccountDeletion() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Loading dialog göster
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1C1B29),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                color: Color(0xFF8A2BE2),
              ),
              const SizedBox(height: 16),
              Text(
                'Hesap siliniyor...',
                style: TextStyle(
                  color: const Color(0xFFFFFFFF).withOpacity(0.9),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );

      // Kullanıcının verilerini sil
      await _deleteUserData(currentUser.uid);

      // Firebase Storage'daki dosyaları sil
      await _deleteUserFiles(currentUser.uid);

      // Kullanıcı hesabını sil
      await currentUser.delete();

      // Dialog'u kapat
      if (mounted) Navigator.pop(context);

      // Ana sayfaya yönlendir
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hesabınız başarıyla silindi'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Dialog'u kapat
      if (mounted) Navigator.pop(context);

      if (mounted) {
        String errorMessage = 'Hesap silinirken hata oluştu';
        
        if (e.toString().contains('requires-recent-login')) {
          errorMessage = 'Güvenlik için tekrar giriş yapmanız gerekiyor';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteUserData(String userId) async {
    try {
      // Firestore'daki kullanıcı verilerini sil
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .delete();

      // Kullanıcının mesajlarını sil
      final chatsQuery = await FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: userId)
          .get();

      for (var chatDoc in chatsQuery.docs) {
        await chatDoc.reference.delete();
      }

      // Kullanıcının takipçi/takip listelerinden kendisini çıkar
      final usersQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('following', arrayContains: userId)
          .get();

      for (var userDoc in usersQuery.docs) {
        await userDoc.reference.update({
          'following': FieldValue.arrayRemove([userId]),
          'followingCount': FieldValue.increment(-1),
        });
      }

      final followersQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('followers', arrayContains: userId)
          .get();

      for (var userDoc in followersQuery.docs) {
        await userDoc.reference.update({
          'followers': FieldValue.arrayRemove([userId]),
          'followerCount': FieldValue.increment(-1),
        });
      }
    } catch (e) {
      print('Kullanıcı verileri silinirken hata: $e');
    }
  }

  Future<void> _deleteUserFiles(String userId) async {
    try {
      // Profil fotoğraflarını sil
      final profilePhotosRef = FirebaseStorage.instance
          .ref()
          .child('profile_photos');

      final profilePhotosList = await profilePhotosRef.listAll();
      for (var item in profilePhotosList.items) {
        if (item.name.startsWith('${userId}_profile_')) {
          await item.delete();
        }
      }

      // Post fotoğraflarını sil
      final postPhotosRef = FirebaseStorage.instance
          .ref()
          .child('post_images');

      final postPhotosList = await postPhotosRef.listAll();
      for (var item in postPhotosList.items) {
        if (item.name.startsWith('${userId}_')) {
          await item.delete();
        }
      }
    } catch (e) {
      print('Kullanıcı dosyaları silinirken hata: $e');
    }
  }

  Future<void> _signOut() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Kullanıcıyı çevrimdışı yap
      await _userStatusService.setUserOffline();

      await FirebaseAuth.instance.signOut();

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Başarıyla çıkış yapıldı'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Çıkış yapılırken hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
