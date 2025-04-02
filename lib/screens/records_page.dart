import 'package:flutter/material.dart';
import 'dart:developer'; // Import the log function
import 'package:excel/excel.dart'; // Import the excel package
import 'dart:io'; // Ensure this import is present
import 'package:path_provider/path_provider.dart'; // For getting file paths
import '../services/attendance_data.dart'; // Import attendanceData
import 'package:share_plus/share_plus.dart'; // Import the share_plus package
// Import file picker package
import 'package:intl/intl.dart'; // Import for date formatting
import 'student_details_page.dart'; // Import the new screen

class RecordsPage extends StatefulWidget {
  final List<String> groups;
  const RecordsPage({super.key, required this.groups});

  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  @override
  void initState() {
    super.initState();
    AttendanceData().loadFromJson(); // Load registration data from JSON
  }

  Future<String?> _exportGroupToExcel(String groupId) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Attendance Records'];

      excel.delete('Sheet1'); // Delete the default "Sheet1"

      // Add date at the top
      final currentDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
      sheet.appendRow([TextCellValue('Date: $currentDate')]);
      sheet.appendRow([]); // Empty row for spacing

      // Correct way to add headers
      sheet.appendRow([
        TextCellValue('Name'),
        TextCellValue('Reg No'),
        TextCellValue('Percentage')
      ]);

      final groupAttendance = AttendanceData().getAttendancePercentages(groupId);
      if (groupAttendance.isEmpty) {
        return null;
      }

      for (final student in groupAttendance.keys) {
        // Retrieve registration number correctly
        final regNo = AttendanceData().getRegNo(groupId, student) ?? 'N/A';
        final attendancePercentage = groupAttendance[student]!;

        // Ensure percentage is calculated correctly
        final correctedPercentage = attendancePercentage.clamp(0.0, 100.0);

        // Add student data to the Excel sheet
        sheet.appendRow([
          TextCellValue(student),
          TextCellValue(regNo), // Include registration number
          TextCellValue('${correctedPercentage.toStringAsFixed(1)}%')
        ]);
      }

      final directory = await getApplicationDocumentsDirectory();
      final attendanceFolder = Directory('${directory.path}/attendance');
      if (!await attendanceFolder.exists()) {
        await attendanceFolder.create(recursive: true);
      }

      final filePath = '${attendanceFolder.path}/$groupId-AttendanceRecords.xlsx';
      final fileBytes = excel.save();
      if (fileBytes == null) {
        log('Error: Excel file bytes are null.');
        return null;
      }

      final file = File(filePath);
      await file.writeAsBytes(fileBytes, flush: true); // Ensure the file is flushed to disk

      return filePath;
    } catch (e) {
      log('Error exporting to Excel: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('View Records'),
      ),
      body: ListView.builder(
        itemCount: widget.groups.length,
        itemBuilder: (context, index) {
          final groupId = widget.groups[index];

          return FutureBuilder<Map<String, double>>(
            future: AttendanceData().getStoredPercentages(groupId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return ListTile(
                  title: Text(groupId),
                  subtitle: const Text('Error loading data'),
                );
              }

              final groupAttendance = snapshot.data ?? {};
              final allStudents = AttendanceData().attendance[groupId]?.keys.toList() ?? [];
              final filteredStudents = allStudents.where((studentName) {
                final regNo = AttendanceData().getRegNo(groupId, studentName);
                return regNo != null && regNo.isNotEmpty; // Exclude deleted students
              }).toList();

              final allStudentRecords = filteredStudents.map((studentName) {
                final percentage = groupAttendance[studentName] ?? 0.0;
                final correctedPercentage = percentage.clamp(0.0, 100.0);
                final regNo = AttendanceData().getRegNo(groupId, studentName) ?? 'N/A'; // Retrieve regNo
                return {
                  'name': studentName,
                  'regNo': regNo,
                  'percentage': correctedPercentage,
                };
              }).toList();

              final totalPercentage = groupAttendance.isNotEmpty
                  ? groupAttendance.values.reduce((a, b) => a + b) / groupAttendance.length
                  : 0.0;

              return Card(
                child: ExpansionTile(
                  leading: Icon(Icons.group, color: Theme.of(context).colorScheme.primary),
                  title: Text(groupId),
                  subtitle: Text('Overall Attendance: ${totalPercentage.toStringAsFixed(1)}%'),
                  children: [
                    ListTile(
                      title: Text('Date: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}'),
                    ),
                    for (var record in allStudentRecords)
                      ListTile(
                        title: Text('${record['name']} (${record['regNo']})'), // Include regNo
                        subtitle: Text('Attendance: ${(record['percentage'] as double?)?.toStringAsFixed(1) ?? '0.0'}%'),
                        trailing: IconButton(
                          icon: const Icon(Icons.info),
                          onPressed: () {
                            // Navigate to the student details page
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => StudentDetailsPage(
                                  studentName: record['name'] as String,
                                  regNo: record['regNo'] as String,
                                  percentage: record['percentage'] as double,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ListTile(
                      leading: const Icon(Icons.share),
                      title: const Text('Share Group Record as Excel'),
                      onTap: () async {
                        final filePath = await _exportGroupToExcel(groupId);
                        if (filePath != null) {
                          try {
                            await Share.shareXFiles([XFile(filePath)], text: 'Attendance Record for $groupId');
                          } catch (e) {
                            log('Error sharing file: $e');
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Failed to share the Excel file.')),
                              );
                            }
                          }
                        } else {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Failed to export group record as Excel.')),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}