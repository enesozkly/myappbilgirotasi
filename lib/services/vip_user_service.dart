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
    String? serverVerificationData,
    String? localVerificationData,
    String? source,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('VIP kaydedilemedi. Kullanıcı giriş yapmamış.');
    }

    if (purchaseId.trim().isEmpty &&
        (serverVerificationData == null || serverVerificationData.trim().isEmpty)) {
      throw Exception('Satın alma doğrulama bilgisi boş geldi. VIP aktif edilmedi.');
    }

    final DateTime now = DateTime.now();
    final DateTime expiresAt = _calculateVipExpireDate(planKey, now);
    final String monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    final DocumentReference<Map<String, dynamic>> userRef =
        _firestore.collection('users').doc(user.uid);

    await _firestore.runTransaction((Transaction tx) async {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await tx.get(userRef);
      final Map<String, dynamic> oldData = snapshot.data() ?? <String, dynamic>{};

      tx.set(
        userRef,
        <String, dynamic>{
          'uid': user.uid,
          'email': user.email ?? oldData['email'] ?? '',
          'vipActive': true,
          'isVip': true,
          'vipPlan': planKey,
          'vipProductId': productId,
          'vipPurchaseId': purchaseId,
          'vipSource': source ?? 'store',
          'vipStartedAt': Timestamp.fromDate(now),
          'vipActivatedAt': FieldValue.serverTimestamp(),
          'vipExpiresAt': Timestamp.fromDate(expiresAt),
          'vipUpdatedAt': FieldValue.serverTimestamp(),
          'maxEnergy': 100,
          'energy': 100,
          'vipWeakTopicRights': 4,
          'vipTestRights': 4,
          'vipPdfRights': 1,
          'vipRightsMonth': monthKey,
        },
        SetOptions(merge: true),
      );

      final DocumentReference<Map<String, dynamic>> purchaseRef = userRef
          .collection('vip_purchases')
          .doc(purchaseId.isNotEmpty ? purchaseId : productId);

      tx.set(
        purchaseRef,
        <String, dynamic>{
          'productId': productId,
          'planKey': planKey,
          'purchaseId': purchaseId,
          'serverVerificationData': serverVerificationData ?? '',
          'localVerificationData': localVerificationData ?? '',
          'source': source ?? 'store',
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
          'expiresAt': Timestamp.fromDate(expiresAt),
        },
        SetOptions(merge: true),
      );
    });
  }

  Future<bool> isVipActive() async {
    final User? user = _auth.currentUser;
    if (user == null) return false;

    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await _firestore.collection('users').doc(user.uid).get();
    return _isActive(snapshot.data());
  }

  Stream<bool> vipActiveStream() {
    final User? user = _auth.currentUser;
    if (user == null) return Stream<bool>.value(false);

    return _firestore.collection('users').doc(user.uid).snapshots().map(
          (DocumentSnapshot<Map<String, dynamic>> snapshot) =>
              _isActive(snapshot.data()),
        );
  }

  Future<void> deactivateVipForTest() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('VIP kapatılamadı. Kullanıcı giriş yapmamış.');
    }

    await _firestore.collection('users').doc(user.uid).set(
      <String, dynamic>{
        'vipActive': false,
        'isVip': false,
        'maxEnergy': 50,
        'energy': 50,
        'vipWeakTopicRights': 0,
        'vipTestRights': 0,
        'vipPdfRights': 0,
        'vipExpiresAt': null,
        'vipUpdatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  bool _isActive(Map<String, dynamic>? data) {
    if (data == null) return false;
    final bool flag = data['isVip'] == true || data['vipActive'] == true;
    if (!flag) return false;

    final dynamic expiresAt = data['vipExpiresAt'];
    if (expiresAt is Timestamp && expiresAt.toDate().isBefore(DateTime.now())) {
      return false;
    }
    return true;
  }

  DateTime _calculateVipExpireDate(String planKey, DateTime from) {
    switch (planKey) {
      case 'yearly':
        return DateTime(from.year + 1, from.month, from.day, from.hour, from.minute);
      case 'three_months':
        return DateTime(from.year, from.month + 3, from.day, from.hour, from.minute);
      case 'monthly':
      default:
        return DateTime(from.year, from.month + 1, from.day, from.hour, from.minute);
    }
  }
}
