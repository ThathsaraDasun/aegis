import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/hazard_report_model.dart';

class RouteSafetyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Submit new hazard report to Firestore
  Future<void> reportHazard(HazardReportModel report) async {
    await _firestore.collection('hazard_reports').add(report.toMap());
  }

  // Stream nearby hazard reports
  Stream<List<HazardReportModel>> streamNearbyHazards() {
    return _firestore.collection('hazard_reports').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => HazardReportModel.fromMap(doc.id, doc.data())).toList());
  }

  // Route Safety Scoring Engine (0% - 100%)
  static double calculateSafetyScore({required int hazardCount, required double lightingRatio}) {
    double baseScore = 100.0;
    baseScore -= (hazardCount * 15.0);
    baseScore += (lightingRatio * 30.0);
    return baseScore.clamp(0.0, 100.0);
  }
}
