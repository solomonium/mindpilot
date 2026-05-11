import 'package:mindpilot/export.dart';

enum LoadingState { idle, busy, loaded, error }

class HomeProvider extends BaseProvider {
  int _navIndex = 0;
  String phoneNumber = '';
  int get navIndex => _navIndex;
  set navIndex(int val) {
    _navIndex = val;
    safePrint(val);
    notifyListeners();
  }
}
