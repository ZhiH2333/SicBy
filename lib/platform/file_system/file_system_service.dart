import '../../services/file_system_service.dart';
import 'file_system_service_io.dart'
    if (dart.library.html) 'file_system_service_web.dart';

FileSystemService createFileSystemService() => createPlatformFileSystemService();
