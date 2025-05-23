import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import SharedPreferences
import 'dart:convert'; // For JSON encoding/decoding
import '../services/attendance_data.dart';

class GroupRecordsPage extends StatefulWidget {
  final String groupId;

  const GroupRecordsPage({
    super.key,
    required this.groupId,
  });

  @override
  State<GroupRecordsPage> createState() => _GroupRecordsPageState();
}

class _GroupRecordsPageState extends State<GroupRecordsPage> {
  late Map<String, double> studentPercentages;

  @override
  void initState() {
    super.initState();
    studentPercentages = {}; // Initialize with an empty map
    _loadStudentPercentages();
  }

  Future<void> _loadStudentPercentages() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('studentPercentages_${widget.groupId}');
    setState(() {
      studentPercentages = data != null
          ? Map<String, double>.from(
              json.decode(data).map((key, value) => MapEntry(key, value.toDouble())),
            )
          : {}; // Fallback to an empty map if no data is found
    });
  }

  Future<void> _saveStudentPercentages() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'studentPercentages_${widget.groupId}',
      json.encode(studentPercentages),
    );
  }

  void _updateStudentPercentage(String student, double percentage) {
    setState(() {
      studentPercentages[student] = percentage;
    });
    _saveStudentPercentages();
  }

  void _showStudentPercentageDialog(String student, double percentage) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Attendance Details'),
          content: Text(
            'Student: $student\nAttendance: ${percentage.toStringAsFixed(1)}%',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // For debugging - print the data we're working with
    debugPrint('Group ID: ${widget.groupId}');
    debugPrint('Student percentages: $studentPercentages');

    return Scaffold(
      appBar: AppBar(
        title: Text('Records - ${widget.groupId}'),
      ),
      body: ListView.builder(
        itemCount: studentPercentages.length,
        itemBuilder: (context, index) {
          final student = studentPercentages.keys.elementAt(index);
          final percentage = studentPercentages[student]!;
          final regNo = AttendanceData().getRegNo(widget.groupId, student); // Retrieve regNo

          // Debugging: Log if regNo is null
          if (regNo == null) {
            debugPrint('Warning: regNo is null for student $student in group ${widget.groupId}');
          }

          return Card(
            child: ListTile(
              leading: Icon(
                Icons.person,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(
                regNo != null ? '$student ($regNo)' : student,
                style: TextStyle(
                  color: regNo == null ? Colors.red : null,
                ),
              ),
              subtitle: Text('Attendance: ${percentage.toStringAsFixed(1)}%'),
              onTap: () {
                _showStudentPercentageDialog(student, percentage);
              },
              trailing: IconButton(
                icon: Icon(Icons.edit),
                onPressed: () {
                  // Example: Update percentage (you can replace this with your logic)
                  _updateStudentPercentage(student, percentage + 1.0);
                },
              ),
            ),
          );
        },
      ),
    );
  }
}