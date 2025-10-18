import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'email_verification_page.dart';

class TermsOfUsePage extends StatefulWidget {
  const TermsOfUsePage({super.key});

  @override
  State<TermsOfUsePage> createState() => _TermsOfUsePageState();
}

class _TermsOfUsePageState extends State<TermsOfUsePage> {
  bool _accepted = false;
  bool _loading = false;

  Future<void> _accept() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _loading = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'eulaAccepted': true,
        'eulaAcceptedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (mounted) {
        // EULA kabul edildikten sonra email doğrulama durumuna göre yönlendir
        final isVerified = user.emailVerified == true;
        if (!isVerified) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const EmailVerificationPage()),
          );
        } else {
          Navigator.of(context).pushReplacementNamed('/home');
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Onay sırasında hata: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kullanım Şartları')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Terms of Use (EULA)',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: const Text(
                  'Athlor / FitMatch – Kullanım Şartları (EULA)\n\n'
                  '1) Sıfır Tolerans Politikası\n'
                  '- Uygulamada kullanıcı tarafından oluşturulan içeriklerin (mesajlar, yorumlar, aktiviteler ve medya) hukuka aykırı, hakaret içeren, nefret söylemi barındıran, taciz edici, müstehcen, şiddet içerikli veya başkalarının haklarını ihlal eden nitelikte olmasına kesinlikle TOLERANS GÖSTERİLMEZ.\n'
                  '- Bu şartları kabul ederek objeksiyonel/istismarcı içerik üretmeyeceğinizi ve diğer kullanıcılara saygılı davranacağınızı kabul edersiniz.\n\n'
                  '2) Raporlama ve Engelleme\n'
                  '- Uygulamada uygunsuz içerikleri "Raporla" özelliği ile şikayet edebilir, istismarcı kullanıcıları "Engelle" özelliği ile engelleyebilirsiniz.\n'
                  '- Engelleme, yalnızca engelleyen kullanıcı için geçerlidir; engellediğiniz kullanıcının içerikleri size gösterilmez.\n\n'
                  '3) Moderasyon ve 24 Saat İçinde Aksiyon\n'
                  '- Geliştirici ekip, şikayet edilen içerikleri en geç 24 saat içinde inceler. Gerekli görülmesi halinde içerik kaldırılır ve ihlalde bulunan kullanıcının hesabı kısıtlanır veya sonlandırılır.\n'
                  '- Moderasyon kapsamında, ihlal kayıtları ve yapılan işlemler denetim amacıyla saklanabilir.\n\n'
                  '4) Yaptırımlar\n'
                  '- İhlal tespitinde, içeriklerin kaldırılması, hesap kısıtlaması/sonlandırması, geçici veya kalıcı uzaklaştırma (ejection) gibi yaptırımlar uygulanabilir.\n'
                  '- Tekrarlanan veya ağır ihlallerde hesap kalıcı olarak kapatılabilir.\n\n'
                  '5) Özelliklerin Kötüye Kullanımı\n'
                  '- Raporlama ve engelleme özelliklerinin kötüye kullanılması (ör. spam raporlar) da yaptırım sebebidir.\n\n'
                  'Bu şartları kabul ederek, yukarıdaki politikalara uyacağınızı ve ihlal halinde belirtilen yaptırımları kabul ettiğinizi onaylarsınız.',
                ),
              ),
            ),
            Row(
              children: [
                Checkbox(value: _accepted, onChanged: (v) => setState(() => _accepted = v ?? false)),
                const Expanded(child: Text('Kullanım Şartları\'nı okudum ve kabul ediyorum.')),
              ],
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _accepted && !_loading ? _accept : null,
                child: _loading ? const CircularProgressIndicator() : const Text('Onayla ve Devam Et'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
