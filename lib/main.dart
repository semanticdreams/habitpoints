import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as Path;
import 'package:sqflite/sqflite.dart';

class Debouncer {
  Debouncer({this.delay = const Duration(milliseconds: 800)});

  final Duration delay;
  Timer? _timer;
  Future<void> Function()? _callback;

  void call(Future<void> Function() callback) {
    _timer?.cancel();
    _timer = Timer(delay, () {
      callback();
    });
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  bool hasPendingCallback() => _timer?.isActive ?? false;

  Future<void> executePendingCallback() async {
    if (_timer?.isActive ?? false) {
      _timer!.cancel();
      if (_callback != null) {
        await _callback!();
      }
    }
  }
}

class DatabaseHelper {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDb();
    return _database!;
  }

  _initDb() async {
    final dbPath = Path.join(await getDatabasesPath(), 'habitpoints.db');
    return await openDatabase(
      dbPath,
      onCreate: (db, version) async {
        await db.execute(
            'CREATE TABLE habits(id INTEGER PRIMARY KEY, name TEXT, value INTEGER)');
        await db.execute(
            'CREATE TABLE habit_instances(id INTEGER PRIMARY KEY, habit_id INTEGER, date TEXT)');
      },
      version: 1,
    );
  }
}

final dbHelper = DatabaseHelper();

class Habit {
  final int id;
  final String name;
  final int value;
  final int dailyScore;
  final int totalScore;

  const Habit({
    required this.id,
    required this.name,
    required this.value,
    required this.dailyScore,
    required this.totalScore,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'value': value,
    };
  }

  @override
  String toString() {
    return 'Habit{id: $id, name: $name, value: $value, dailyScore: $dailyScore, totalScore: $totalScore}';
  }
}

class HabitInstance {
  final int id;
  final int habitId;
  final DateTime date;

