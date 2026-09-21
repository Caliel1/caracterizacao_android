import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models/device_characterization.dart';

class DeviceCharacterizationService {
  final DeviceInfoPlugin _deviceInfoPlugin =
      DeviceInfoPlugin();

  Future<DeviceCharacterization> collect(
    BuildContext context,
  ) async {
    // -------------------------------------------------------------------------
    // Obtemos tudo que depende do BuildContext ANTES dos await.
    // -------------------------------------------------------------------------

    final view = View.of(context);
    final mediaQuery = MediaQuery.of(context);

    final display = view.display;

    final double devicePixelRatio =
        display.devicePixelRatio;

    final double logicalWidth =
        mediaQuery.size.width;

    final double logicalHeight =
        mediaQuery.size.height;

    final String orientation =
        mediaQuery.orientation ==
                Orientation.portrait
            ? 'PORTRAIT'
            : 'LANDSCAPE';

    // -------------------------------------------------------------------------
    // Agora podemos executar as operações assíncronas.
    // -------------------------------------------------------------------------

    final androidInfo =
        await _deviceInfoPlugin.androidInfo;

    final packageInfo =
        await PackageInfo.fromPlatform();

    // -------------------------------------------------------------------------
    // Monta a caracterização.
    // -------------------------------------------------------------------------

    return DeviceCharacterization(
      collectedAt: DateTime.now(),

      // -----------------------------------------------------------------------
      // PLATAFORMA
      // -----------------------------------------------------------------------

      platform: 'ANDROID',

      // -----------------------------------------------------------------------
      // DISPOSITIVO
      // -----------------------------------------------------------------------

      manufacturer:
          androidInfo.manufacturer,

      brand:
          androidInfo.brand,

      model:
          androidInfo.model,

      device:
          androidInfo.device,

      product:
          androidInfo.product,

      board:
          androidInfo.board,

      hardware:
          androidInfo.hardware,

      // -----------------------------------------------------------------------
      // ANDROID
      // -----------------------------------------------------------------------

      androidRelease:
          androidInfo.version.release,

      androidSdkInt:
          androidInfo.version.sdkInt,

      androidSecurityPatch:
          androidInfo.version.securityPatch,

      isPhysicalDevice:
          androidInfo.isPhysicalDevice,

      supported32BitAbis:
          List<String>.from(
        androidInfo.supported32BitAbis,
      ),

      supported64BitAbis:
          List<String>.from(
        androidInfo.supported64BitAbis,
      ),

      supportedAbis:
          List<String>.from(
        androidInfo.supportedAbis,
      ),

      // -----------------------------------------------------------------------
      // DISPLAY
      // -----------------------------------------------------------------------

      displayPhysicalWidthPx:
          display.size.width.round(),

      displayPhysicalHeightPx:
          display.size.height.round(),

      devicePixelRatio:
          devicePixelRatio,

      logicalWidth:
          logicalWidth,

      logicalHeight:
          logicalHeight,

      refreshRateHz:
          display.refreshRate,

      displayId:
          display.id,

      orientation:
          orientation,

      // -----------------------------------------------------------------------
      // APLICATIVO
      // -----------------------------------------------------------------------

      appName:
          packageInfo.appName,

      packageName:
          packageInfo.packageName,

      appVersion:
          packageInfo.version,

      appBuildNumber:
          packageInfo.buildNumber,
    );
  }
}