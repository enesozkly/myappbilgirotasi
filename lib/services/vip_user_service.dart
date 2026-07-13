import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Ücretli uygulama modelinde bütün giriş yapmış hesaplara Premium erişim verir.
class VipUserService {
  VipUserService._();

  static final VipUserService instance = VipUserService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _currentRightsMonth() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  Future<void> ensureUniversalVip() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final ref = _firestore.collection('users').doc(user.uid);
    final snapshot = await ref.get();
    final data = snapshot.data() ?? <String, dynamic>{};
    final monthKey = _currentRightsMonth();

    final updates = <String, dynamic>{
      'isVip': true,
      'vipActive': true,
      'vipNeverExpires': true,
      'vipPlan': 'paid_app_access',
      'vipPlanLabel': 'Premium Erişim',
      'vipSource': 'paid_app',
      'vipUpdatedAt': FieldValue.serverTimestamp(),
      'vipExpiresAt': FieldValue.delete(),
      'vipPdfRights': FieldValue.delete(),
      'vipTestRights': FieldValue.delete(),
    };

    final currentRights = data['vipWeakTopicRights'];
    final shouldResetRights =
        data['vipRightsMonth'] != monthKey || currentRights is! num;

    if (shouldResetRights) {
      updates['vipWeakTopicRights'] = 4;
      updates['vipRightsMonth'] = monthKey;
    }

    if (data['vipActivatedAt'] == null) {
      updates['vipActivatedAt'] = FieldValue.serverTimestamp();
    }

    await ref.set(updates, SetOptions(merge: true));
  }

  Future<void> activateVip({
    required String planKey,
    required String productId,
    required String purchaseId,
    String? serverVerificationData,
    String? localVerificationData,
    String? source,
  }) async {
    await ensureUniversalVip();
  }

  Future<bool> isVipActive() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    await ensureUniversalVip();
    return true;
  }

  Stream<bool> vipActiveStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream<bool>.value(false);

    return _firestore
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .map((_) => true);
  }

  Future<void> deactivateVipForTest() async {
    await ensureUniversalVip();
  }
}
