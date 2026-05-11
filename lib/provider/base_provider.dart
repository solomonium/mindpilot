import 'package:flutter/material.dart';

abstract class BaseProvider extends ChangeNotifier {
  bool isBusy = false;

  set setBusy(bool val) {
    isBusy = val;
    notifyListeners();
  }
}
