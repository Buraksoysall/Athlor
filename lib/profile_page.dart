import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_page.dart';
import 'settings_page.dart';

class ProfilePage extends StatefulWidget {
  final String? targetUserId; // null ise kendi profili, dolu ise başkasının profili
  
  const ProfilePage({super.key, this.targetUserId});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ImagePicker _picker = ImagePicker();
  List<XFile> _selectedImages = [];
  List<String> _userPosts = [];
  bool _isLoadingPosts = true;
  
  // Kullanıcı bilgileri
  String _userName = 'Kullanıcı Adı';
  String _userBio = '';
  List<String> _userInterests = [];
  int _activityCount = 0;
  int _followerCount = 0;
  int _followingCount = 0;
  int _userRank = 0; // Leaderboard sıralaması
  bool _isLoadingUserData = true;
  String? _profileImageUrl;

  // İlgi alanları kategorileri
  final List<Map<String, dynamic>> _interestCategories = [
    {'id': 'tennis', 'name': 'Tenis', 'icon': Icons.sports_tennis, 'color': Colors.green},
    {'id': 'football', 'name': 'Futbol', 'icon': Icons.sports_soccer, 'color': Colors.blue},
    {'id': 'basketball', 'name': 'Basketbol', 'icon': Icons.sports_basketball, 'color': Colors.orange},
    {'id': 'volleyball', 'name': 'Voleybol', 'icon': Icons.sports_volleyball, 'color': Colors.purple},
    {'id': 'boxing', 'name': 'Boks', 'icon': Icons.sports_mma, 'color': Colors.red},
    {'id': 'fitness', 'name': 'Fitness', 'icon': Icons.fitness_center, 'color': Colors.cyan},
  ];
  
  // Takip durumu
  bool _isFollowing = false;
  bool _isLoadingFollow = false;
  bool _isOwnProfile = true;

  @override
  void initState() {
    super.initState();
    _isOwnProfile = widget.targetUserId == null;
    _loadUserData();
    _loadUserPosts();
    if (!_isOwnProfile) {
      _checkFollowStatus();
    }
    // Negatif değerleri düzelt
    _fixNegativeCounts();
  }

  Future<void> _loadUserData() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Hangi kullanıcının verilerini yükleyeceğimizi belirle
      final targetUserId = widget.targetUserId ?? currentUser.uid;
      
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(targetUserId)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data();
        
        setState(() {
          _userName = userData?['username'] ?? userData?['displayName'] ?? 'Kullanıcı';
          _userBio = userData?['bio'] ?? '';
          _userInterests = List<String>.from(userData?['interests'] ?? []);
          _followerCount = _ensureNonNegative(userData?['followerCount']);
          _followingCount = _ensureNonNegative(userData?['followingCount']);
          _profileImageUrl = userData?['profileImageUrl'];
          _isLoadingUserData = false;
        });
        
        // Aktivite sayısını dinamik olarak hesapla
        _calculateActivityCount(targetUserId);
        