  const HabitInstance({
    required this.id,
    required this.habitId,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'habit_id': habitId,
      'date': date.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'HabitInstance{id: $id, habitId: $habitId, date: $date}';
  }
}

Future<void> insertHabit(Habit habit) async {
  final db = await dbHelper.database;

  await db.insert(
    'habits',
    habit.toMap(),
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}

Future<void> insertHabitInstance(HabitInstance habitInstance) async {
  final db = await dbHelper.database;

  await db.insert(
    'habit_instances',
    habitInstance.toMap(),
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}

Future<List<Habit>> habits() async {
  final db = await dbHelper.database;

  final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT 
        habits.*, 
        COUNT(case when SUBSTR(habit_instances.date, 1, 10) = ? then 1 else null end) * habits.value as dailyScore, 
        COUNT(habit_instances.id) * habits.value as totalScore,
        MAX(habit_instances.date) as recent_date
      FROM habits
      LEFT JOIN habit_instances ON habits.id = habit_instances.habit_id
      GROUP BY habits.id
      ORDER BY recent_date DESC
  ''', [DateTime.now().toIso8601String().substring(0, 10)]);

  return List.generate(maps.length, (i) {
    return Habit(
      id: maps[i]['id'] as int,
      name: maps[i]['name'] as String,
      value: maps[i]['value'] as int,
      dailyScore: maps[i]['dailyScore'] as int,
      totalScore: maps[i]['totalScore'] as int,
    );
  });
}

Future<void> updateHabit(Habit habit) async {
  final db = await dbHelper.database;

  await db.update(
    'habits',
    habit.toMap(),
    where: 'id = ?',
    whereArgs: [habit.id],
  );
}

Future<void> deleteHabit(int id) async {
  final db = await dbHelper.database;

  await db.delete(
    'habit_instances',
    where: 'habit_id = ?',
    whereArgs: [id],
  );

  await db.delete(
    'habits',
    where: 'id = ?',
    whereArgs: [id],
  );
}

Future<void> deleteAllInstancesOfHabit(int habitId) async {
  final db = await dbHelper.database;

  await db.delete(
    'habit_instances',
    where: 'habit_id = ?',
    whereArgs: [habitId],
  );
}

Future<int> getHabitInstanceCount(int habitId) async {
  final db = await dbHelper.database;
  final count = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM habit_instances WHERE habit_id = ?', [habitId]));
  return count ?? 0;
}

Future<int> getTodayHabitInstanceCount(int habitId) async {
  final db = await dbHelper.database;
  final todayDate = DateTime.now().toIso8601String().split('T')[0];
  final count = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM habit_instances WHERE habit_id = ? AND date = ?',
      [habitId, todayDate]));
  return count ?? 0;
}

Future<int> totalDailyScore() async {
  final db = await dbHelper.database;

  var result = await db.rawQuery('''
      SELECT 
        SUM(CASE WHEN SUBSTR(habit_instances.date, 1, 10) = ? THEN habits.value ELSE 0 END) as dailyTotal
      FROM habits
      LEFT JOIN habit_instances ON habits.id = habit_instances.habit_id
  ''', [DateTime.now().toIso8601String().substring(0, 10)]);

  return result.first['dailyTotal'] as int? ?? 0;
}

Future<int> totalScore() async {
  final db = await dbHelper.database;

  var result = await db.rawQuery('''
      SELECT 
        SUM(sub.total) as grand_total
      FROM (
        SELECT 
          habits.value * COUNT(habit_instances.id) as total
        FROM habits
        LEFT JOIN habit_instances ON habits.id = habit_instances.habit_id
        GROUP BY habits.id
      ) as sub
  ''');

  if (result.isNotEmpty && result.first['grand_total'] != null) {
    return result.first['grand_total'] as int;
  }
  return 0;
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'habitpoints',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class HabitDetailsPage extends StatefulWidget {
  final Habit habit;

  HabitDetailsPage({required this.habit});

  @override
  _HabitDetailsPageState createState() => _HabitDetailsPageState();
}

class _HabitDetailsPageState extends State<HabitDetailsPage> {
  late TextEditingController _nameController;
  late TextEditingController _valueController;
  final _debouncer = Debouncer(delay: Duration(milliseconds: 800));

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.habit.name)
      ..addListener(_debouncedUpdateHabit);
    _valueController =
        TextEditingController(text: widget.habit.value.toString())
          ..addListener(_debouncedUpdateHabit);
  }

  @override
  void dispose() {
    _debouncer.dispose();
    _nameController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  bool _hasChanges() {
    return widget.habit.name != _nameController.text ||
        widget.habit.value.toString() != _valueController.text;
  }

  Future<void> _debouncedUpdateHabit() async {
    _debouncer.call(_updateHabit);
  }

  Future<void> _updateHabit() async {
    if (!_hasChanges()) {
      return;
    }
    await updateHabit(Habit(
      id: widget.habit.id,
      name: _nameController.text,
      value: int.parse(_valueController.text),
      dailyScore: widget.habit.dailyScore,
      totalScore: widget.habit.totalScore,
    ));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Habit saved')),
    );
  }

  Future<bool> _handleBackAction() async {
    // TODO does this work?
    await _debouncer.executePendingCallback();
    Navigator.of(context).pop(true);
    return true;
  }

  _deleteHabit() async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Delete'),
          content: Text('Are you sure you want to delete this habit?'),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Delete'),
              onPressed: () async {
                await _actualDeleteHabit();
                Navigator.of(context).pop();
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );
  }

  _actualDeleteHabit() async {
    await deleteHabit(widget.habit.id);
  }

  Future<bool> _willPopCallback() async {
    if (_debouncer.hasPendingCallback()) {
      await _debouncer.executePendingCallback();
    }
    return true;
  }

  Future<void> _resetHabit() async {
    await deleteAllInstancesOfHabit(widget.habit.id);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Habit reset successfully!')),
    );
  }

  void _showResetConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Reset Habit'),
          content: Text(
              'Are you sure you want to reset this habit and delete all its instances?'),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Confirm'),
              onPressed: () {
                _resetHabit();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: _willPopCallback,
        child: Scaffold(
          appBar: AppBar(
            title: Text('Edit Habit'),
            leading: IconButton(
              icon: Icon(Icons.arrow_back),
              onPressed: _handleBackAction,
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.delete),
                onPressed: _deleteHabit,
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: <Widget>[
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(labelText: 'Habit Name'),
                ),
                TextField(
                  controller: _valueController,
                  decoration: InputDecoration(labelText: 'Habit Value'),
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  child: Text('Reset'),
                  style: ElevatedButton.styleFrom(
                    primary: Colors.red,
                    onPrimary: Colors.white,
                  ),
                  onPressed: _showResetConfirmationDialog,
                )
              ],
            ),
          ),
        ));
  }
}

class _MyHomePageState extends State<MyHomePage> {
  List<Habit> _habits = [];

  @override
  void initState() {
    super.initState();
    _loadHabits();
  }

  _loadHabits() async {
    List<Habit> loadedHabits = await habits();
    setState(() {
      _habits = loadedHabits;
    });
  }

  Future<void> _displayAddHabitDialog(BuildContext context) async {
    String? habitName;
    int? habitValue;

    return showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Add a New Habit'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  onChanged: (value) {
                    habitName = value;
                  },
                  decoration: InputDecoration(hintText: "Habit Name"),
                ),
                TextField(
                  onChanged: (value) {
                    habitValue = int.tryParse(value);
                  },
                  decoration: InputDecoration(hintText: "Habit Value"),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                child: Text('Cancel'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: Text('Save'),
                onPressed: () {
                  if (habitName != null &&
                      habitName!.isNotEmpty &&
                      habitValue != null) {
                    insertHabit(Habit(
                      id: DateTime.now().millisecondsSinceEpoch,
                      name: habitName!,
                      value: habitValue!,
                      dailyScore: 0,
                      totalScore: 0,
                    ));
                    Navigator.of(context).pop();
                    _loadHabits();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Please complete all fields!')),
                    );
                  }
                },
              ),
            ],
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: FutureBuilder<List<int>>(
          future: Future.wait([totalDailyScore(), totalScore()]),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done &&
                snapshot.hasData) {
              return Text(
                  'Daily: ${snapshot.data![0]}, Total: ${snapshot.data![1]}');
            } else {
              return CircularProgressIndicator();
            }
          },
        ),
      ),
      body: ListView.builder(
        itemCount: _habits.length,
        itemBuilder: (context, index) {
          final habit = _habits[index];
          return ListTile(
            title: Text(
              habit.name,
              style: TextStyle(
                color: habit.value < 0 ? Colors.red : Colors.black,
              ),
            ),
            subtitle: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                      text: 'Val: ${habit.value} ',
                      style: TextStyle(color: Colors.grey)),
                  TextSpan(
                      text: 'Daily: ${habit.dailyScore} ',
                      style: TextStyle(color: Colors.green)),
                  TextSpan(
                      text: 'Total: ${habit.totalScore}',
                      style: TextStyle(color: Colors.blue)),
                ],
              ),
            ),
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => HabitDetailsPage(habit: habit),
                ),
              );
              if (result == true) {
                _loadHabits();
              }
            },
            trailing: IconButton(
              icon: Icon(Icons.add_circle),
              onPressed: () async {
                final habitInstance = HabitInstance(
                  id: DateTime.now().millisecondsSinceEpoch,
                  habitId: habit.id!,
                  date: DateTime.now(),
                );
                await insertHabitInstance(habitInstance);

                _loadHabits();

                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Habit instance added!')),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _displayAddHabitDialog(context),
        tooltip: 'Add Habit',
        child: Icon(Icons.add),
      ),
    );
  }
}
