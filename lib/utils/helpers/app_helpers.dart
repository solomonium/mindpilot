import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mindpilot/export.dart';

class AppHelper {
  static void unFocus() {
    WidgetsBinding.instance.focusManager.primaryFocus?.unfocus();
  }

  String splitNumber(String s) {
    var sa = s.split('');
    var n = '';
    var i = 0;
    for (var v in sa) {
      if (i < 4) {
        n += v;
        i += 1;
      } else {
        n += '-$v';
        i = 1;
      }
    }

    return n;
  }
}

void safePrint(Object? object) {
  if (kDebugMode) {
    print(object);
  }
}

class TimeTeller {
  static String tellTimeOfTheDay() {
    int hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour >= 12 && hour < 16) {
      return 'Good Afternoon';
    } else if (hour >= 16 && hour < 24) {
      return 'Good Evening';
    } else {
      return 'Good Day';
    }
  }
}

mixin FormMixin<T extends StatefulWidget> on State<T> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  AutovalidateMode? autoValidateMode;

  void validate(VoidCallback callback, {VoidCallback? orElse}) {
    final FormState? formState = formKey.currentState;

    if (formState != null && formState.validate() != false) {
      FocusScope.of(context).unfocus();
      formState.save();
      callback();
    } else {
      setState(() => autoValidateMode = AutovalidateMode.onUserInteraction);
      orElse?.call();
    }
  }

  bool _isLoading = false;
  bool get isLoading => _isLoading;
  set isLoading(bool isLoading) {
    if (!mounted) return;
    setState(() => _isLoading = isLoading);
  }

  FutureOr load<R>(Future<R> Function() action) async {
    isLoading = true;
    R result = await action();
    isLoading = false;
    return result;
  }
}

///hello world
