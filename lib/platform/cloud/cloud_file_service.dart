import '../../services/cloud_file_service.dart';
import 'cloud_file_service_io.dart'
    if (dart.library.html) 'cloud_file_service_web.dart';

CloudFileService createCloudFileService() => createPlatformCloudFileService();
