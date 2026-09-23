import 'dart:io';
import 'package:in_app_update/in_app_update.dart';
import 'package:mindpilot/export.dart';

class InAppUpdateService {
  static final InAppUpdateService _instance = InAppUpdateService._internal();
  factory InAppUpdateService() => _instance;
  InAppUpdateService._internal();

  bool _isChecking = false;
  bool _isUpdating = false;

  bool get isUpdating => _isUpdating;

  /// Checks for app updates.
  /// 1. On Android: First attempts Google Play In-App Updates API (flexible/immediate).
  ///    If unavailable or not returned, checks RemoteConfig. If update is required, shows update dialog.
  /// 2. On iOS: Checks RemoteConfig version and shows update dialog.
  /// 3. If [isManual] is true and app is up to date, notifies the user.
  Future<void> checkForInAppUpdate(BuildContext context, {bool isManual = false}) async {
    if (_isChecking) return;
    _isChecking = true;

    try {
      final config = ConfigService();
      await config.fetchRemoteConfig();
      final currentVersion = config.currentAppVersion;
      final latestVersion = config.latestVersion;
      final isRemoteUpdateRequired = config.isUpdateRequired(currentVersion);
      final isForceUpdate = config.forceUpdate;

      if (Platform.isAndroid) {
        bool playUpdateHandled = false;
        try {
          final updateInfo = await InAppUpdate.checkForUpdate();

          if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
            playUpdateHandled = true;
            if (isForceUpdate && updateInfo.immediateUpdateAllowed) {
              safePrint('InAppUpdateService: Starting immediate in-app update...');
              final result = await InAppUpdate.performImmediateUpdate();
              if (result != AppUpdateResult.success && isForceUpdate) {
                await openStoreListing();
              }
            } else if (updateInfo.flexibleUpdateAllowed) {
              safePrint('InAppUpdateService: Starting flexible in-app update...');
              await InAppUpdate.startFlexibleUpdate();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('MindPilot update is downloading in background!'),
                    backgroundColor: const Color(0xFF10B981),
                    action: SnackBarAction(
                      label: 'Restart App',
                      textColor: Colors.white,
                      onPressed: () async {
                        await InAppUpdate.completeFlexibleUpdate();
                      },
                    ),
                    duration: const Duration(seconds: 30),
                  ),
                );
              }
            } else if (updateInfo.immediateUpdateAllowed) {
              final result = await InAppUpdate.performImmediateUpdate();
              if (result != AppUpdateResult.success) {
                await openStoreListing();
              }
            } else {
              // Update available but neither immediate nor flexible allowed
              if (context.mounted) {
                AppHelper.showUpdatePrompt(
                  context,
                  version: latestVersion.isNotEmpty ? latestVersion : 'Latest',
                  force: isForceUpdate,
                );
              }
            }
          }
        } catch (playError) {
          safePrint('InAppUpdateService Play Store check error: $playError');
        }

        if (!playUpdateHandled) {
          if (isRemoteUpdateRequired) {
            if (context.mounted) {
              AppHelper.showUpdatePrompt(
                context,
                version: latestVersion.isNotEmpty ? latestVersion : 'Latest',
                force: isForceUpdate,
              );
            }
          } else if (isManual && context.mounted) {
            context.showInAppNotification(
              'MindPilot is up to date! (v$currentVersion)',
              type: InAppNotificationType.success,
            );
          }
        }
      } else if (Platform.isIOS) {
        if (isRemoteUpdateRequired) {
          if (context.mounted) {
            AppHelper.showUpdatePrompt(
              context,
              version: latestVersion.isNotEmpty ? latestVersion : 'Latest',
              force: isForceUpdate,
            );
          }
        } else if (isManual && context.mounted) {
          context.showInAppNotification(
            'MindPilot is up to date! (v$currentVersion)',
            type: InAppNotificationType.success,
          );
        }
      }
    } catch (e) {
      safePrint('InAppUpdateService check failed: $e');
      if (isManual && context.mounted) {
        context.showInAppNotification('Could not check for updates: $e');
      }
    } finally {
      _isChecking = false;
    }
  }

  /// Performs the update action when user taps "Update Now" on the update dialog.
  /// Ensures Google Play In-App Updates is tried, and seamlessly falls back to opening the store listing.
  Future<bool> performAppUpdate(BuildContext context, {bool isForceUpdate = false}) async {
    if (_isUpdating) return false;
    _isUpdating = true;

    try {
      if (Platform.isAndroid) {
        try {
          final updateInfo = await InAppUpdate.checkForUpdate();
          if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
            if (isForceUpdate && updateInfo.immediateUpdateAllowed) {
              safePrint('InAppUpdateService: Performing immediate in-app update...');
              final result = await InAppUpdate.performImmediateUpdate();
              if (result == AppUpdateResult.success) {
                return true;
              }
              // If not completed or denied, fallback to store listing
              await openStoreListing();
              return true;
            } else if (updateInfo.flexibleUpdateAllowed) {
              safePrint('InAppUpdateService: Starting flexible in-app update...');
              await InAppUpdate.startFlexibleUpdate();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('MindPilot update is downloading in background!'),
                    backgroundColor: const Color(0xFF10B981),
                    action: SnackBarAction(
                      label: 'Restart App',
                      textColor: Colors.white,
                      onPressed: () async {
                        await InAppUpdate.completeFlexibleUpdate();
                      },
                    ),
                    duration: const Duration(seconds: 30),
                  ),
                );
              }
              return true;
            } else if (updateInfo.immediateUpdateAllowed) {
              final result = await InAppUpdate.performImmediateUpdate();
              if (result == AppUpdateResult.success) {
                return true;
              }
              await openStoreListing();
              return true;
            }
          }
        } catch (playError) {
          safePrint('InAppUpdate error during performAppUpdate: $playError');
        }

        // Fallback: If Google Play In-App Updates API is not available or throws error (e.g. sideloaded, dev build, or Play store cache lag)
        safePrint('InAppUpdateService: Falling back to Store listing...');
        await openStoreListing();
        return true;
      } else {
        // iOS or other platform -> Open App Store listing
        await openStoreListing();
        return true;
      }
    } catch (e) {
      safePrint('InAppUpdateService performAppUpdate failed: $e');
      final fallbackUrl = ConfigService().updateUrl;
      await AppHelper.launchURL(fallbackUrl);
      return true;
    } finally {
      _isUpdating = false;
    }
  }

  /// Opens the official app store listing (Google Play or Apple App Store).
  Future<void> openStoreListing() async {
    try {
      await InAppReviewService().openStoreListing();
    } catch (e) {
      safePrint('InAppUpdateService openStoreListing failed: $e');
      final fallbackUrl = ConfigService().updateUrl;
      await AppHelper.launchURL(fallbackUrl);
    }
  }
}
