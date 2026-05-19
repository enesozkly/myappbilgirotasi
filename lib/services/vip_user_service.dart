import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VipUserService {
  VipUserService._();

  static final VipUserService instance = VipUserService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> activateVip({
    required String planKey,
    required String productId,
    required String purchaseId,
  }) async {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw Exception('VIP kaydedilemedi. Kullanici giris yapmamis.');
    }

    final DateTime now = DateTime.now();
    final DateTime expiresAt = _calculateVipExpireDate(planKey, now);

    await _firestore.collection('users').doc(user.uid).set(
      {
        // Yeni sistem alanları
        'vipActive': true,
        'vipPlan': planKey,
        'vipProductId': productId,
        'vipPurchaseId': purchaseId,
        'vipStartedAt': Timestamp.fromDate(now),
        'vipExpiresAt': Timestamp.fromDate(expiresAt),
        'vipUpdatedAt': FieldValue.serverTimestamp(),

        // Mevcut uygulamanın kullandığı alan
        // Mevcut uygulamanın kullandığı alanlar
        'isVip': true,
        'vipActivatedAt': FieldValue.serverTimestamp(),

// VIP kullanıcıya verilecek uygulama avantajları
        'maxEnergy': 100,
        'energy': 100,

// VIP aylık haklar
        'vipWeakTopicRights': 4,
        'vipTestRights': 4,
        'vipPdfRights': 1,
        'vipRightsMonth': '${now.year}-${now.month.toString().padLeft(2, '0')}',
      },
      SetOptions(merge: true),
    );
  }

  Future<bool> isVipActive() async {
    final User? user = _auth.currentUser;

    if (user == null) {
      return false;
    }

    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await _firestore.collection('users').doc(user.uid).get();

    final Map<String, dynamic>? data = snapshot.data();

    if (data == null) {
      return false;
    }

    return data['isVip'] == true || data['vipActive'] == true;
  }

  Stream<bool> vipActiveStream() {
    final User? user = _auth.currentUser;

    if (user == null) {
      return Stream<bool>.value(false);
    }

    return _firestore.collection('users').doc(user.uid).snapshots().map(
      (DocumentSnapshot<Map<String, dynamic>> snapshot) {
        final Map<String, dynamic>? data = snapshot.data();

        if (data == null) {
          return false;
        }

        return data['isVip'] == true || data['vipActive'] == true;
      },
    );
  }

  Future<void> deactivateVipForTest() async {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw Exception('VIP kapatilamadi. Kullanici giris yapmamis.');
    }

    await _firestore.collection('users').doc(user.uid).set(
      {
        'vipActive': false,
        'isVip': false,
        'maxEnergy': 50,
        'energy': 50,
        'vipWeakTopicRights': 0,
        'vipTestRights': 0,
        'vipPdfRights': 0,
        'vipUpdatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  DateTime _calculateVipExpireDate(String planKey, DateTime startDate) {
    switch (planKey) {
      case 'monthly':
        return DateTime(
          startDate.year,
          startDate.month + 1,
          startDate.day,
          startDate.hour,
          startDate.minute,
          startDate.second,
        );

      case 'three_months':
        return DateTime(
          startDate.year,
          startDate.month + 3,
          startDate.day,
          startDate.hour,
          startDate.minute,
          startDate.second,
        );

      case 'yearly':
        return DateTime(
          startDate.year + 1,
          startDate.month,
          startDate.day,
          startDate.hour,
          startDate.minute,
          startDate.second,
        );

      default:
        return DateTime(
          startDate.year,
          startDate.month + 1,
          startDate.day,
          startDate.hour,
          startDate.minute,
          startDate.second,
        );
    }
  }
}
