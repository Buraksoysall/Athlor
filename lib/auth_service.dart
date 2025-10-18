import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // 07.10.2025 tarihini DateTime olarak tanımla
  static final DateTime _emailVerificationCutoffDate = DateTime(2025, 10, 7);
  
  /// Kullanıcının email doğrulaması gerekip gerekmediğini kontrol eder
  bool requiresEmailVerification(User user) {
    // Kullanıcının hesap oluşturma tarihi
    final creationTime = user.metadata.creationTime;
    
    if (creationTime == null) {
      // Eğer creation time null ise, güvenlik için doğrulama iste
      return true;
    }
    
    // 07.10.2025'ten sonra oluşturulan hesaplar için email doğrulaması gerekli
    return creationTime.isAfter(_emailVerificationCutoffDate);
  }
  
  /// Email doğrulama maili gönderir
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      // E-posta dilini TR olarak ayarla (platforma göre bazen gerekli)
      try {
        await _auth.setLanguageCode('tr');
      } catch (_) {}
      await user.sendEmailVerification();
    }
  }
  
  /// Kullanıcının email doğrulama durumunu kontrol eder
  Future<bool> isEmailVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    
    // Firebase'den güncel bilgileri al
    await user.reload();
    final refreshedUser = _auth.currentUser;
    
    return refreshedUser?.emailVerified ?? false;
  }
  
  /// Kullanıcının giriş yapıp yapamayacağını kontrol eder
  Future<bool> canUserLogin(User user) async {
    // Email doğrulaması gerekmeyen kullanıcılar (eski kullanıcılar)
    if (!requiresEmailVerification(user)) {
      return true;
    }
    
    // Yeni kullanıcılar için email doğrulaması kontrolü
    await user.reload();
    final refreshedUser = _auth.currentUser;
    return refreshedUser?.emailVerified ?? false;
  }
  
  /// Kayıt işlemi - email doğrulama maili gönderir
  Future<UserCredential> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required String username,
  }) async {
    try {
      // Firebase Auth ile kullanıcı oluştur
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      final User? user = userCredential.user;
      if (user != null) {
        // Email doğrulama maili gönder (TR dili garanti)
        await sendEmailVerification();
        
        // Kullanıcı profilini güncelle
        await user.updateDisplayName(name);
        
        // Firestore'da kullanıcı belgesi oluştur
        await _firestore.collection('users').doc(user.uid).set({
          'name': name,
          'username': username,
          'email': email,
          'createdAt': FieldValue.serverTimestamp(),
          'emailVerified': false,
          'privacyPolicyAccepted': true, // Kayıt sırasında kabul edildiği varsayılır
        });
      }
      
      return userCredential;
    } catch (e) {
      rethrow;
    }
  }
  
  /// Giriş işlemi - email doğrulama kontrolü ile
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      final User? user = userCredential.user;
      if (user != null) {
        // Kullanıcının giriş yapıp yapamayacağını kontrol et
        final canLogin = await canUserLogin(user);
        
        if (!canLogin) {
          throw FirebaseAuthException(
            code: 'email-not-verified',
            message: 'Email adresinizi doğrulamanız gerekiyor.',
          );
        }
        
        // Firestore'da emailVerified durumunu güncelle
        if (user.emailVerified) {
          await _firestore.collection('users').doc(user.uid).update({
            'emailVerified': true,
          });
        }
      }
      
      return userCredential;
    } catch (e) {
      rethrow;
    }
  }
  
  /// Çıkış işlemi
  Future<void> signOut() async {
    await _auth.signOut();
  }
  
  /// Mevcut kullanıcıyı döndürür
  User? get currentUser => _auth.currentUser;
  
  /// Auth state değişikliklerini dinler
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}
