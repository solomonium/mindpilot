import 'package:mindpilot/export.dart';

enum ENV { dev, prod }

class MyRoutes {
  final GlobalKey<NavigatorState> navKey = GlobalKey();
  NavigatorState? get nav => navKey.currentState;
  final GlobalKey<InAppNotificationState> notifyKey = GlobalKey();

  static const prodUrl = 'https://twezi_app.com/';
  static const devUrl = 'https://twezi_app.com/';
  // static const prodUrl = 'https://d1032c0f16a5.ngrok-free.app/api/';
  // static const devUrl = 'https://d1032c0f16a5.ngrok-free.app/api/';

  static const environment = ENV.dev;
  final String baseUrl = getBaseUrl(environment);

  static String getBaseUrl(env) {
    switch (env) {
      case ENV.dev:
        return devUrl;
      case ENV.prod:
        return prodUrl;
      default:
        return devUrl;
    }
  }
}
