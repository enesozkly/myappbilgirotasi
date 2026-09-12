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
    required String planPrice,
    required String purchaseId,
    String? offerToken,
    String? serverVerificationData,
    String? localVerificationData,
    String? source,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('VIP kaydedilemedi. Kullanıcı giriş yapmamış.');
    }

    final DateTime now = DateTime.now();
    final DateTime expiresAt = _calculateVipExpireDate(planKey, now);
    final String planLabel = _planLabel(planKey);
    final int durationDays = expiresAt.difference(now).inDays;
    final String saleDocumentId = _saleDocumentId(
      uid: user.uid,
      productId: productId,
      purchaseId: purchaseId,
    );
    final WriteBatch batch = _firestore.batch();
    final DocumentReference<Map<String, dynamic>> userRef =
        _firestore.collection('users').doc(user.uid);
    final DocumentReference<Map<String, dynamic>> saleRef = _firestore
        .collection('admin_purchase_events')
        .doc(saleDocumentId);

    batch.set(
      userRef,
      {
        'vipActive': true,
        'vipPlan': planKey,
        'vipProductId': productId,
        'vipPurchaseId': purchaseId,
        'vipSource': source ?? 'unknown',
        'vipStartedAt': Timestamp.fromDate(now),
        'vipExpiresAt': Timestamp.fromDate(expiresAt),
        'vipUpdatedAt': FieldValue.serverTimestamp(),
        'vipServerVerificationData': serverVerificationData,
        'vipLocalVerificationData': localVerificationData,

        // Mevcut uygulamanın kullandığı alanlar.
        'isVip': true,
        'vipActivatedAt': FieldValue.serverTimestamp(),

        // VIP avantajları.
        'maxEnergy': 100,
        'energy': 100,

        // Aylık VIP hakları.
        'vipWeakTopicRights': 4,
        'vipTestRights': 1,
        'vipRightsMonth': '${now.year}-${now.month.toString().padLeft(2, '0')}',
      },
      SetOptions(merge: true),
    );

    // Satış ve VIP aktivasyonu aynı batch içinde yazılır. Böylece kullanıcı
    // VIP olup satışın admin paneline düşmemesi gibi yarım kayıt oluşmaz.
    batch.set(
      saleRef,
      {
        'trackingVersion': 2,
        'type': 'vip',
        'saleType': 'vip',
        'uid': user.uid,
        'name': user.displayName ?? '',
        'email': user.email ?? '',
        'productId': productId,
        'productTitle': planLabel,
        'planKey': planKey,
        'planLabel': planLabel,
        'durationDays': durationDays,
        'price': planPrice,
        'purchaseId': purchaseId,
        'offerToken': offerToken ?? '',
        'source': source ?? 'unknown',
        'status': 'purchased',
        'paymentStatus': 'paid',
        'paymentCompleted': true,
        'expiresAt': Timestamp.fromDate(expiresAt),
        'createdAt': FieldValue.serverTimestamp(),
        'purchasedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  Future<bool> isVipActive() async {
    final User? user = _auth.currentUser;
    if (user == null) return false;

    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await _firestore.collection('users').doc(user.uid).get();
    final Map<String, dynamic>? data = snapshot.data();
    if (data == null) return false;

    return data['isVip'] == true || data['vipActive'] == true;
  }

  Stream<bool> vipActiveStream() {
    final User? user = _auth.currentUser;
    if (user == null) return Stream<bool>.value(false);

    return _firestore.collection('users').doc(user.uid).snapshots().map(
      (DocumentSnapshot<Map<String, dynamic>> snapshot) {
        final Map<String, dynamic>? data = snapshot.data();
        if (data == null) return false;
        return data['isVip'] == true || data['vipActive'] == true;
      },
    );
  }

  Future<void> deactivateVipForTest() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('VIP kapatılamadı. Kullanıcı giriş yapmamış.');
    }

    await _firestore.collection('users').doc(user.uid).set(
      {
        'vipActive': false,
        'isVip': false,
        'maxEnergy': 50,
        'energy': 50,
        'vipWeakTopicRights': 0,
        'vipTestRights': 0,
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

  String _planLabel(String planKey) {
    switch (planKey) {
      case 'monthly':
        return 'Aylık VIP';
      case 'three_months':
        return '3 Aylık VIP';
      case 'yearly':
        return 'Yıllık VIP';
      default:
        return 'VIP';
    }
  }

  String _saleDocumentId({
    required String uid,
    required String productId,
    required String purchaseId,
  }) {
    // Firestore belge kimliğini kısa ve güvenli tutan deterministik FNV-1a.
    // Aynı mağaza işlemi tekrar bildirilirse yeni satış yerine aynı kayıt
    // güncellenir; böylece sayaçlar iki kez artmaz.
    final String input = '$uid|$productId|$purchaseId';
    int hash = 0xcbf29ce484222325;
    for (final int codeUnit in input.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }
    return 'vip_${uid}_${hash.toRadixString(16).padLeft(16, '0')}';
  }
}
