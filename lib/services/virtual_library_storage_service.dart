import '../state/virtual_library_models.dart';

abstract class VirtualLibraryStorageService {
  Future<VirtualLibrarySnapshot> read();
  Future<void> write(VirtualLibrarySnapshot snapshot);
  Future<void> reset();
}
