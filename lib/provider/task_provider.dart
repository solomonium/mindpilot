import 'package:mindpilot/export.dart';

class TaskItem {
  final int? id;
  final String title;
  final String description;
  final String date;
  final String? completionTime;
  final String? startTime;
  final int? durationMinutes;
  final bool isDone;

  TaskItem({
    this.id,
    required this.title,
    required this.description,
    required this.date,
    this.completionTime,
    this.startTime,
    this.durationMinutes,
    this.isDone = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'date': date,
      'completionTime': completionTime,
      'startTime': startTime,
      'durationMinutes': durationMinutes,
      'isDone': isDone ? 1 : 0,
    };
  }
}

class TaskProvider extends ChangeNotifier {
  final List<TaskItem> _tasks = [];
  int _completedCount = 0;
  int _totalCount = 0;
  final DatabaseHelper _dbHelper = DatabaseHelper();

  List<TaskItem> get tasks => _tasks;
  int get completedCount => _completedCount;
  int get totalCount => _totalCount;

  Future<void> loadTasks() async {
    final data = await _dbHelper.getTasks();
    _tasks.clear();
    for (var item in data) {
      _tasks.add(TaskItem(
        id: item['id'],
        title: item['title'],
        description: item['description'],
        date: item['date'],
        completionTime: item['completionTime'],
        startTime: item['startTime'],
        durationMinutes: item['durationMinutes'],
        isDone: item['isDone'] == 1,
      ));
    }
    await refreshStats();
    notifyListeners();
  }

  Future<void> refreshStats() async {
    _completedCount = await _dbHelper.getCompletedTasksCount();
    _totalCount = await _dbHelper.getTotalTasksCount();
    notifyListeners();
  }

  Future<void> addTask(
    String title, 
    String description, {
    String? completionTime,
    String? startTime,
    int? durationMinutes,
  }) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final task = TaskItem(
      title: title, 
      description: description, 
      date: today,
      completionTime: completionTime,
      startTime: startTime,
      durationMinutes: durationMinutes,
    );
    await _dbHelper.insertTask(task.toMap());
    await loadTasks();
  }


  Future<void> toggleTaskDone(TaskItem task) async {
    final updatedTask = TaskItem(
      id: task.id,
      title: task.title,
      description: task.description,
      date: task.date,
      completionTime: task.completionTime,
      isDone: !task.isDone,
    );
    await _dbHelper.updateTask(task.id!, updatedTask.toMap());
    await loadTasks();
  }

  Future<void> deleteTask(int id) async {
    await _dbHelper.deleteTask(id);
    await loadTasks();
  }
}
