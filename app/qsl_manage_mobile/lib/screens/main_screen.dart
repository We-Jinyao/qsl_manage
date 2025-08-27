import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/backend_provider.dart';
import '../providers/server_agent_provider.dart';
import '../services/auth_service.dart';
import 'add_record_screen.dart';
import 'edit_record_screen.dart';
import 'login_screen.dart';
import 'backend_setup_screen.dart';
import 'package:flutter/services.dart';

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final TextEditingController _backendController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final backend = Provider.of<BackendProvider>(context, listen: false).backend;
    if (backend != null) {
      _backendController.text = backend;
    }
  }

  Future<void> _logout() async {
    setState(() {
      _isLoading = true;
    });

    await AuthService.logout();
    Provider.of<ServerAgentProvider>(context, listen: false).disposeServerAgent();

    setState(() {
      _isLoading = false;
    });

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => LoginScreen(
          backend: Provider.of<BackendProvider>(context, listen: false).backend!,
        ),
      ),
    );
  }

  Future<void> _updateBackend() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      await Provider.of<BackendProvider>(context, listen: false)
          .saveBackend(_backendController.text.trim());
      
      // 重新初始化ServerAgent
      Provider.of<ServerAgentProvider>(context, listen: false)
          .initServerAgent(_backendController.text.trim());

      // 显示成功消息
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backend地址已更新')),
      );

      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('主页面')),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
              ),
              child: Text(
                '功能菜单',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.add),
              title: Text('添加记录'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/add-record');
              },
            ),
            ListTile(
              leading: Icon(Icons.edit),
              title: Text('编辑记录'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/edit-record');
              },
            ),
            ListTile(
              leading: Icon(Icons.logout),
              title: Text('退出登录'),
              onTap: () {
                Navigator.pop(context);
                _logout();
              },
            ),
          ],
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _backendController,
                    decoration: InputDecoration(
                      labelText: 'Backend 地址',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入后端地址';
                      }
                      return null;
                    },
                    enabled: !_isLoading,
                  ),
                  SizedBox(height: 16),
                  _isLoading
                      ? CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: _updateBackend,
                          child: Text('更新Backend'),
                        ),
                ],
              ),
            ),
            SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _logout,
              child: Text('登出'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
