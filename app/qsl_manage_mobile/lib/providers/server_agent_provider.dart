import 'package:flutter/foundation.dart';
import '../services/handle_transaction.dart';

class ServerAgentProvider extends ChangeNotifier {
  ServerAgent? _serverAgent;

  ServerAgent? get serverAgent => _serverAgent;

  void initServerAgent(String backend) async{
    _serverAgent = await ServerAgent.create(backend);
    notifyListeners();
  }

  void disposeServerAgent() {
    _serverAgent = null;
    notifyListeners();
  }
}
