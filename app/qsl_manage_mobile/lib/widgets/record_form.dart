import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RecordForm extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final Function(Map<String, dynamic>) onSubmit;
  final bool isEditing;

  const RecordForm({
    super.key,
    this.initialData,
    required this.onSubmit,
    this.isEditing = false,
  });

  @override
  _RecordFormState createState() => _RecordFormState();
}

class _RecordFormState extends State<RecordForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _idController = TextEditingController();
  bool _sent = false;
  bool _received = false;
  DateTime? _sentDate;
  DateTime? _receivedDate;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      final data = widget.initialData!;
      _idController.text = data['QSLCardId'].toString();
      _sent = data['Sent'] == 1;
      _received = data['Received'] == 1;
      
      if (data['SentDate'] != null && data['SentDate'].toString().isNotEmpty) {
        try {
          _sentDate = DateFormat('yyyy-MM-dd').parse(data['SentDate']);
        } catch (e) {
          // 处理日期解析错误
        }
      }
      
      if (data['ReceivedDate'] != null && data['ReceivedDate'].toString().isNotEmpty) {
        try {
          _receivedDate = DateFormat('yyyy-MM-dd').parse(data['ReceivedDate']);
        } catch (e) {
          // 处理日期解析错误
        }
      }
    }
  }

  Future<void> _selectDate(bool isSentDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isSentDate) {
          _sentDate = picked;
        } else {
          _receivedDate = picked;
        }
      });
    }
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSubmitting = true;
      });

      final Map<String, dynamic> data = {};
      
      if (!widget.isEditing) {
        data['id'] = _idController.text.trim();
      }
      
      data['sent'] = _sent;
      data['received'] = _received;
      
      if (_sent && _sentDate != null) {
        data['sent_date'] = DateFormat('yyyy-MM-dd').format(_sentDate!);
      }
      
      if (_received && _receivedDate != null) {
        data['received_date'] = DateFormat('yyyy-MM-dd').format(_receivedDate!);
      }

      widget.onSubmit(data);
      
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          if (!widget.isEditing)
            TextFormField(
              controller: _idController,
              decoration: InputDecoration(
                labelText: '呼号',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '呼号为必填项';
                }
                return null;
              },
              enabled: !_isSubmitting,
            ),
          SizedBox(height: 16),
          Row(
            children: [
              Checkbox(
                value: _sent,
                onChanged: _isSubmitting
                    ? null
                    : (value) {
                        setState(() {
                          _sent = value ?? false;
                        });
                      },
              ),
              Text('已发送'),
              SizedBox(width: 20),
              if (_sent)
                ElevatedButton(
                  onPressed: _isSubmitting ? null : () => _selectDate(true),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: Text(_sentDate != null
                      ? DateFormat('yyyy-MM-dd').format(_sentDate!)
                      : '选择发送日期'),
                ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Checkbox(
                value: _received,
                onChanged: _isSubmitting
                    ? null
                    : (value) {
                        setState(() {
                          _received = value ?? false;
                        });
                      },
              ),
              Text('已接收'),
              SizedBox(width: 20),
              if (_received)
                ElevatedButton(
                  onPressed: _isSubmitting ? null : () => _selectDate(false),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: Text(_receivedDate != null
                      ? DateFormat('yyyy-MM-dd').format(_receivedDate!)
                      : '选择接收日期'),
                ),
            ],
          ),
          SizedBox(height: 24),
          _isSubmitting
              ? CircularProgressIndicator()
              : ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 50),
                  ),
                  child: Text(widget.isEditing ? '更新记录' : '添加记录'),
                ),
        ],
      ),
    );
  }
}
