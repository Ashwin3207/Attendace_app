import 'package:flutter/material.dart';
import '../services/attendance_data.dart';

class AttendancePage extends StatefulWidget {
  final String groupId;
  final Map<String, String> students;
  final Function(Map<String, bool>) onAttendanceTaken;

  const AttendancePage({
    super.key,
    required this.groupId,
    required this.students,
    required this.onAttendanceTaken,
  });

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  final Map<String, bool> _attendance = {};

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  Future<void> _loadAttendance() async {
    final todayAttendance = await AttendanceData().loadCurrentAttendance(widget.groupId);
    setState(() {
      widget.students.forEach((name, regNo) {
        _attendance[name] = todayAttendance[name] ?? false; // Load saved state or default to false
      });
    });
  }

  Future<void> _saveAttendance() async {
    widget.onAttendanceTaken(_attendance);
    await AttendanceData().saveAttendance(widget.groupId, _attendance); // Save today's attendance
    await AttendanceData().calculateAndStorePercentages(widget.groupId); // Update percentages
    await AttendanceData().saveCurrentAttendance(widget.groupId, _attendance); // Persist toggle state
    await AttendanceData().saveRegistrationNumbers(widget.groupId, widget.students); // Save registration numbers
  }

  Future<void> _resetAttendance() async {
    await AttendanceData().resetTodayAttendance(widget.groupId); // Reset today's attendance
    await _loadAttendance(); // Reload the reset state
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Today\'s attendance has been reset.')),
    );
  }

  @override
  void dispose() {
    _saveAttendance(); // Automatically save attendance and update percentages when exiting the page
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Take Attendance - ${widget.groupId}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetAttendance, // Reset attendance when the button is pressed
          ),
        ],
      ),
      body: ListView(
        children: widget.students.keys.map((studentName) {
          final regNo = widget.students[studentName] ?? "N/A"; // Retrieve regNo from students map
          return SwitchListTile(
            title: Text('$studentName ($regNo)'), // Display regNo
            value: _attendance[studentName]!,
            onChanged: (value) {
              setState(() {
                _attendance[studentName] = value;
              });
              AttendanceData().toggleAttendance(widget.groupId, studentName, value); // Sync toggle state
            },
            activeColor: Theme.of(context).colorScheme.primary,
          );
        }).toList(),
      ),
    );
  }
}
