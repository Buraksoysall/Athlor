import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

class AddActivityPage extends StatefulWidget {
  const AddActivityPage({super.key});

  @override
  State<AddActivityPage> createState() => _AddActivityPageState();
}

class _AddActivityPageState extends State<AddActivityPage> {
  String? _selectedCategory;
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  dynamic _selectedImage; // Tek fotoğraf için File veya XFile
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  
  // Yeni eklenen alanlar
  bool _showInviteForm = false;
  final _maxParticipantsController = TextEditingController();
  String? _selectedCity;
  final _addressController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  // Kategori listesi
  final List<Map<String, dynamic>> _categories = [
    {'name': 'Tenis', 'icon': Icons.sports_tennis, 'color': const Color(0xFF8A2BE2), 'emoji': '🎾'},
    {'name': 'Futbol', 'icon': Icons.sports_soccer, 'color': const Color(0xFF007AFF), 'emoji': '⚽'},
    {'name': 'Basketbol', 'icon': Icons.sports_basketball, 'color': const Color(0xFFFF6B35), 'emoji': '🏀'},
    {'name': 'Voleybol', 'icon': Icons.sports_volleyball, 'color': const Color(0xFF8A2BE2), 'emoji': '🏐'},
    {'name': 'Boks', 'icon': Icons.sports_martial_arts, 'color': const Color(0xFFFF3B30), 'emoji': '🥊'},
    {'name': 'Fitness', 'icon': Icons.fitness_center, 'color': const Color(0xFF06B6D4), 'emoji': '💪'},
  ];

