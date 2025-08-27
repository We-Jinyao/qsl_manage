import 'package:flutter/foundation.dart';
import '../utils/storage_utils.dart';

class BackendProvider extends ChangeNotifier {
  String? _backend;

  String? get backend => _backend;

  Future<String?> loadBackend() async {
    _backend = StorageUtils.getString('backend');
    notifyListeners();
    return _backend;
  }

  Future<void> saveBackend(String backend) async {
    _backend = backend;
    await StorageUtils.setString('backend', backend);
    notifyListeners();
  }

  Future<void> clearBackend() async {
    _backend = null;
    await StorageUtils.remove('backend');
    notifyListeners();
  }
}
