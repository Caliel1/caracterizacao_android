class DeviceCharacterization {
  final DateTime collectedAt;

  // ---------------------------------------------------------------------------
  // PLATAFORMA / DISPOSITIVO
  // ---------------------------------------------------------------------------

  final String platform;

  final String manufacturer;
  final String brand;
  final String model;
  final String device;
  final String product;
  final String board;
  final String hardware;

  // ---------------------------------------------------------------------------
  // ANDROID
  // ---------------------------------------------------------------------------

  final String androidRelease;
  final int androidSdkInt;
  final String? androidSecurityPatch;

  final bool isPhysicalDevice;

  final List<String> supported32BitAbis;
  final List<String> supported64BitAbis;
  final List<String> supportedAbis;

  // ---------------------------------------------------------------------------
  // DISPLAY
  // ---------------------------------------------------------------------------

  final int displayPhysicalWidthPx;
  final int displayPhysicalHeightPx;

  final double devicePixelRatio;

  final double logicalWidth;
  final double logicalHeight;

  final double refreshRateHz;

  final int displayId;

  final String orientation;

  // ---------------------------------------------------------------------------
  // APLICATIVO
  // ---------------------------------------------------------------------------

  final String appName;
  final String packageName;
  final String appVersion;
  final String appBuildNumber;

  DeviceCharacterization({
    required this.collectedAt,
    required this.platform,
    required this.manufacturer,
    required this.brand,
    required this.model,
    required this.device,
    required this.product,
    required this.board,
    required this.hardware,
    required this.androidRelease,
    required this.androidSdkInt,
    required this.androidSecurityPatch,
    required this.isPhysicalDevice,
    required this.supported32BitAbis,
    required this.supported64BitAbis,
    required this.supportedAbis,
    required this.displayPhysicalWidthPx,
    required this.displayPhysicalHeightPx,
    required this.devicePixelRatio,
    required this.logicalWidth,
    required this.logicalHeight,
    required this.refreshRateHz,
    required this.displayId,
    required this.orientation,
    required this.appName,
    required this.packageName,
    required this.appVersion,
    required this.appBuildNumber,
  });

  Map<String, dynamic> toMap() {
    return {
      'characterization_collected_at':
          collectedAt.toIso8601String(),

      'platform':
          platform,

      'manufacturer':
          manufacturer,

      'brand':
          brand,

      'model':
          model,

      'device':
          device,

      'product':
          product,

      'board':
          board,

      'hardware':
          hardware,

      'android_release':
          androidRelease,

      'android_sdk_int':
          androidSdkInt,

      'android_security_patch':
          androidSecurityPatch,

      'is_physical_device':
          isPhysicalDevice,

      'supported_32bit_abis':
          supported32BitAbis.join('|'),

      'supported_64bit_abis':
          supported64BitAbis.join('|'),

      'supported_abis':
          supportedAbis.join('|'),

      'display_physical_width_px':
          displayPhysicalWidthPx,

      'display_physical_height_px':
          displayPhysicalHeightPx,

      'device_pixel_ratio':
          devicePixelRatio,

      'logical_width':
          logicalWidth,

      'logical_height':
          logicalHeight,

      'refresh_rate_hz':
          refreshRateHz,

      'display_id':
          displayId,

      'orientation':
          orientation,

      'app_name':
          appName,

      'package_name':
          packageName,

      'app_version':
          appVersion,

      'app_build_number':
          appBuildNumber,
    };
  }
}