  // Türkiye şehirleri listesi
  final List<String> _cities = [
    'İstanbul', 'Ankara', 'İzmir', 'Bursa', 'Antalya', 'Adana', 'Konya', 'Gaziantep',
    'Şanlıurfa', 'Kocaeli', 'Mersin', 'Diyarbakır', 'Hatay', 'Manisa', 'Kayseri',
    'Samsun', 'Balıkesir', 'Kahramanmaraş', 'Van', 'Aydın', 'Tekirdağ', 'Sakarya',
    'Denizli', 'Muğla', 'Eskişehir', 'Trabzon', 'Ordu', 'Afyon', 'Malatya', 'Erzurum',
    'Elazığ', 'Adapazarı', 'Tokat', 'Sivas', 'Çorum', 'Zonguldak', 'Kütahya', 'Osmaniye',
    'Çanakkale', 'Düzce', 'Isparta', 'Mardin', 'Kırıkkale', 'Uşak', 'Giresun', 'Aksaray',
    'Nevşehir', 'Niğde', 'Kırşehir', 'Kırklareli', 'Edirne', 'Karabük', 'Bartın', 'Kastamonu',
    'Sinop', 'Çankırı', 'Yozgat', 'Amasya', 'Sivas', 'Gümüşhane', 'Bayburt', 'Artvin',
    'Rize', 'Ardahan', 'Iğdır', 'Kars', 'Ağrı', 'Muş', 'Bitlis', 'Siirt', 'Batman',
    'Şırnak', 'Hakkâri', 'Tunceli', 'Bingöl', 'Bingöl', 'Erzincan', 'Bilecik', 'Yalova',
    'Kilis', 'Düzce', 'Bolu', 'Çankırı', 'Kırklareli', 'Tekirdağ', 'Edirne', 'Kırklareli'
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _maxParticipantsController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _selectCategory(String category) {
    setState(() {
      _selectedCategory = category;
    });
  }

  // Tarih seçici
  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // Saat seçici
  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  // Aktivite sayısını güncelle (sadece kendi oluşturduğu aktivitelerin sayısı)
  Future<void> _updateActivityCount(String userId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || currentUser.uid != userId) {
        print('Kullanıcı kendi aktivite sayısını güncelleyemez');
        return;
      }

      // Kullanıcının oluşturduğu aktivitelerin sayısını al
      final activitiesSnapshot = await FirebaseFirestore.instance
          .collection('activities')
          .where('createdBy', isEqualTo: userId)
          .get();
      
      final activityCount = activitiesSnapshot.docs.length;
      
      // Firestore'da aktivite sayısını güncelle
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'activityCount': activityCount,
        'activityCountUpdatedAt': FieldValue.serverTimestamp(),
      });
      
    } catch (e) {
      print('Aktivite sayısı güncellenirken hata: $e');
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          if (kIsWeb) {
            _selectedImage = image; // Web'de XFile kullan
          } else {
            _selectedImage = File(image.path); // Mobil'de File kullan
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fotoğraf seçilirken hata oluştu: $e'),
          backgroundColor: const Color(0xFFFF3B30),
        ),
      );
    }
  }

  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          if (kIsWeb) {
            _selectedImage = image; // Web'de XFile kullan
          } else {
            _selectedImage = File(image.path); // Mobil'de File kullan
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kameradan fotoğraf alınırken hata oluştu: $e'),
          backgroundColor: const Color(0xFFFF3B30),
        ),
      );
    }
  }

  // Firebase Storage bağlantısını test et
  Future<void> _testFirebaseStorage() async {
    try {
      print('Firebase Storage test ediliyor...');
      final testRef = FirebaseStorage.instance.ref().child('test/test.txt');
      final testData = 'Test data';
      await testRef.putString(testData).timeout(const Duration(seconds: 10));
      print('Firebase Storage bağlantısı başarılı!');
      await testRef.delete(); // Test dosyasını sil
    } catch (e) {
      print('Firebase Storage bağlantı hatası: $e');
    }
  }


  Future<String?> _uploadImage() async {
    if (_selectedImage == null) return null;
    
    try {
      print('Fotoğraf yükleme başlıyor...');
      final fileName = 'activity_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref().child('activity_images/$fileName');
      
      UploadTask uploadTask;
      if (kIsWeb) {
        // Web için XFile kullan
        final xFile = _selectedImage as XFile;
        final bytes = await xFile.readAsBytes();
        print('Web: Fotoğraf boyutu: ${bytes.length} bytes');
        final metadata = SettableMetadata(
          contentType: 'image/jpeg',
          cacheControl: 'max-age=31536000',
        );
        uploadTask = ref.putData(bytes, metadata);
      } else {
        // Mobil için File kullan
        final file = _selectedImage as File;
        final fileSize = await file.length();
        print('Mobil: Fotoğraf boyutu: $fileSize bytes');
        final metadata = SettableMetadata(
          contentType: 'image/jpeg',
          cacheControl: 'max-age=31536000',
        );
        uploadTask = ref.putFile(file, metadata);
      }
      
      // Upload progress takibi
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        print('Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
      });
      
      print('Upload task başlatıldı, bekleniyor...');
      final snapshot = await uploadTask;
      print('Upload tamamlandı, URL alınıyor...');
      final downloadUrl = await snapshot.ref.getDownloadURL();
      print('Fotoğraf başarıyla yüklendi: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('Fotoğraf yüklenirken hata: $e');
      throw Exception('Fotoğraf yüklenirken hata oluştu: $e');
    }
  }


  Future<void> _addActivity() async {
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen bir spor kategorisi seçin'),
          backgroundColor: const Color(0xFFFF3B30),
        ),
      );
      return;
    }

    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen aktivite başlığı girin'),
          backgroundColor: const Color(0xFFFF3B30),
        ),
      );
      return;
    }


    setState(() {
      _isUploading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kullanıcı girişi yapılmamış'),
            backgroundColor: const Color(0xFFFF3B30),
          ),
        );
        return;
      }

      // Tarih ve saati belirle
      DateTime activityDateTime;
      if (_showInviteForm && _selectedDate != null) {
        // Davet formu aktifse ve tarih seçilmişse
        final selectedDate = _selectedDate!;
        final selectedTime = _selectedTime ?? TimeOfDay.now();
        activityDateTime = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          selectedTime.hour,
          selectedTime.minute,
        );
      } else {
        // Normal aktivite için şu anki tarih ve saat
        activityDateTime = DateTime.now();
      }

      // Kullanıcı adını basit şekilde al
      final userName = user.displayName ?? 
                     user.email?.split('@')[0] ?? 
                     'Kullanıcı';
      
      // Fotoğraf yükleme işlemi
      String? imageUrl;
      if (_selectedImage != null) {
        try {
          print('Fotoğraf yükleme başlatılıyor...');
          
          // Önce Firebase Storage bağlantısını test et
          await _testFirebaseStorage();
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Fotoğraf yükleniyor...'),
              backgroundColor: const Color(0xFF007AFF),
              duration: Duration(seconds: 1),
            ),
          );
          
          // Daha uzun timeout ve progress göster
          imageUrl = await _uploadImage().timeout(const Duration(seconds: 30));
          
          print('Fotoğraf yükleme başarılı: $imageUrl');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Fotoğraf başarıyla yüklendi!'),
              backgroundColor: const Color(0xFF8A2BE2),
              duration: Duration(seconds: 1),
            ),
          );
        } catch (e) {
          print('Fotoğraf yükleme hatası: $e');
          // Fotoğraf yüklenemezse devam et
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Fotoğraf yüklenemedi: ${e.toString()}'),
              backgroundColor: const Color(0xFFFF6B35),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }

      // Aktivite verilerini hazırla
      final maxParticipants = _maxParticipantsController.text.isNotEmpty 
          ? int.tryParse(_maxParticipantsController.text) ?? 20
          : 20;
      
      final activityData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': _selectedCategory,
        'categoryTag': _selectedCategory!.toLowerCase().replaceAll(' ', '_'),
        'dateTime': activityDateTime,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': user.uid,
        'createdByEmail': user.email,
        'createdByName': userName,
        'participants': [user.uid], // Oluşturan kişi otomatik katılımcı
        'maxParticipants': maxParticipants,
        'status': 'active', // active, cancelled, completed
        'media': imageUrl != null ? [imageUrl] : [], // Yüklenen fotoğraf URL'i
        'mediaCount': imageUrl != null ? 1 : 0, // Fotoğraf sayısı
        'isInviteEnabled': _showInviteForm, // İnsanları davet etme özelliği aktif mi
        'city': _selectedCity ?? '', // Seçilen şehir
        'address': _addressController.text.trim(), // Detaylı adres
        'location': {
          'city': _selectedCity ?? '',
          'address': _addressController.text.trim(),
        },
      };

      // Firestore'a aktivite ekle
      final docRef = await FirebaseFirestore.instance
          .collection('activities')
          .add(activityData)
          .timeout(const Duration(seconds: 10));

      // Kullanıcı dokümanını güncelle (opsiyonel)
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'myJoinedActivities': FieldValue.arrayUnion([docRef.id]),
        }).timeout(const Duration(seconds: 5));
      } catch (e) {
        print('Kullanıcı dokümanı güncellenemedi: $e');
        // Bu hata kritik değil, devam et
      }

      // Aktivite sayısını güncelle (opsiyonel)
      try {
        await _updateActivityCount(user.uid);
      } catch (e) {
        print('Aktivite sayısı güncellenemedi: $e');
        // Bu hata kritik değil, devam et
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aktivite başarıyla oluşturuldu!'),
          backgroundColor: const Color(0xFF8A2BE2),
        ),
      );

      // Ana sayfaya geri dön
      Navigator.pop(context);
    } catch (e) {
      print('Aktivite eklenirken hata: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Aktivite eklenirken hata oluştu: $e'),
          backgroundColor: const Color(0xFFFF3B30),
        ),
      );
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1B29),
        automaticallyImplyLeading: false,
        leading: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 0),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0E1E3A).withOpacity(0.8),
              border: Border.all(color: const Color(0xFF8A2BE2).withOpacity(0.3), width: 2),
              borderRadius: BorderRadius.circular(12),
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
                Icons.arrow_back_rounded,
                color: Color(0xFFFFFFFF),
                size: 20,
              ),
              style: IconButton.styleFrom(
                backgroundColor: Colors.transparent,
                minimumSize: const Size(44, 44),
              ),
            ),
          ),
        ),
        centerTitle: true,
        elevation: 0,
        title: const Text(
          'Yeni Aktivite',
          style: TextStyle(
            color: Color(0xFFFFFFFF),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Kategori seçimi
            const Text(
              'Spor Kategorisi Seçin',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFFFFFFFF),
              ),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 3.0,
              ),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = _selectedCategory == category['name'];
                
                return GestureDetector(
                  onTap: () => _selectCategory(category['name']),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? category['color'] 
                          : const Color(0xFF1C1B29),
                      borderRadius: BorderRadius.circular(8),
                      border: isSelected
                          ? Border.all(color: category['color'], width: 2)
                          : Border.all(color: const Color(0xFF8A2BE2).withOpacity(0.3), width: 1),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: category['color'].withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          Icon(
                            category['icon'],
                            color: isSelected 
                                ? Colors.white 
                                : const Color(0xFFFFFFFF),
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  category['emoji'],
                                  style: const TextStyle(fontSize: 14),
                                ),
                                Flexible(
                                  child: Text(
                                    category['name'],
                                    style: TextStyle(
                                      color: isSelected 
                                          ? Colors.white 
                                          : const Color(0xFFFFFFFF),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
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
              },
            ),
            const SizedBox(height: 24),
            
            // Aktivite başlığı
            const Text(
              'Aktivite Başlığı',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFFFFFFFF),
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _titleController,
              style: const TextStyle(color: Color(0xFFFFFFFF)),
              decoration: InputDecoration(
                hintText: 'Örn: Hafta Sonu Futbol Turnuvası',
                hintStyle: TextStyle(color: const Color(0xFFFFFFFF).withOpacity(0.5)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: const Color(0xFF8A2BE2).withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF8A2BE2), width: 2),
                ),
                filled: true,
                fillColor: const Color(0xFF1C1B29),
              ),
            ),
            const SizedBox(height: 16),
            
            // Medya ekleme
            const Text(
              'Medya Ekle',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFFFFFFFF),
              ),
            ),
            const SizedBox(height: 8),
            
            // Seçilen fotoğrafı göster
            if (_selectedImage != null) ...[
              Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF8A2BE2).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: kIsWeb
                          ? Image.network(
                              (_selectedImage as XFile).path,
                              width: double.infinity,
                              height: 200,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: double.infinity,
                                  height: 200,
                                  color: const Color(0xFF1C1B29),
                                  child: const Icon(Icons.error, size: 48, color: Color(0xFFFF3B30)),
                                );
                              },
                            )
                          : Image.file(
                              _selectedImage as File,
                              width: double.infinity,
                              height: 200,
                              fit: BoxFit.cover,
                            ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedImage = null;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF3B30),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Medya ekleme butonları
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1B29),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF8A2BE2).withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: const Color(0xFF8A2BE2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.photo_library,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Galeri',
                            style: TextStyle(
                              color: const Color(0xFFFFFFFF).withOpacity(0.7),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: _pickImageFromCamera,
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1B29),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF8A2BE2).withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: const Color(0xFF007AFF),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Kamera',
                            style: TextStyle(
                              color: const Color(0xFFFFFFFF).withOpacity(0.7),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Açıklama
            const Text(
              'Açıklama',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFFFFFFFF),
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              style: const TextStyle(color: Color(0xFFFFFFFF)),
              decoration: InputDecoration(
                hintText: 'Aktivite hakkında detaylı bilgi...',
                hintStyle: TextStyle(color: const Color(0xFFFFFFFF).withOpacity(0.5)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: const Color(0xFF8A2BE2).withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF8A2BE2), width: 2),
                ),
                filled: true,
                fillColor: const Color(0xFF1C1B29),
              ),
            ),
            const SizedBox(height: 24),
            
            // İnsanları Davet Et Butonu
            Container(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _showInviteForm = !_showInviteForm;
                  });
                },
                icon: Icon(
                  _showInviteForm ? Icons.people_alt : Icons.people_outline,
                  color: _showInviteForm ? Colors.white : const Color(0xFF8A2BE2),
                ),
                label: Text(
                  _showInviteForm ? 'Davet Formunu Gizle' : 'İnsanları Davet Et',
                  style: TextStyle(
                    color: _showInviteForm ? Colors.white : const Color(0xFF8A2BE2),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _showInviteForm ? const Color(0xFF8A2BE2) : const Color(0xFF1C1B29),
                  foregroundColor: const Color(0xFF8A2BE2),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: const Color(0xFF8A2BE2),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
            
            // Davet Formu (gizli/görünür)
            if (_showInviteForm) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1B29),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF8A2BE2).withOpacity(0.3), width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Maksimum Katılımcı Sayısı
                    const Text(
                      'Maksimum Katılımcı Sayısı',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFFFFFF),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _maxParticipantsController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Color(0xFFFFFFFF)),
                      decoration: InputDecoration(
                        hintText: 'Örn: 10',
                        hintStyle: TextStyle(color: const Color(0xFFFFFFFF).withOpacity(0.5)),
                        suffixText: 'kişi',
                        suffixStyle: TextStyle(color: const Color(0xFFFFFFFF).withOpacity(0.7)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: const Color(0xFF8A2BE2).withOpacity(0.3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF8A2BE2), width: 2),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF0E1E3A).withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Tarih ve Saat Seçimi
                    const Text(
                      'Aktivite Tarihi ve Saati',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFFFFFF),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: _selectDate,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color(0xFF8A2BE2).withOpacity(0.3)),
                                borderRadius: BorderRadius.circular(12),
                                color: const Color(0xFF0E1E3A).withOpacity(0.8),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today, color: const Color(0xFF8A2BE2), size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    _selectedDate != null 
                                        ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                                        : 'Tarih Seç',
                                    style: TextStyle(
                                      color: _selectedDate != null ? const Color(0xFFFFFFFF) : const Color(0xFFFFFFFF).withOpacity(0.5),
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: _selectTime,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color(0xFF8A2BE2).withOpacity(0.3)),
                                borderRadius: BorderRadius.circular(12),
                                color: const Color(0xFF0E1E3A).withOpacity(0.8),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.access_time, color: const Color(0xFF8A2BE2), size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    _selectedTime != null 
                                        ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}'
                                        : 'Saat Seç',
                                    style: TextStyle(
                                      color: _selectedTime != null ? const Color(0xFFFFFFFF) : const Color(0xFFFFFFFF).withOpacity(0.5),
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Şehir Seçimi
                    const Text(
                      'Şehir',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFFFFFF),
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        String? selectedCity = await showDialog<String>(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              backgroundColor: const Color(0xFF1C1B29),
                              title: const Text(
                                'Şehir Seçin',
                                style: TextStyle(color: Color(0xFFFFFFFF)),
                              ),
                              content: SizedBox(
                                width: double.maxFinite,
                                height: 300,
                                child: ListView.builder(
                                  itemCount: _cities.length,
                                  itemBuilder: (context, index) {
                                    return ListTile(
                                      title: Text(
                                        _cities[index],
                                        style: const TextStyle(color: Color(0xFFFFFFFF)),
                                      ),
                                      onTap: () {
                                        Navigator.of(context).pop(_cities[index]);
                                      },
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                        );
                        if (selectedCity != null) {
                          setState(() {
                            _selectedCity = selectedCity;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0E1E3A).withOpacity(0.8),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF8A2BE2).withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _selectedCity ?? 'Şehir seçin',
                                style: TextStyle(
                                  color: _selectedCity != null 
                                      ? const Color(0xFFFFFFFF) 
                                      : const Color(0xFFFFFFFF).withOpacity(0.5),
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.arrow_drop_down,
                              color: Color(0xFFFFFFFF),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Detaylı Adres
                    const Text(
                      'Detaylı Adres',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFFFFFF),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _addressController,
                      maxLines: 2,
                      style: const TextStyle(color: Color(0xFFFFFFFF)),
                      decoration: InputDecoration(
                        hintText: 'Mahalle, sokak, bina no vb. detaylı bilgi...',
                        hintStyle: TextStyle(color: const Color(0xFFFFFFFF).withOpacity(0.5)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: const Color(0xFF8A2BE2).withOpacity(0.3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF8A2BE2), width: 2),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF0E1E3A).withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 32),
            
            // Aktivite ekle butonu
            Container(
              width: double.infinity,
              height: 56,
              margin: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 16, // Extra padding for navigation bar
              ),
              child: ElevatedButton(
                onPressed: _isUploading ? null : _addActivity,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8A2BE2),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  shadowColor: const Color(0xFF8A2BE2).withOpacity(0.3),
                ),
                child: _isUploading
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Yükleniyor...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : const Text(
                        'Aktivite Ekle',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }
}

