import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/server_agent_provider.dart';
import '../services/handle_transaction.dart';
import '../widgets/record_form.dart';

class EditRecordScreen extends StatefulWidget {
  @override
  _EditRecordScreenState createState() => _EditRecordScreenState();
}

class _EditRecordScreenState extends State<EditRecordScreen> {
  final TextEditingController _idController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  List<Map<String, dynamic>> _records = [];
  bool _isLoading = false;
  Map<String, bool> _deletedRecords = {};
  Map<String, bool> _updatedRecords = {};

  Future<void> _queryRecords() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final serverAgent = Provider.of<ServerAgentProvider>(context, listen: false).serverAgent;
      if (serverAgent == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('服务器连接错误')),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      OperationResult result = await serverAgent.query(_idController.text.trim());

      if (result.status && result.result != null) {
        setState(() {
          _records = List<Map<String, dynamic>>.from(result.result);
          // 重置状态跟踪
          _deletedRecords = {};
          _updatedRecords = {};
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message)),
        );
      }

      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteRecord(String cardId) async {
    setState(() {
      _isLoading = true;
    });

    final serverAgent = Provider.of<ServerAgentProvider>(context, listen: false).serverAgent;
    if (serverAgent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('服务器连接错误')),
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    OperationResult result = await serverAgent.delete(cardId);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );

    if (result.status) {
      setState(() {
        _deletedRecords[cardId] = true;
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _updateRecord(String cardId, Map<String, dynamic> data) async {
    setState(() {
      _isLoading = true;
    });

    final serverAgent = Provider.of<ServerAgentProvider>(context, listen: false).serverAgent;
    if (serverAgent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('服务器连接错误')),
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    OperationResult result = await serverAgent.update(cardId, data);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );

    if (result.status) {
      setState(() {
        _updatedRecords[cardId] = true;
        // 更新本地记录数据
        final index = _records.indexWhere((r) => r['QSLCardId'].toString() == cardId);
        if (index != -1) {
          _records[index] = {
            ..._records[index],
            'Sent': data['sent'] ? 1 : 0,
            'Received': data['received'] ? 1 : 0,
            if (data.containsKey('sentDate')) 'SentDate': data['sentDate'],
            if (data.containsKey('receivedDate')) 'ReceivedDate': data['receivedDate'],
          };
        }
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _showEditDialog(Map<String, dynamic> record) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('修改记录'),
        content: SingleChildScrollView(
          child: RecordForm(
            initialData: record,
            onSubmit: (data) {
              Navigator.pop(context);
              _updateRecord(record['QSLCardId'].toString(), data);
            },
            isEditing: true,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('编辑记录')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            Form(
              key: _formKey,
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _idController,
                      decoration: InputDecoration(
                        labelText: '查询呼号',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '请输入呼号';
                        }
                        if (value.length < 3 || value.length > 8) {
                          return '呼号长度必须为3-8位';
                        }
                        if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(value)) {
                          return '呼号只能包含字母和数字';
                        }
                        return null;
                      },
                      enabled: !_isLoading,
                    ),
                  ),
                  SizedBox(width: 10),
                  _isLoading
                      ? CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: _queryRecords,
                          child: Text('查询'),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                          ),
                        ),
                ],
              ),
            ),
            SizedBox(height: 20),
            Expanded(
              child: _records.isEmpty
                  ? Center(child: Text('请输入呼号并查询记录'))
                  : ListView.builder(
                      itemCount: _records.length,
                      itemBuilder: (context, index) {
                        final record = _records[index];
                        final cardId = record['QSLCardId'].toString();
                        final isDeleted = _deletedRecords[cardId] ?? false;
                        final isUpdated = _updatedRecords[cardId] ?? false;

                        return Card(
                          color: isUpdated ? Colors.grey[200] : null,
                          child: ListTile(
                            title: Text(
                              '呼号: ${record['ToCallsign']}',
                              style: TextStyle(
                                decoration: isDeleted ? TextDecoration.lineThrough : TextDecoration.none,
                                color: isDeleted ? Colors.grey : null,
                                inherit: true, // 确保inherit属性一致
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '已发送: ${record['Sent'] == 1 ? '是' : '否'}',
                                  style: TextStyle(
                                    decoration: isDeleted ? TextDecoration.lineThrough : TextDecoration.none,
                                    color: isDeleted ? Colors.grey : null,
                                    inherit: true, // 确保inherit属性一致
                                  ),
                                ),
                                if (record['Sent'] == 1 && record['SentDate'] != null)
                                  Text(
                                    '发送日期: ${record['SentDate']}',
                                    style: TextStyle(
                                      decoration: isDeleted ? TextDecoration.lineThrough : TextDecoration.none,
                                      color: isDeleted ? Colors.grey : null,
                                      inherit: true, // 确保inherit属性一致
                                    ),
                                  ),
                                Text(
                                  '已接收: ${record['Received'] == 1 ? '是' : '否'}',
                                  style: TextStyle(
                                    decoration: isDeleted ? TextDecoration.lineThrough : TextDecoration.none,
                                    color: isDeleted ? Colors.grey : null,
                                    inherit: true, // 确保inherit属性一致
                                  ),
                                ),
                                if (record['Received'] == 1 && record['ReceivedDate'] != null)
                                  Text(
                                    '接收日期: ${record['ReceivedDate']}',
                                    style: TextStyle(
                                      decoration: isDeleted ? TextDecoration.lineThrough : TextDecoration.none,
                                      color: isDeleted ? Colors.grey : null,
                                      inherit: true, // 确保inherit属性一致
                                    ),
                                  ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: (isDeleted || isUpdated || _isLoading)
                                      ? null
                                      : () => _showEditDialog(record),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: (isDeleted || _isLoading)
                                      ? null
                                      : () => _deleteRecord(cardId),
                                ),
                              ],
                            ),
                          ),
                        );

                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
