import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/backend_provider.dart';
import 'login_screen.dart';

class BackendSetupScreen extends StatefulWidget {
  @override
  _BackendSetupScreenState createState() => _BackendSetupScreenState();
}

class _BackendSetupScreenState extends State<BackendSetupScreen> {
  final TextEditingController _backendController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('设置后端地址')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextFormField(
                controller: _backendController,
                decoration: InputDecoration(
                  labelText: 'Backend 地址',
                  hintText: '请输入后端服务地址',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入后端地址';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    await Provider.of<BackendProvider>(context, listen: false)
                        .saveBackend(_backendController.text.trim());
                    
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LoginScreen(
                          backend: _backendController.text.trim(),
                        ),
                      ),
                    );
                  }
                },
                child: Text('确认'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
