import 'package:hive/hive.dart';

class ReportService {
  final Box _box = Hive.box('reports');

  void submitReport(String reporterUUID, String targetUUID) {
    List<String> currentReports = List<String>.from(_box.get(targetUUID, defaultValue: <String>[]));
    if (!currentReports.contains(reporterUUID)) {
      currentReports.add(reporterUUID);
      _box.put(targetUUID, currentReports);
    }
  }

  int submitSpaceReport(String spaceId, String reporterUUID) {
    final key = 'space:$spaceId';
    List<String> currentReports = List<String>.from(_box.get(key, defaultValue: <String>[]));
    if (!currentReports.contains(reporterUUID)) {
      currentReports.add(reporterUUID);
      _box.put(key, currentReports);
    }
    return currentReports.length;
  }

  bool isExposed(String targetUUID) {
    List<String> reporters = List<String>.from(_box.get(targetUUID, defaultValue: <String>[]));
    return reporters.length >= 3;
  }
}
