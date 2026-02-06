import '../../services/background_scan_service.dart';
import 'background_scan_service_io.dart'
    if (dart.library.html) 'background_scan_service_web.dart';

BackgroundScanService createBackgroundScanService() =>
    createPlatformBackgroundScanService();
