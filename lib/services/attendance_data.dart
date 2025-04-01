import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class AttendanceData {
  static final AttendanceData _instance = AttendanceData._internal();
  factory AttendanceData() => _instance;
  AttendanceData._internal();

  Map<String, Map<String, Map<String, bool>>> _attendance = {};
  Map<String, Map<String, String>> _studentInfo = {};

  Map<String, Map<String, Map<String, bool>>> get attendance => _attendance;

  Future<void> initializeGroup(String groupId, List<Map<String, String>> students) async {
    _attendance[groupId] ??= {};
    _studentInfo[groupId] ??= {};
    
    for (var student in students) {
      final name = student['name'] ?? '';
      final regNo = student['regNo'] ?? '';
      if (name.isNotEmpty && regNo.isNotEmpty) {
        _attendance[groupId]![name] ??= {};
        _studentInfo[groupId]![name] = regNo;
      }
    }
    await _saveData();
  }

  Future<void> toggleAttendance(String groupId, String studentName, bool isPresent) async {
    final date = DateTime.now().toIso8601String().split('T')[0];
    _attendance[groupId] ??= {};
    _attendance[groupId]![studentName] ??= {};
    _attendance[groupId]![studentName]![date] = isPresent;
    await _saveData(); // Save data immediately after toggling
    await calculateAndStorePercentages(groupId); // Recalculate percentages
  }

  Future<void> resetTodayAttendance(String groupId) async {
    final date = DateTime.now().toIso8601String().split('T')[0];
    _attendance[groupId]?.forEach((studentName, records) {
      records[date] = false; // Reset today's attendance to false
    });
    await _saveData(); // Save the reset data
  }

  Future<void> saveAttendance(String groupId, Map<String, bool> attendanceData) async {
    final date = DateTime.now().toIso8601String().split('T')[0];
    _attendance[groupId] ??= {};

    attendanceData.forEach((studentName, isPresent) {
      _attendance[groupId]![studentName] ??= {};
      _attendance[groupId]![studentName]![date] = isPresent;
    });

    await _saveData();
    await calculateAndStorePercentages(groupId); // Recalculate percentages
  }

  Future<void> calculateAndStorePercentages(String groupId) async {
    final records = _attendance[groupId] ?? {};
    final percentages = <String, double>{};

    records.forEach((name, attendance) {
      final total = attendance.length;
      final presentCount = attendance.values.where((v) => v).length;
      percentages[name] = total == 0 ? 0.0 : (presentCount / total) * 100;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('percentages_$groupId', jsonEncode(percentages));
  }

  Future<Map<String, double>> getStoredPercentages(String groupId) async {
    final prefs = await SharedPreferences.getInstance();
    final percentagesJson = prefs.getString('percentages_$groupId');
    return percentagesJson == null ? {} : Map<String, double>.from(jsonDecode(percentagesJson));
  }

  Map<String, bool> getGroupAttendance(String groupId) {
    final date = DateTime.now().toIso8601String().split('T')[0];
    return _attendance[groupId]?.map((name, records) {
      final regNo = getRegNo(groupId, name) ?? "N/A";
      return MapEntry('$name ($regNo)', records[date] ?? false); // Include regNo
    }) ?? {};
  }

  Map<String, double> getAttendancePercentages(String groupId) {
    final result = <String, double>{};
    final records = _attendance[groupId] ?? {};
    
    records.forEach((name, attendance) {
      final total = attendance.length;
      result[name] = total == 0 ? 0.0 : (attendance.values.where((v) => v).length / total) * 100;
    });
    
    return result;
  }

  Future<void> deleteGroup(String groupId) async {
    _attendance.remove(groupId);
    _studentInfo.remove(groupId);
    await _saveData(); // Ensure changes are saved persistently
  }

  Future<void> deleteStudent(String groupId, String studentName) async {
    _attendance[groupId]?.remove(studentName);
    _studentInfo[groupId]?.remove(studentName);
    await _saveData(); // Ensure changes are saved persistently
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      _attendance = _decodeMap(prefs.getString('attendance_data')) as Map<String, Map<String, Map<String, bool>>>;
      _studentInfo = _decodeMap(prefs.getString('student_info'))
          .map((key, value) => MapEntry(key, Map<String, String>.from(value))); // Load student info
    } catch (e) {
      _attendance = {};
      _studentInfo = {};
    }
  }

  Future<void> saveCurrentAttendance(String groupId, Map<String, bool> currentAttendance) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_attendance_$groupId', jsonEncode(currentAttendance));
  }

  Future<Map<String, bool>> loadCurrentAttendance(String groupId) async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('current_attendance_$groupId');
    if (json == null) return {};
    return Map<String, bool>.from(jsonDecode(json));
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('attendance_data', _encodeMap(_attendance));
    await prefs.setString('student_info', _encodeMap(_studentInfo)); // Save student info
  }

  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('attendance_data', _encodeMap(_attendance));
    await prefs.setString('student_info', _encodeMap(_studentInfo));
  }

  String _encodeMap(Map<String, dynamic> map) => jsonEncode(map);
  
  Map<String, dynamic> _decodeMap(String? json) {
    return json == null ? {} : Map<String, dynamic>.from(jsonDecode(json));
  }

  String? getRegNo(String groupId, String studentName) {
    return _studentInfo[groupId]?[studentName]; // Ensure correct retrieval of regNo
  }

  Future<List<String>> validateCsv(File file) async {
    final errors = <String>[];

    try {
      if (!await file.exists()) {
        errors.add('File does not exist.');
        return errors;
      }

      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        errors.add('CSV file is empty.');
        return errors;
      }

      final rows = const CsvToListConverter().convert(content, eol: '\n');
      if (rows.isEmpty || rows[0].length != 2) {
        errors.add('Invalid CSV format. Expected two columns: regNo and name.');
        return errors;
      }

      for (var i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.length != 2) {
          errors.add('Invalid row format on line ${i + 1}. Each row must have exactly two columns: regNo and name.');
          continue;
        }

        final regNo = row[0]?.toString().trim() ?? '';
        final name = row[1]?.toString().trim() ?? '';
        if (regNo.isEmpty || name.isEmpty) {
          errors.add('Empty regNo or name on line ${i + 1}. Both fields are required.');
        }
      }
    } catch (e) {
      errors.add('Error reading CSV file: ${e.toString()}');
    }

    return errors;
  }

  Future<void> handleCsvImport(String groupId, File csvFile) async {
    try {
      final csvContent = await csvFile.readAsString();
      final rows = csvContent.split('\n').map((row) => row.split(',')).toList();

      for (final row in rows) {
        if (row.length < 2) continue; // Skip invalid rows
        final studentName = row[0].trim();
        final regNo = row[1].trim();

        _attendance[groupId] ??= {};
        _attendance[groupId]![studentName] ??= {};
        _studentInfo[groupId] ??= {};
        _studentInfo[groupId]![studentName] = regNo;
      }

      await _saveData(); // Save the updated data persistently
    } catch (e) {
      throw Exception('Failed to import CSV: $e');
    }
  }

  Future<void> saveRegistrationNumbers(String groupId, Map<String, String> students) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('registration_numbers_$groupId', jsonEncode(students));
  }

  Future<void> loadFromJson() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/attendance_data.json');
      if (await file.exists()) {
        final jsonData = jsonDecode(await file.readAsString());
        _attendance = (jsonData['attendance'] as Map<String, dynamic>).map((groupId, groupData) {
          return MapEntry(
            groupId,
            (groupData as Map<String, dynamic>).map((studentName, details) {
              return MapEntry(studentName, details as Map<String, bool>);
            }),
          );
        });
        _studentInfo = (jsonData['studentInfo'] as Map<String, dynamic>).map((groupId, groupData) {
          return MapEntry(
            groupId,
            (groupData as Map<String, dynamic>).map((studentName, regNo) {
              return MapEntry(studentName, regNo as String);
            }),
          );
        });
      }
    } catch (e) {
      // Handle errors (e.g., log them)
      _attendance = {};
      _studentInfo = {};
    }
  }

  Future<void> saveToJson() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/attendance_data.json');
      final jsonData = {
        'attendance': _attendance.map((groupId, groupData) {
          return MapEntry(
            groupId,
            groupData.map((studentName, details) => MapEntry(studentName, details)),
          );
        }),
        'studentInfo': _studentInfo.map((groupId, groupData) {
          return MapEntry(
            groupId,
            groupData.map((studentName, regNo) => MapEntry(studentName, regNo)),
          );
        }),
      };
      await file.writeAsString(jsonEncode(jsonData));
    } catch (e) {
      // Handle errors (e.g., log them)
    }
  }

  void updateAttendance(String groupId, String studentName, double percentage) {
    _studentInfo[groupId] ??= {};
    _studentInfo[groupId]![studentName] = percentage.toString();
    saveToJson(); // Save changes to JSON
  }
}