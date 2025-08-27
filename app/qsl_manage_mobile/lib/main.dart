import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/backend_provider.dart';
import 'providers/server_agent_provider.dart';
import 'screens/backend_setup_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'utils/storage_utils.dart';
import 'services/auth_service.dart';
import 'screens/add_record_screen.dart';
import 'screens/edit_record_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageUtils.init();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BackendProvider()),
        ChangeNotifierProvider(create: (_) => ServerAgentProvider()),
      ],
      child: MaterialApp(
        title: 'Backend App',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: InitialScreen(),
        routes: {
          '/main': (context) => MainScreen(),
          '/add-record': (context) => AddRecordScreen(),
          '/edit-record': (context) => EditRecordScreen(),
        },
      ),
    );
  }
}

class InitialScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final backendProvider = Provider.of<BackendProvider>(context, listen: false);
    
    return FutureBuilder<String?>(
      future: backendProvider.loadBackend(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
        if (snapshot.data == null) {
          return BackendSetupScreen();
        } else {
          return FutureBuilder<bool>(
            future: AuthService.isLoggedIn(snapshot.data!),
            builder: (context, loginSnapshot) {
              if (loginSnapshot.connectionState == ConnectionState.waiting) {
                return Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              
              if (loginSnapshot.data == true) {
                Provider.of<ServerAgentProvider>(context, listen: false)
                    .initServerAgent(snapshot.data!);
                return MainScreen();
              } else {
                return LoginScreen(backend: snapshot.data!);
              }
            },
          );
        }
      },
    );
  }
}
