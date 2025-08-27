import 'dart:io';
import 'package:dio/dio.dart';
import 'auth_service.dart';

bool _isNumericOnly(String str) {
  if (str.isEmpty) return false;
  return RegExp(r'^[0-9]+$').hasMatch(str);
}

bool _isAlphanumeric(String str) {
  if (str.isEmpty) return false; // 空字符串返回false
  // 正则表达式：^表示开头，$表示结尾，[]内为允许的字符范围
  return RegExp(r'^[a-zA-Z0-9]+$').hasMatch(str);
}

class OperationResult{
  final bool status;
  final String message;
  final result;
  OperationResult({ required this.status, required this.message, this.result});
}

class ServerAgent{
  final String backend;
  final Dio _dio;


  final String _token;
  final add_params = [
    "received",
    "sent",
    "received_date",
    "sent_date"];
  ServerAgent(this.backend, this._token, this._dio);

  static Future<ServerAgent> create(String backend) async{
    String? token = await AuthService.getToken();
    if(token!=null){
      final dio =  Dio(
        BaseOptions(
          baseUrl: backend,
          connectTimeout: const Duration(seconds: 6),
          receiveTimeout: const Duration(seconds: 3),
          validateStatus: (int? status) {
            return status != null;
            },
        ),
      );
      return ServerAgent(backend, token, dio);
    }
    print("error! No valid tokrn!");
    exit(-1);
  }

  Future<OperationResult> query(String callsign) async{
    Response resp;
    resp = await _dio.get("$backend/", queryParameters: {'callsign':callsign});
    return OperationResult(
      status: resp.statusCode==200,
      message: resp.statusCode==200?'Get ${resp.data['meta']['rows_read']} results!':resp.data.toString(),
      result: resp.statusCode==200?resp.data["results"]:null
    );
  }

  Future<OperationResult> delete(String cardid) async{
    if(!_isNumericOnly(cardid)){
      return OperationResult(status: false, message: "Invalid input!");
    }
    Response resp;
    resp = await _dio.post("$backend/delete_qsl",
        data: {"qsl_card_id":cardid},
        options: Options(
            headers: {
              "Authorization": _token,
            }
        ));
    return OperationResult(
        status: resp.statusCode==200,
        message: resp.statusCode==200?"success!${resp.data}":"failed!${resp.data}"
    );
  }

  Future<OperationResult> add(String callsign, Map<String, dynamic> data) async{
    if(!(callsign.length>=3 && callsign.length<=8 && _isAlphanumeric(callsign))){
      return OperationResult(status: false, message: "Invalid input!");
    }
    Response resp;
    Map<String, dynamic> uploadData = {};
    uploadData["to_callsign"] = callsign;
    for(var i in add_params){
      if(data.containsKey(i)){
        uploadData[i] = data[i];
      }
    }
    resp = await _dio.post("$backend/add_new_qsl",
        data: uploadData,
        options: Options(
            headers: {
              "Authorization": _token,
            }
        ));
    return OperationResult(
        status: resp.statusCode==200,
        message: resp.statusCode==200?"success!${resp.data}":"failed!${resp.data}"
    );
  }

  Future<OperationResult> update(String cardid, Map<String, dynamic> data) async{
    if(data.isEmpty){
      return OperationResult(status: false, message: "Invalid input!");
    }
    Response resp;
    Map<String, dynamic> uploadData = {};
    uploadData["qsl_card_id"] = cardid;
    for(var i in add_params){
      if(data.containsKey(i)){
        uploadData[i] = data[i];
      }
    }
      resp = await _dio.post("$backend/update_qsl",
          data: uploadData,
          options: Options(
              headers: {
                "Authorization": _token,
              }
          ));
    return OperationResult(
        status: resp.statusCode==200,
        message: resp.statusCode==200?"success!${resp.data}":"failed!${resp.data}"
    );
  }


}