        // Leaderboard sıralamasını hesapla (her profil için)
        _calculateUserRank(targetUserId);
      } else {
        // Kullanıcı dokümanı yoksa varsayılan değerler
        setState(() {
          _userName = 'Kullanıcı';
          _userBio = '';
          _userInterests = [];
          _activityCount = 0;
          _followerCount = 0;
          _followingCount = 0;
          _isLoadingUserData = false;
        });
        
        // Aktivite sayısını dinamik olarak hesapla
        _calculateActivityCount(targetUserId);
      }
    } catch (e) {
      setState(() {
        _isLoadingUserData = false;
      });
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

  // Negatif değerleri 0'a çeviren yardımcı fonksiyon
  int _ensureNonNegative(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value < 0 ? 0 : value;
    if (value is double) return value < 0 ? 0 : value.toInt();
    return 0;
  }

  // Aktivite sayısını dinamik olarak hesapla
  Future<void> _calculateActivityCount(String userId) async {
    try {
      // Kullanıcının userActivities array'ini al
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (userDoc.exists) {
        final userData = userDoc.data();
        final userActivities = userData?['myActivities'] as List<dynamic>? ?? [];
        final activityCount = userActivities.length;
        
        setState(() {
          _activityCount = activityCount;
        });
        
        // Sadece kendi aktivite sayısını güncelle
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null && currentUser.uid == userId) {
          try {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .update({
              'activityCount': activityCount,
              'activityCountUpdatedAt': FieldValue.serverTimestamp(),
            });
          } catch (updateError) {
            print('Aktivite sayısı güncellenirken hata: $updateError');
            // Bu hata kritik değil, sadece UI'da göster
          }
        }
      } else {
        setState(() {
          _activityCount = 0;
        });
      }
      
    } catch (e) {
      print('Aktivite sayısı hesaplanırken hata: $e');
      // Hata durumunda mevcut değeri koru
    }
  }

  // Kullanıcının leaderboard sıralamasını hesapla
  Future<void> _calculateUserRank(String userId) async {
    try {
      // Tüm kullanıcıları çek ve likes alanına göre sırala
      QuerySnapshot usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();
      
      Map<String, int> userLikeCounts = {};
      
      for (var userDoc in usersSnapshot.docs) {
        String currentUserId = userDoc.id;
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        
        // likes alanını al
        int likes = userData['likes'] ?? 0;
        
        if (likes > 0) {
          userLikeCounts[currentUserId] = likes;
        }
      }
      
      // En çok like alan kullanıcıları sırala
      var sortedUsers = userLikeCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      // Kullanıcının sıralamasını bul
      int rank = 0;
      for (int i = 0; i < sortedUsers.length; i++) {
        if (sortedUsers[i].key == userId) {
          rank = i + 1;
          break;
        }
      }
      
      setState(() {
        _userRank = rank;
      });
      
      print('Kullanıcı $userId sıralaması: $rank');
    } catch (e) {
      print('Kullanıcı sıralaması hesaplama hatası: $e');
    }
  }

  // Mevcut kullanıcının negatif sayılarını düzelt
  Future<void> _fixNegativeCounts() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid);
      
      final userDoc = await userRef.get();
      if (!userDoc.exists) return;

      final userData = userDoc.data()!;
      bool needsUpdate = false;
      Map<String, dynamic> updates = {};

      // Negatif değerleri kontrol et ve düzelt
      final activityCount = _ensureNonNegative(userData['activityCount']);
      final followerCount = _ensureNonNegative(userData['followerCount']);
      final followingCount = _ensureNonNegative(userData['followingCount']);

      if (userData['activityCount'] != activityCount) {
        updates['activityCount'] = activityCount;
        needsUpdate = true;
      }
      if (userData['followerCount'] != followerCount) {
        updates['followerCount'] = followerCount;
        needsUpdate = true;
      }
      if (userData['followingCount'] != followingCount) {
        updates['followingCount'] = followingCount;
        needsUpdate = true;
      }

      // Güncelleme gerekliyse yap
      if (needsUpdate) {
        await userRef.update(updates);
        print('Negatif değerler düzeltildi: $updates');
      }
    } catch (e) {
      print('Negatif değerler düzeltilirken hata: $e');
    }
  }

  Future<void> _loadUserPosts() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Hangi kullanıcının postlarını yükleyeceğimizi belirle
      final targetUserId = widget.targetUserId ?? currentUser.uid;
      
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(targetUserId)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data();
        final posts = userData?['posts'] as List<dynamic>? ?? [];
        
        setState(() {
          _userPosts = posts.cast<String>();
          _isLoadingPosts = false;
        });
      } else {
        setState(() {
          _userPosts = [];
          _isLoadingPosts = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingPosts = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Postlar yüklenirken hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _checkFollowStatus() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || widget.targetUserId == null) return;

      final currentUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (currentUserDoc.exists) {
        final userData = currentUserDoc.data();
        final following = userData?['following'] as List<dynamic>? ?? [];
        
        setState(() {
          _isFollowing = following.contains(widget.targetUserId);
        });
      }
    } catch (e) {
      print('Takip durumu kontrol edilirken hata: $e');
    }
  }

  Future<void> _toggleFollow() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || widget.targetUserId == null) return;

      // Kendini takip etmeyi engelle
      if (currentUser.uid == widget.targetUserId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kendinizi takip edemezsiniz'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      setState(() {
        _isLoadingFollow = true;
      });

      final currentUserRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid);
      
      final targetUserRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.targetUserId!);

      if (_isFollowing) {
        // Takibi bırak
        await currentUserRef.set({
          'following': FieldValue.arrayRemove([widget.targetUserId]),
        }, SetOptions(merge: true));
        
        await targetUserRef.set({
          'followers': FieldValue.arrayRemove([currentUser.uid]),
        }, SetOptions(merge: true));
        
        // Sayıları güvenli şekilde güncelle
        await _updateFollowCounts(currentUserRef, targetUserRef, -1);
        
        setState(() {
          _isFollowing = false;
          _followerCount = _ensureNonNegative(_followerCount - 1);
        });
      } else {
        // Takip et
        await currentUserRef.set({
          'following': FieldValue.arrayUnion([widget.targetUserId]),
        }, SetOptions(merge: true));
        
        await targetUserRef.set({
          'followers': FieldValue.arrayUnion([currentUser.uid]),
        }, SetOptions(merge: true));
        
        // Sayıları güvenli şekilde güncelle
        await _updateFollowCounts(currentUserRef, targetUserRef, 1);
        
        setState(() {
          _isFollowing = true;
          _followerCount++;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Takip işlemi sırasında hata oluştu: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoadingFollow = false;
      });
    }
  }

  // Takip sayılarını güvenli şekilde güncelleyen fonksiyon
  Future<void> _updateFollowCounts(DocumentReference currentUserRef, DocumentReference targetUserRef, int increment) async {
    try {
      // Mevcut değerleri al
      final currentUserDoc = await currentUserRef.get();
      final targetUserDoc = await targetUserRef.get();
      
      final currentUserData = currentUserDoc.data() as Map<String, dynamic>?;
      final targetUserData = targetUserDoc.data() as Map<String, dynamic>?;
      
      final currentFollowingCount = _ensureNonNegative(currentUserData?['followingCount']);
      final targetFollowerCount = _ensureNonNegative(targetUserData?['followerCount']);
      
      // Yeni değerleri hesapla
      final newCurrentFollowingCount = _ensureNonNegative(currentFollowingCount + increment);
      final newTargetFollowerCount = _ensureNonNegative(targetFollowerCount + increment);
      
      // Güvenli şekilde güncelle
      await currentUserRef.update({
        'followingCount': newCurrentFollowingCount,
      });
      
      await targetUserRef.update({
        'followerCount': newTargetFollowerCount,
      });
    } catch (e) {
      print('Takip sayıları güncellenirken hata: $e');
    }
  }

  Future<void> _pickProfileImage() async {
    try {
      // Sadece kendi profiliyse profil fotoğrafı değiştirebilir
      if (!_isOwnProfile) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sadece kendi profilinizin fotoğrafını değiştirebilirsiniz'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      
      if (image != null) {
        await _uploadProfileImage(image);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profil fotoğrafı seçilirken hata oluştu: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _uploadProfileImage(XFile image) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      print('Profil fotoğrafı yükleme başlıyor...');
      print('Kullanıcı UID: ${user.uid}');

      // Firebase Storage reference - /profile_photos klasörüne kaydet
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${user.uid}_profile_$timestamp.jpg';
      print('Dosya yolu: profile_photos/$fileName');

      // Loading göster
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_photos')
          .child(fileName);

      // Upload image with timeout
      if (kIsWeb) {
        // Web için bytes upload
        final bytes = await image.readAsBytes();
        print('Web: Profil fotoğrafı boyutu: ${bytes.length} bytes');
        final metadata = SettableMetadata(
          contentType: 'image/jpeg',
          cacheControl: 'max-age=31536000',
        );
        await ref.putData(bytes, metadata).timeout(const Duration(seconds: 30));
      } else {
        // Mobile için file upload
        final file = File(image.path);
        final fileSize = await file.length();
        print('Mobil: Profil fotoğrafı boyutu: $fileSize bytes');
        final metadata = SettableMetadata(
          contentType: 'image/jpeg',
          cacheControl: 'max-age=31536000',
        );
        await ref.putFile(file, metadata).timeout(const Duration(seconds: 30));
      }

      // Download URL al
      print('Profil fotoğrafı upload tamamlandı, URL alınıyor...');
      final downloadUrl = await ref.getDownloadURL().timeout(const Duration(seconds: 10));

      // Firestore'da kullanıcının profil fotoğrafını güncelle
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'profileImageUrl': downloadUrl,
        'profileImageUpdatedAt': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 10));

      // Dialog'u kapat
      if (mounted) Navigator.pop(context);

      // Başarı mesajı
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil fotoğrafı başarıyla güncellendi!'),
          backgroundColor: Colors.green,
        ),
      );

      // Profil fotoğrafını güncelle
      setState(() {
        _profileImageUrl = downloadUrl;
      });

      print('Profil fotoğrafı başarıyla yüklendi: $downloadUrl');

    } catch (e) {
      // Dialog'u kapat
      if (mounted) Navigator.pop(context);
      
      print('Profil fotoğrafı yükleme hatası: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profil fotoğrafı yüklenirken hata oluştu: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickImages() async {
    try {
      // Sadece kendi profiliyse fotoğraf seçebilir
      if (!_isOwnProfile) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sadece kendi profilinize fotoğraf ekleyebilirsiniz'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final List<XFile> images = await _picker.pickMultiImage();
      if (images.isNotEmpty) {
        setState(() {
          _selectedImages = images;
        });
        _showImagePreview();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fotoğraf seçilirken hata oluştu: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showImagePreview() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: double.infinity,
          height: 500,
          decoration: BoxDecoration(
            color: const Color(0xFF1C1B29),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF007AFF).withOpacity(0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF007AFF).withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 15,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Başlık
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: const Color(0xFF007AFF).withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                ),
                child: Text(
                  'Fotoğraf Önizleme',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFFFFFFFF),
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
              ),
              // Resim alanı
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E1E3A).withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF007AFF).withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: PageView.builder(
                      itemCount: _selectedImages.length,
                      itemBuilder: (context, index) {
                        if (kIsWeb) {
                          // Web için XFile'dan bytes kullan
                          return FutureBuilder<Uint8List>(
                            future: _selectedImages[index].readAsBytes(),
                            builder: (context, snapshot) {
                              if (snapshot.hasData) {
                                return Image.memory(
                                  snapshot.data!,
                                  fit: BoxFit.cover,
                                );
                              } else if (snapshot.hasError) {
                                return Container(
                                  color: const Color(0xFF0E1E3A),
                                  child: const Center(
                                    child: Icon(
                                      Icons.error,
                                      color: Color(0xFFFF3B30),
                                      size: 50,
                                    ),
                                  ),
                                );
                              } else {
                                return Container(
                                  color: const Color(0xFF0E1E3A),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      color: Color(0xFF007AFF),
                                    ),
                                  ),
                                );
                              }
                            },
                          );
                        } else {
                          // Mobile için File kullan
                          return Image.file(
                            File(_selectedImages[index].path),
                            fit: BoxFit.cover,
                          );
                        }
                      },
                    ),
                  ),
                ),
              ),
              // Butonlar
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1C1B29), Color(0xFF0E1E3A)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF007AFF).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            setState(() {
                              _selectedImages.clear();
                            });
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFFFFFFF),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'İptal',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF007AFF), Color(0xFF4DD0E1)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF007AFF).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _shareImages();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Paylaş',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openSettings() {
    // Ayarlar sayfasına git
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SettingsPage(),
      ),
    );
  }

  Future<void> _editBio() async {
    // Sadece kendi profiliyse bio düzenleyebilir
    if (!_isOwnProfile) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sadece kendi profilinizin bio\'sunu düzenleyebilirsiniz'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final TextEditingController bioController = TextEditingController(text: _userBio);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1B29),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Bio Düzenle',
          style: GoogleFonts.poppins(
            color: const Color(0xFFFFFFFF),
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
            maxWidth: MediaQuery.of(context).size.width * 0.9,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0E1E3A).withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF007AFF).withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: TextField(
                controller: bioController,
                maxLines: 4,
                maxLength: 150,
                style: GoogleFonts.poppins(
                  color: const Color(0xFFFFFFFF),
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'Kendinizi tanıtın...',
                  hintStyle: GoogleFonts.poppins(
                    color: const Color(0xFFFFFFFF).withOpacity(0.6),
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                  counterStyle: GoogleFonts.poppins(
                    color: const Color(0xFFFFFFFF).withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
                onChanged: (value) {
                  setState(() {});
                },
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0E1E3A).withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF007AFF).withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Text(
                '${bioController.text.length}/150',
                style: GoogleFonts.poppins(
                  color: const Color(0xFFFFFFFF).withOpacity(0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF007AFF),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text(
              'İptal',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF007AFF), Color(0xFF4DD0E1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF007AFF).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _updateBio(bioController.text);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Kaydet',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateBio(String newBio) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Loading göster
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Firestore'da bio'yu güncelle
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({
        'bio': newBio,
        'bioUpdatedAt': FieldValue.serverTimestamp(),
      });

      // Dialog'u kapat
      if (mounted) Navigator.pop(context);

      // Başarı mesajı
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bio başarıyla güncellendi!'),
          backgroundColor: Colors.green,
        ),
      );

      // Bio'yu güncelle
      setState(() {
        _userBio = newBio;
      });

    } catch (e) {
      // Dialog'u kapat
      if (mounted) Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bio güncellenirken hata oluştu: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _openChat() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || widget.targetUserId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kullanıcı girişi yapılmamış'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Kendi profiliyse mesaj gönderemez
      if (currentUser.uid == widget.targetUserId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kendinize mesaj gönderemezsiniz'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Loading göster
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Sohbet ID'sini oluştur (küçük ID önce gelir)
      final userIds = [currentUser.uid, widget.targetUserId!];
      userIds.sort();
      final chatId = '${userIds[0]}_${userIds[1]}';

      // Sohbet dokümanının var olup olmadığını kontrol et
      final chatDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .get();

      if (!chatDoc.exists) {
        // Yeni sohbet oluştur
        await FirebaseFirestore.instance
            .collection('chats')
            .doc(chatId)
            .set({
          'participants': [currentUser.uid, widget.targetUserId!],
          'participantNames': [currentUser.displayName ?? 'Kullanıcı', _userName],
          'lastMessage': '',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // Dialog'u kapat
      if (mounted) Navigator.pop(context);

      // Chat sayfasına git
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatPage(
              otherUserId: widget.targetUserId!,
              otherUserName: _userName,
            ),
          ),
        );
      }
    } catch (e) {
      // Dialog'u kapat
      if (mounted) Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Chat açılırken hata oluştu: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _shareImages() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kullanıcı girişi yapılmamış'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Sadece kendi profiliyse fotoğraf yükleyebilir
      if (!_isOwnProfile) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sadece kendi profilinize fotoğraf ekleyebilirsiniz'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      print('Profile fotoğraf paylaşma başlıyor... ${_selectedImages.length} resim');

      // Loading göster
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      List<String> newImageUrls = [];

      // Her fotoğrafı Firebase Storage'a yükle
      for (int i = 0; i < _selectedImages.length; i++) {
        try {
          print('Profile resim $i yükleniyor...');
          final image = _selectedImages[i];
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final fileName = '${user.uid}_${timestamp}_$i.jpg';
          
          // Firebase Storage reference - /post_images klasörüne kaydet
          final ref = FirebaseStorage.instance
              .ref()
              .child('post_images')
              .child(fileName);

          // Upload image with timeout
          if (kIsWeb) {
            // Web için bytes upload
            final bytes = await image.readAsBytes();
            print('Web: Profile resim boyutu: ${bytes.length} bytes');
            final metadata = SettableMetadata(
              contentType: 'image/jpeg',
              cacheControl: 'max-age=31536000',
            );
            await ref.putData(bytes, metadata).timeout(const Duration(seconds: 30));
          } else {
            // Mobile için file upload
            final file = File(image.path);
            final fileSize = await file.length();
            print('Mobil: Profile resim boyutu: $fileSize bytes');
            final metadata = SettableMetadata(
              contentType: 'image/jpeg',
              cacheControl: 'max-age=31536000',
            );
            await ref.putFile(file, metadata).timeout(const Duration(seconds: 30));
          }

          // Download URL al
          print('Profile resim $i upload tamamlandı, URL alınıyor...');
          final downloadUrl = await ref.getDownloadURL().timeout(const Duration(seconds: 10));
          newImageUrls.add(downloadUrl);
          print('Profile resim $i başarıyla yüklendi: $downloadUrl');
        } catch (e) {
          print('Profile resim $i yüklenirken hata: $e');
          // Tek resim hatası tüm işlemi durdurmasın
          continue;
        }
      }

      if (newImageUrls.isEmpty) {
        throw Exception('Hiçbir resim yüklenemedi');
      }

      print('Profile resimler yüklendi, Firestore güncelleniyor...');

      // Kullanıcının mevcut postlarını al
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 10));

      List<String> existingPosts = [];
      if (userDoc.exists) {
        final userData = userDoc.data();
        existingPosts = (userData?['posts'] as List<dynamic>? ?? [])
            .cast<String>();
      }

      // Yeni postları mevcut listeye ekle
      existingPosts.addAll(newImageUrls);

      // Kullanıcının users koleksiyonundaki posts array'ini güncelle
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'posts': existingPosts,
        'lastPostUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true))
          .timeout(const Duration(seconds: 10));

      // Dialog'u kapat
      if (mounted) Navigator.pop(context);

      // Başarı mesajı
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${newImageUrls.length} fotoğraf başarıyla paylaşıldı!'),
          backgroundColor: Colors.green,
        ),
      );

      // Postları yeniden yükle
      await _loadUserPosts();

    } catch (e) {
      // Dialog'u kapat
      if (mounted) Navigator.pop(context);
      
      print('Profile fotoğraf paylaşma hatası: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fotoğraf yüklenirken hata oluştu: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Profil sayfası için sıralama rozeti widget'ı
  Widget _buildProfileRankBadge(int rank) {
    String badgeText;
    IconData badgeIcon;
    
    switch (rank) {
      case 1:
        badgeText = '1st';
        badgeIcon = Icons.emoji_events;
        break;
      case 2:
        badgeText = '2nd';
        badgeIcon = Icons.emoji_events;
        break;
      case 3:
        badgeText = '3rd';
        badgeIcon = Icons.emoji_events;
        break;
      case 4:
        badgeText = '4th';
        badgeIcon = Icons.star;
        break;
      case 5:
        badgeText = '5th';
        badgeIcon = Icons.star;
        break;
      default:
        badgeText = '#$rank';
        badgeIcon = Icons.star;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B35), Color(0xFFFF3B30)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B35).withOpacity(0.4),
            blurRadius: 12,
            spreadRadius: 2,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            badgeIcon,
            size: 16,
            color: const Color(0xFFFFFFFF),
          ),
          const SizedBox(width: 4),
          Text(
            badgeText,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFFFFFFF),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1C1B29), // Deep purple
                Color(0xFF0E1E3A), // Navy blue
              ],
            ),
          ),
        ),
        automaticallyImplyLeading: false,
        leading: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 0),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF1C1B29).withOpacity(0.9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF007AFF).withOpacity(0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF007AFF).withOpacity(0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
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
                color: Color(0xFFFFFFFF),
                size: 20,
              ),
            ),
          ),
        ),
        title: Text(
          'Profil',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 24,
            color: const Color(0xFFFFFFFF),
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 0),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                if (_isOwnProfile) ...[
                  // Kendi profiliyse fotoğraf ekleme butonu
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: const Color(0xFFFF6B35).withOpacity(0.2),
                      border: Border.all(
                        color: const Color(0xFFFF6B35).withOpacity(0.4),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF6B35).withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 2),
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: _pickImages,
                      icon: const Icon(
                        Icons.add_photo_alternate,
                        color: Color(0xFFFFFFFF),
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ] else ...[
                  // Başkasının profiliyse mesaj butonu
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: const Color(0xFF007AFF).withOpacity(0.2),
                      border: Border.all(
                        color: const Color(0xFF007AFF).withOpacity(0.4),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF007AFF).withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 2),
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: _openChat,
                      icon: const Icon(
                        Icons.message,
                        color: Color(0xFFFFFFFF),
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (_isOwnProfile) ...[
                  // Kendi profiliyse ayarlar ikonu
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: const Color(0xFF1C1B29).withOpacity(0.8),
                      border: Border.all(
                        color: const Color(0xFFFFFFFF).withOpacity(0.2),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFFFFF).withOpacity(0.1),
                          blurRadius: 12,
                          offset: const Offset(0, 2),
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: () {
                        // Ayarlar sayfasına git
                        _openSettings();
                      },
                      icon: const Icon(
                        Icons.settings,
                        color: Color(0xFFFFFFFF),
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        centerTitle: false,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0A0A0A), // Near black
              Color(0xFF1C1B29), // Deep purple
              Color(0xFF0E1E3A), // Navy blue
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profil Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1B29).withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF007AFF).withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF007AFF).withOpacity(0.2),
                    blurRadius: 25,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Profil Fotoğrafı
                  Stack(
                    children: [
                      GestureDetector(
                        onTap: _isOwnProfile ? _pickProfileImage : null,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF0E1E3A).withOpacity(0.5),
                            border: Border.all(
                              color: const Color(0xFFFF6B35),
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF6B35).withOpacity(0.4),
                                blurRadius: 15,
                                offset: const Offset(0, 0),
                              ),
                            ],
                          ),
                          child: _profileImageUrl != null
                              ? ClipOval(
                                  child: Image.network(
                                    _profileImageUrl!,
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Container(
                                        width: 100,
                                        height: 100,
                                        color: const Color(0xFF0E1E3A).withOpacity(0.5),
                                        child: const Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFFFF6B35),
                                          ),
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Icon(
                                        Icons.person,
                                        size: 50,
                                        color: Color(0xFFFF6B35),
                                      );
                                    },
                                  ),
                                )
                              : const Icon(
                                  Icons.person,
                                  size: 50,
                                  color: Color(0xFFFF6B35),
                                ),
                        ),
                      ),
                      // Sadece kendi profiliyse kamera ikonu göster
                      if (_isOwnProfile)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF6B35),
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFFFFFFF), width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF6B35).withOpacity(0.5),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Color(0xFFFFFFFF),
                              size: 16,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Kullanıcı Adı ve Sıralama Rozeti
                  if (_isLoadingUserData)
                    Container(
                      height: 24,
                      width: 150,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _userName,
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFFFFFFF),
                            letterSpacing: 0.5,
                          ),
                        ),
                        if (_userRank > 0) ...[
                          const SizedBox(width: 8),
                          _buildProfileRankBadge(_userRank),
                        ],
                      ],
                    ),
                  const SizedBox(height: 16),
                  
                  // Bio
                  if (_isLoadingUserData)
                    Container(
                      height: 20,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    )
                  else if (_userBio.isNotEmpty || _isOwnProfile)
                    GestureDetector(
                      onTap: _isOwnProfile ? _editBio : null,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _isOwnProfile ? const Color(0xFF007AFF).withOpacity(0.1) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: _isOwnProfile ? Border.all(color: const Color(0xFF007AFF).withOpacity(0.3)) : null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _userBio.isEmpty && _isOwnProfile ? 'Bio eklemek için tıklayın' : _userBio,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: _userBio.isEmpty && _isOwnProfile ? const Color(0xFFFFFFFF).withOpacity(0.6) : const Color(0xFFFFFFFF).withOpacity(0.9),
                                      fontStyle: _userBio.isEmpty && _isOwnProfile ? FontStyle.italic : FontStyle.normal,
                                    ),
                                  ),
                                ),
                                if (_isOwnProfile)
                                  Icon(
                                    Icons.edit,
                                    size: 16,
                                    color: const Color(0xFF007AFF),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  
                  // İlgi Alanları İkonları
                  if (_userInterests.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _userInterests.map((interestId) {
                          final category = _interestCategories.firstWhere(
                            (cat) => cat['id'] == interestId,
                            orElse: () => {'id': '', 'name': '', 'icon': Icons.help, 'color': Colors.grey},
                          );
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0E1E3A).withOpacity(0.8),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF007AFF).withOpacity(0.4),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF007AFF).withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  category['icon'],
                                  size: 16,
                                  color: const Color(0xFFFFFFFF),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  category['name'],
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: const Color(0xFFFFFFFF),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  const SizedBox(height: 16),
                  // İstatistikler
                  if (_isLoadingUserData)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatItemSkeleton(),
                        _buildStatItemSkeleton(),
                        _buildStatItemSkeleton(),
                      ],
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatItem('Aktiviteler', _activityCount.toString()),
                        _buildStatItem('Takipçiler', _followerCount.toString()),
                        _buildStatItem('Takip', _followingCount.toString()),
                      ],
                    ),
                  const SizedBox(height: 16),
                  // Takip butonu (sadece başkasının profiliyse ve kendisi değilse)
                  if (!_isOwnProfile && widget.targetUserId != FirebaseAuth.instance.currentUser?.uid)
                    SizedBox(
                      width: double.infinity,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: _isFollowing 
                              ? const LinearGradient(
                                  colors: [Color(0xFFFF3B30), Color(0xFFFF6B35)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : const LinearGradient(
                                  colors: [Color(0xFF007AFF), Color(0xFF4DD0E1)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: _isFollowing 
                                  ? const Color(0xFFFF3B30).withOpacity(0.4)
                                  : const Color(0xFF007AFF).withOpacity(0.4),
                              blurRadius: 15,
                              offset: const Offset(0, 4),
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isLoadingFollow ? null : _toggleFollow,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                            child: _isLoadingFollow
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Color(0xFFFFFFFF),
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                _isFollowing ? 'Takibi Bırak' : 'Takip Et',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFFFFFFF),
                                  letterSpacing: 0.5,
                                ),
                              ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Instagram benzeri grid layout
            _buildInstagramGrid(),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFFFFFFFF),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: const Color(0xFFFFFFFF).withOpacity(0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStatItemSkeleton() {
    return Column(
      children: [
        Container(
          height: 20,
          width: 30,
          decoration: BoxDecoration(
            color: const Color(0xFF1C1B29).withOpacity(0.6),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 14,
          width: 60,
          decoration: BoxDecoration(
            color: const Color(0xFF1C1B29).withOpacity(0.6),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }

  Widget _buildInstagramGrid() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1B29).withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF007AFF).withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF007AFF).withOpacity(0.2),
            blurRadius: 25,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tab bar (Instagram benzeri)
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: const Color(0xFF007AFF).withOpacity(0.3)),
                ),
              ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: const Color(0xFFFF6B35), width: 2),
                    ),
                  ),
                  child: const Icon(
                    Icons.grid_on,
                    color: Color(0xFFFF6B35),
                    size: 24,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Icon(
                    Icons.person_pin_circle_outlined,
                    color: const Color(0xFFFFFFFF).withOpacity(0.4),
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        
        // Grid layout
        if (_isLoadingPosts)
          Container(
            height: 200,
            child: const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFF6B35),
              ),
            ),
          )
        else if (_userPosts.isEmpty)
          Container(
            height: 200,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.photo_library_outlined,
                    size: 60,
                    color: const Color(0xFFFFFFFF).withOpacity(0.4),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Henüz fotoğraf paylaşılmamış',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: const Color(0xFFFFFFFF).withOpacity(0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'İlk fotoğrafınızı paylaşmak için + butonuna tıklayın',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: const Color(0xFFFFFFFF).withOpacity(0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, // 3'ten 2'ye düşürdük
              crossAxisSpacing: 8, // 2'den 8'e çıkardık
              mainAxisSpacing: 8, // 2'den 8'e çıkardık
              childAspectRatio: 1.0, // Kare şeklinde
            ),
            itemCount: _userPosts.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () {
                  _showImageDialog(_userPosts, index);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E1E3A).withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12), // Yuvarlatılmış köşeler
                    border: Border.all(
                      color: const Color(0xFF007AFF).withOpacity(0.2),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF007AFF).withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12), // Image için de yuvarlatılmış köşeler
                    child: Image.network(
                      _userPosts[index],
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: const Color(0xFF0E1E3A).withOpacity(0.8),
                          child: const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: Color(0xFFFF6B35),
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: const Color(0xFF0E1E3A).withOpacity(0.8),
                          child: const Icon(
                            Icons.broken_image,
                            color: Color(0xFFFFFFFF),
                            size: 48,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    ),
    );
  }

  // Fotoğraf silme fonksiyonu
  Future<void> _deleteImage(int index) async {
    try {
      // Onay dialog'u göster
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1C1B29),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Fotoğrafı Sil',
            style: GoogleFonts.poppins(
              color: const Color(0xFFFFFFFF),
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
          content: Text(
            'Bu fotoğrafı silmek istediğinizden emin misiniz?',
            style: GoogleFonts.poppins(
              color: const Color(0xFFFFFFFF).withOpacity(0.8),
              fontSize: 14,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF007AFF),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: Text(
                'İptal',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF3B30), Color(0xFFFF6B35)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF3B30).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Sil',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Loading göster
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            color: Color(0xFFFF6B35),
          ),
        ),
      );

      // Fotoğrafı listeden kaldır
      final imageUrl = _userPosts[index];
      final updatedPosts = List<String>.from(_userPosts);
      updatedPosts.removeAt(index);

      // Firestore'da posts array'ini güncelle
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'posts': updatedPosts,
        'lastPostUpdate': FieldValue.serverTimestamp(),
      });

      // Firebase Storage'dan fotoğrafı sil
      try {
        final ref = FirebaseStorage.instance.refFromURL(imageUrl);
        await ref.delete();
        print('Fotoğraf Firebase Storage\'dan silindi: $imageUrl');
      } catch (e) {
        print('Firebase Storage\'dan silme hatası: $e');
        // Storage hatası kritik değil, devam et
      }

      // Dialog'u kapat
      if (mounted) Navigator.pop(context);

      // Başarı mesajı
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fotoğraf başarıyla silindi!'),
          backgroundColor: Colors.green,
        ),
      );

      // Postları yeniden yükle
      await _loadUserPosts();

    } catch (e) {
      // Dialog'u kapat
      if (mounted) Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fotoğraf silinirken hata oluştu: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showImageDialog(List<String> images, int initialIndex) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: const Color(0xFF0A0A0A).withOpacity(0.95),
            child: Stack(
              children: [
                // Arka plan - tıklanabilir
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: Colors.transparent,
                  ),
                ),
                // Ana resim
                Center(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 3.0,
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.95,
                        maxHeight: MediaQuery.of(context).size.height * 0.85,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          images[initialIndex],
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              width: 300,
                              height: 300,
                              color: const Color(0xFF1C1B29),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const CircularProgressIndicator(
                                      color: Color(0xFFFF6B35),
                                      strokeWidth: 3,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Yükleniyor...',
                                      style: TextStyle(
                                        color: const Color(0xFFFFFFFF),
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 300,
                              height: 300,
                              color: const Color(0xFF1C1B29),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.broken_image,
                                    size: 64,
                                    color: Color(0xFFFFFFFF),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Fotoğraf yüklenemedi',
                                    style: TextStyle(
                                      color: Color(0xFFFFFFFF),
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Lütfen tekrar deneyin',
                                    style: TextStyle(
                                      color: const Color(0xFFFFFFFF).withOpacity(0.6),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                // Modern kapatma butonu
                Positioned(
                  top: MediaQuery.of(context).padding.top + 20,
                  right: 20,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1B29).withOpacity(0.8),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFFF6B35).withOpacity(0.4),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF6B35).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Color(0xFFFFFFFF),
                        size: 28,
                      ),
                    ),
                  ),
                ),
                // Silme butonu (sadece kendi profiliyse)
                if (_isOwnProfile)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 20,
                    left: 20,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop(); // Dialog'u kapat
                        _deleteImage(initialIndex); // Silme işlemini başlat
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF3B30).withOpacity(0.9),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.delete,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                // Resim sayısı göstergesi (birden fazla resim varsa)
                if (images.length > 1)
                  Positioned(
                    bottom: MediaQuery.of(context).padding.bottom + 30,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C1B29).withOpacity(0.9),
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(
                            color: const Color(0xFF007AFF).withOpacity(0.4),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF007AFF).withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          '${initialIndex + 1} / ${images.length}',
                          style: const TextStyle(
                            color: Color(0xFFFFFFFF),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
