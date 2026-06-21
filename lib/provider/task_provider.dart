import 'package:mindpilot/export.dart';

class TaskItem {
  final int? id;
  final String title;
  final String description;
  final String date;
  final String? completionTime;
  final String? startTime;
  final int? durationMinutes;
  final String? remoteId;
  final bool isDone;
  final String? doneTime;

  TaskItem({
    this.id,
    required this.title,
    required this.description,
    required this.date,
    this.completionTime,
    this.startTime,
    this.durationMinutes,
    this.remoteId,
    this.isDone = false,
    this.doneTime,
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
      'remoteId': remoteId,
      'isDone': isDone ? 1 : 0,
      'doneTime': doneTime,
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
    await SyncService().syncTasksFromFirestore();
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
        remoteId: item['remoteId'],
        isDone: item['isDone'] == 1,
        doneTime: item['doneTime'],
      ));
    }
    // Sort: active tasks first (newest created), then done tasks (newest done first)
    _tasks.sort((a, b) {
      if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
      if (!a.isDone) {
        return (b.id ?? 0).compareTo(a.id ?? 0);
      } else {
        final dtA = a.doneTime ?? '';
        final dtB = b.doneTime ?? '';
        if (dtA.isEmpty && dtB.isEmpty) return (b.id ?? 0).compareTo(a.id ?? 0);
        if (dtA.isEmpty) return 1;
        if (dtB.isEmpty) return -1;
        return dtB.compareTo(dtA);
      }
    });
    await refreshStats();
    notifyListeners();
  }

  Future<void> refreshStats() async {
    _completedCount = await _dbHelper.getCompletedTasksCount();
    _totalCount = await _dbHelper.getTotalTasksCount();
    notifyListeners();
  }

  Future<bool> addTask(
    String title, 
    String description, {
    String? completionTime,
    String? startTime,
    int? durationMinutes,
  }) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    if (!await AppHelper.isOnline()) {
      final context = R.N.navKey.currentContext;
      if (context != null) context.showInAppNotification(R.S.checkInternet);
      return false;
    }

    try {
      final task = TaskItem(
        title: title, 
        description: description, 
        date: today,
        completionTime: completionTime,
        startTime: startTime,
        durationMinutes: durationMinutes,
      );
      final id = await _dbHelper.insertTask(task.toMap());
      
      final taskMap = task.toMap();
      taskMap['id'] = id;
      await SyncService().pushTaskToFirestore(taskMap);
      
      await loadTasks();
      return true;
    } catch (e) {
      safePrint('Error adding task: $e');
      return false;
    }
  }

  Future<void> updateTaskDescription(int id, String newDescription) async {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      final task = _tasks[index];
      final updatedTask = TaskItem(
        id: task.id,
        title: task.title,
        description: newDescription,
        date: task.date,
        completionTime: task.completionTime,
        startTime: task.startTime,
        durationMinutes: task.durationMinutes,
        remoteId: task.remoteId,
        isDone: task.isDone,
        doneTime: task.doneTime,
      );
      
      await _dbHelper.updateTask(id, updatedTask.toMap());
      SyncService().pushTaskToFirestore(updatedTask.toMap());
      _tasks[index] = updatedTask;
      notifyListeners();
    }
  }


  Future<void> toggleTaskDone(TaskItem task) async {
    if (!await AppHelper.isOnline()) {
      final context = R.N.navKey.currentContext;
      if (context != null) context.showInAppNotification('Network required to update tasks.');
      return;
    }

    final nowDone = !task.isDone;
    final updatedTask = TaskItem(
      id: task.id,
      title: task.title,
      description: task.description,
      date: task.date,
      completionTime: task.completionTime,
      startTime: task.startTime,
      durationMinutes: task.durationMinutes,
      remoteId: task.remoteId,
      isDone: nowDone,
      doneTime: nowDone ? DateTime.now().toIso8601String() : null,
    );
    await _dbHelper.updateTask(task.id!, updatedTask.toMap());
    
    SyncService().pushTaskToFirestore(updatedTask.toMap());
    
    if (nowDone) {
      await EngagementService().recordAction(EngagementAction.taskCompleted);
    }

    await loadTasks();
  }

  Future<void> deleteTask(int id) async {
    final task = _tasks.firstWhere((t) => t.id == id);
    if (task.remoteId != null) {
      SyncService().deleteTaskFromFirestore(task.remoteId!);
    }
    await _dbHelper.deleteTask(id);
    await loadTasks();
  }

  Future<void> clearAllTasks() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('tasks')
          .get();
      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }
    }
    await _dbHelper.clearTasks();
    await loadTasks();
  }
}
