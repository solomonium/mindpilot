import 'package:mindpilot/export.dart';

class AppProvider extends BaseProvider {
  ThemeType _theme = ThemeType.system;
  ThemeType get theme => _theme;

  set theme(ThemeType val) {
    _theme = val;
    notifyListeners();
    SharedPrefs.setString('THEME_VALUE', val.toString().split('.').last);
    safePrint(val);
  }

  void toggleTheme() {
    switch (_theme) {
      case ThemeType.light:
        theme = ThemeType.dark;
        break;
      case ThemeType.dark:
        theme = ThemeType.light;
        break;
      default:
        theme = ThemeType.light;
    }
  }

  // New property to represent the current app theme
  AppTheme get currentAppTheme {
    return AppTheme.fromType(_theme);
  }

  int get currentPage => _currentPage;
  int _currentPage = 0;
  set currentPage(int value) {
    _currentPage = value;
    notifyListeners();
  }

  int _onBoardPageIndex = 0;
  int get onBoardPageIndex => _onBoardPageIndex;
  set setOnBoardPageIndex(int val) {
    _onBoardPageIndex = val;
    notifyListeners();
  }
}
