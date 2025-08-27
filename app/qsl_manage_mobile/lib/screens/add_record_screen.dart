import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/server_agent_provider.dart';
import '../services/handle_transaction.dart';
import '../widgets/record_form.dart';

class AddRecordScreen extends StatefulWidget {
  @override
  _AddRecordScreenState createState() => _AddRecordScreenState();
}

class _AddRecordScreenState extends State<AddRecordScreen> {
  final List<Map<String, dynamic>> _pendingRecords = [];
  bool _isSubmitting = false;

  void _addRecord(Map<String, dynamic> record) {
    setState(() {
      _pendingRecords.add(record);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('记录已添加到待提交列表')),
    );
  }

  Future<void> _submitAllRecords() async {
    if (_pendingRecords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('没有待提交的记录')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final serverAgent = Provider.of<ServerAgentProvider>(context, listen: false).serverAgent;
    if (serverAgent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('服务器连接错误')),
      );
      setState(() {
        _isSubmitting = false;
      });
      return;
    }

    // 按顺序提交所有记录
    for (var record in List.from(_pendingRecords)) {
      OperationResult result = await serverAgent.add(
        record['id'], // 假设callsign使用id
        record,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );

      if (result.status) {
        setState(() {
          _pendingRecords.remove(record);
        });
      } else {
        // 如果某条记录失败，停止提交后续记录
        break;
      }
    }

    setState(() {
      _isSubmitting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('添加记录')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: RecordForm(
                  onSubmit: _addRecord,
                ),
              ),
            ),
            SizedBox(height: 20),
            if (_pendingRecords.isNotEmpty)
              Column(
                children: [
                  Text(
                    '待提交记录: ${_pendingRecords.length}',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  _isSubmitting
                      ? CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: _submitAllRecords,
                          child: Text('提交所有记录'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            minimumSize: Size(double.infinity, 50),
                          ),
                        ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
