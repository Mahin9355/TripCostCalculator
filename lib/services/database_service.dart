import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ... (createTour and addDeposit remain unchanged) ...
  // Re-paste them if you deleted them, or just keep them as is.

  // 1. ADD DEPOSIT (Keep this)
  Future<void> addDeposit(String tourId, String memberId, double amount) async {
    await _db.collection('tours').doc(tourId).collection('deposits').add({
      'member_id': memberId,
      'amount': amount,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
  // Add a new member to an existing tour
  Future<void> addMemberToRunningTour(String tourId, String memberName) async {
    await _db.collection('tours').doc(tourId).collection('members').add({
      'name': memberName,
      'role': 'member', // Default role
      'joined_at': FieldValue.serverTimestamp(), // useful for sorting
      'is_active': true, // Important for the "Left" feature
    });
  }
  Future<void> linkMemberToUser(String tourId, String memberDocId, String realUserId) async {
    // 1. Tag the specific member entry with the UID
    await _db.collection('tours').doc(tourId).collection('members').doc(memberDocId).update({
      'linked_uid': realUserId, // This connects "Sajal" to "User XYZ"
    });

    // 2. Add to the main Tour document's access list
    // This allows you to write a query like: collection('tours').where('access_ids', arrayContains: myUid)
    await _db.collection('tours').doc(tourId).update({
      'access_ids': FieldValue.arrayUnion([realUserId])
    });
  }

  // 2. CREATE TOUR (Keep this)
// 2. CREATE TOUR (FIXED & COMPLETE)
  Future<void> createTour(String tourName, String managerName, List<String> otherMembers) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // 1. Create the Tour Document
    DocumentReference tourRef = _db.collection('tours').doc();

    await tourRef.set({
      'tour_name': tourName,
      'manager_name': managerName,
      'created_at': FieldValue.serverTimestamp(),
      'access_ids': [user.uid], // CRITICAL: Gives you permission to see this tour
    });

    // 2. Add Manager to members sub-collection (Linked to UID)
    await tourRef.collection('members').add({
      'name': managerName,
      'role': 'manager',
      'joined_at': FieldValue.serverTimestamp(),
      'linked_uid': user.uid, // CRITICAL: Links "Mahin" to your Login ID
    });

    // 3. Add Other Members
    for (String memberName in otherMembers) {
      await tourRef.collection('members').add({
        'name': memberName,
        'role': 'member',
        'joined_at': FieldValue.serverTimestamp(),
      });
    }
  }
  // ---------------------------------------------------------
  // NEW: USER MANAGEMENT (From ER Diagram)
  // ---------------------------------------------------------
  Future<void> createUserData(User user, String name, String mobile, String district) async {
    // This matches your ER Diagram 'User' entity
    await _db.collection('users').doc(user.uid).set({
      'user_id': user.uid,
      'user_name': name,
      'mobile_number': mobile,
      'home_district': district,
      'email': user.email,
      'created_at': FieldValue.serverTimestamp(),
    });

    // Also update the Auth profile display name for easy access
    await user.updateDisplayName(name);
  }

  Future<Map<String, dynamic>?> getUserData(String uid) async {
    var doc = await _db.collection('users').doc(uid).get();
    return doc.data();
  }


  // 3. ADD EXPENSE (Unchanged signature, but logic changes downstream)
  Future<void> addExpense(String tourId, String description, double totalAmount, Map<String, double> payers, List<String> beneficiaryIds) async {
    // payers can now look like: {'fund': 2000, 'member_id_1': 500}
    await _db.collection('tours').doc(tourId).collection('expenses').add({
      'description': description,
      'total_amount': totalAmount,
      'payers': payers,
      'beneficiaries': beneficiaryIds,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // 4. CALCULATE TOUR (UPDATED for Hybrid Payments)
  Future<Map<String, dynamic>> calculateTour(String tourId) async {
    Map<String, Map<String, dynamic>> memberStats = {};

    double fundTotalCollected = 0.0;
    double fundTotalSpent = 0.0; // Expenses paid by 'fund'

    // A. Init members
    var memberSnap = await _db.collection('tours').doc(tourId).collection('members').get();
    for (var doc in memberSnap.docs) {
      memberStats[doc.id] = {
        'name': doc['name'],
        'given': 0.0, // Deposits + Personal Payments
        'spent': 0.0, // Consumption
      };
    }

    // B. Process DEPOSITS
    var depositSnap = await _db.collection('tours').doc(tourId).collection('deposits').get();
    for (var doc in depositSnap.docs) {
      String mId = doc['member_id'];
      double amount = (doc['amount'] as num).toDouble();

      fundTotalCollected += amount;
      if (memberStats.containsKey(mId)) {
        memberStats[mId]!['given'] += amount;
      }
    }

    // C. Process EXPENSES (The Hybrid Logic)
    var expenseSnap = await _db.collection('tours').doc(tourId).collection('expenses').get();
    for (var doc in expenseSnap.docs) {
      double totalAmt = (doc['total_amount'] as num).toDouble();
      Map<String, dynamic> payers = doc['payers']; // e.g. {'fund': 500, 'mem1': 200}
      List<dynamic> beneficiaries = doc['beneficiaries'];

      // 1. Credit the Payers
      payers.forEach((payerId, amount) {
        double amt = (amount as num).toDouble();

        if (payerId == 'fund') {
          // Money left the manager's box
          fundTotalSpent += amt;
        } else {
          // Money left a person's pocket (Credit them)
          if (memberStats.containsKey(payerId)) {
            memberStats[payerId]!['given'] += amt;
          }
        }
      });

      // 2. Debit the Consumers
      if (beneficiaries.isNotEmpty) {
        double costPerPerson = totalAmt / beneficiaries.length;
        for (var beneficiaryId in beneficiaries) {
          if (memberStats.containsKey(beneficiaryId)) {
            memberStats[beneficiaryId]!['spent'] += costPerPerson;
          }
        }
      }
    }

    // D. Final List
    List<Map<String, dynamic>> memberResults = [];
    memberStats.forEach((id, stats) {
      memberResults.add({
        'name': stats['name'],
        'given': stats['given'],
        'spent': stats['spent'],
        'balance': stats['given'] - stats['spent'],
      });
    });

    return {
      'member_stats': memberResults,
      'fund_stats': {
        'collected': fundTotalCollected,
        'spent': fundTotalSpent,
        'remaining': fundTotalCollected - fundTotalSpent,
      }
    };
  }

  // 5. DELETE TOUR (Keep this)
  Future<void> deleteTour(String tourId) async {
    var members = await _db.collection('tours').doc(tourId).collection('members').get();
    for (var doc in members.docs) await doc.reference.delete();
    var deposits = await _db.collection('tours').doc(tourId).collection('deposits').get();
    for (var doc in deposits.docs) await doc.reference.delete();
    var expenses = await _db.collection('tours').doc(tourId).collection('expenses').get();
    for (var doc in expenses.docs) await doc.reference.delete();
    await _db.collection('tours').doc(tourId).delete();
  }
}
