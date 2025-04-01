import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'services/attendance_data.dart';
import 'screens/group_selection_page.dart';
import 'screens/records_page.dart';
import 'screens/group_creation_page.dart';
import 'screens/delete_group_page.dart';
import 'screens/attendance_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AttendanceData().loadData();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Attendance Manager',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          bodyMedium: TextStyle(fontSize: 16, color: Colors.black54),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue,
          centerTitle: true,
          titleTextStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        cardTheme: const CardTheme(
          margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          elevation: 6,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(15))),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(200, 50),
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 40),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
        ),
      ),
        home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AttendanceData attendance = AttendanceData();
  final List<String> _groups = [];
  final Map<String, List<Map<String, String>>> _groupStudents = {};

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _groups.addAll(List<String>.from(jsonDecode(prefs.getString('groups') ?? '[]')));
      _groupStudents.addAll(
        (jsonDecode(prefs.getString('group_students') ?? '{}') as Map<String, dynamic>)
            .map((key, value) => MapEntry(
                  key,
                  (value as List<dynamic>)
                      .map((e) => Map<String, String>.from(e as Map))
                      .toList(),
                )),
      );
    });
    await attendance.loadData(); // Ensure attendance data is loaded
  }

  Future<void> _saveGroups() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('groups', jsonEncode(_groups));
    await prefs.setString('group_students', jsonEncode(_groupStudents));
    await attendance.saveData(); // Save attendance data persistently
    setState(() {}); // Notify listeners about changes
  }

  Future<void> _addGroup(String name) async {
    if (name.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Group name cannot be empty.')));
      return;
    }
    setState(() {
      _groups.add(name);
      _groupStudents[name] = [];
    });
    await _saveGroups(); // Save changes persistently
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Group "$name" created successfully.')));
  }

  Future<void> _handleCsvImport(File file) async {
    try {
      final errors = await attendance.validateCsv(file);
      if (errors.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CSV Errors:\n${errors.join('\n')}')));
        return;
      }

      final content = await file.readAsString();
      final rows = const CsvToListConverter().convert(content, eol: '\n');
      final students = <Map<String, String>>[];
      
      for (var i = 1; i < rows.length; i++) {
        students.add({
          'regNo': rows[i][0].toString().trim(),
          'name': rows[i][1].toString().trim()
        });
      }

      final group = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Group'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _groups.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(_groups[index]),
                  onTap: () => Navigator.pop(context, _groups[index]),
                );
              },
            ),
          ),
        ),
      );

      if (group != null) {
        await attendance.initializeGroup(group, students);
        setState(() {
          _groupStudents[group] = students;
        });
        await _saveGroups(); // Save changes persistently
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imported ${students.length} students to $group')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to import CSV: ${e.toString()}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance Manager')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildActionButton(
              icon: Icons.upload,
              label: 'Import CSV',
              onPressed: () async {
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['csv']);
                if (result != null && result.files.isNotEmpty) {
                  await _handleCsvImport(File(result.files.single.path!));
                }
              },
            ),
            _buildActionButton(
              icon: Icons.group_add,
              label: 'Create Group',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GroupCreationPage(
                    onGroupCreated: _addGroup))),
            ),
            _buildActionButton(
              icon: Icons.people,
              label: 'Take Attendance',
              onPressed: () async {
                final selectedGroup = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GroupSelectionPage(
                      groups: _groups,
                      groupStudents: _groupStudents,
                    ),
                  ),
                );

                if (selectedGroup != null) {
                  final students = _groupStudents[selectedGroup] ?? [];
                  final studentMap = {
                    for (var student in students) student['name']!: student['regNo']!
                  };

                  final unsaved = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AttendancePage(
                        groupId: selectedGroup,
                        students: studentMap,
                        onAttendanceTaken: (attendanceData) async {
                          await attendance.saveAttendance(selectedGroup, attendanceData);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Attendance saved for $selectedGroup.')),
                          );
                        },
                      ),
                    ),
                  );

                  if (unsaved == true) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Attendance not saved.')),
                    );
                  }
                }
              },
            ),
            _buildActionButton(
              icon: Icons.list,
              label: 'View Records',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RecordsPage(groups: _groups))),
            ),
            _buildActionButton(
              icon: Icons.delete,
              label: 'Manage Groups',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DeleteGroupPage(
                    groups: _groups,
                    groupStudents: _groupStudents,
                    onDeleteGroup: (name) async {
                      setState(() => _groups.remove(name));
                      await attendance.deleteGroup(name);
                      await _saveGroups();
                    },
                    onDeleteStudent: (group, student) async {
                      setState(() => _groupStudents[group]?.removeWhere(
                        (s) => s['name'] == student));
                      await attendance.deleteStudent(group, student);
                      await _saveGroups();
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: ElevatedButton.icon(
        icon: Icon(icon),
        label: Text(label),
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(200, 50),
        ),
      ),
    );
  }
}