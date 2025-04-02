import 'package:flutter/material.dart';
import '../services/attendance_data.dart';

class StudentDetailsPage extends StatelessWidget {
  final String studentName;
  final String regNo;
  final double percentage;

  const StudentDetailsPage({
    super.key,
    required this.studentName,
    required this.regNo,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$studentName Details'),
      ),
      body: FutureBuilder<Map<String, bool>>(
        future: AttendanceData().getStudentAttendance('groupId', studentName), // Replace 'groupId' dynamically
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || snapshot.data == null) {
            return const Center(child: Text('Error loading attendance data.'));
          }

          final attendanceRecords = snapshot.data!;
          return ListView(
            children: [
              ListTile(
                title: Text('Name: $studentName'),
                subtitle: Text('Reg No: $regNo'),
              ),
              ListTile(
                title: Text('Overall Attendance: ${percentage.toStringAsFixed(1)}%'),
              ),
              const Divider(),
              ...attendanceRecords.entries.map((entry) {
                return ListTile(
                  title: Text('Date: ${entry.key}'),
                  subtitle: Text('Present: ${entry.value ? "Yes" : "No"}'),
                );
              }).toList(),
            ],
          );
        },
      ),
    );
  }
}
