import 'package:mindpilot/export.dart';

class TaskItem {
  final int? id;
  final String title;
  final String description;
  final String date;
  final bool isDone;

  TaskItem({
    this.id,
    required this.title,
    required this.description,
    required this.date,
    this.isDone = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'date': date,
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

  Future<void> addTask(String title, String description) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final task = TaskItem(title: title, description: description, date: today);
    await _dbHelper.insertTask(task.toMap());
    await loadTasks();
  }

  Future<void> toggleTaskDone(TaskItem task) async {
    final updatedTask = TaskItem(
      id: task.id,
      title: task.title,
      description: task.description,
      date: task.date,
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
