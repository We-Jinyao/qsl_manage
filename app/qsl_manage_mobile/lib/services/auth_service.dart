
import 'package:dio/dio.dart';
import '../utils/storage_utils.dart';
class AuthService{
  static final String bearerTokenType = 'JWT';
  static Future<String?> getToken() async{
    // final cookies = await SharedPreferences.getInstance();
    // return cookies.getString('bearer_token');
    return StorageUtils.getString("bearer_token");
  }


  static Future<void> removeToken() async{
    if(StorageUtils.getString("bearer_token")!=null){
      await StorageUtils.remove("bearer_token");
    }
  }

  static Future<bool> isLoggedIn(String backend) async{
    final token = await getToken();
    if(token==null){
      return false;
    }
    if(await isLegalCookie(token, backend)){
      return true;
    }else{
      await removeToken();
    }
    return false;
  }

  static Future<bool> isLegalCookie(String? cookie, String backend) async{
    if(cookie==null){
      return false;
    }
    if(bearerTokenType=='JWT' && await isTokenExperied(backend, cookie)){
      return true;
    }
    return false;
  }

  static Future<bool> login(String username, String passwd, String backend) async{
    Dio dio = Dio();
    Response resp;
    resp = await dio.post("$backend/login", data: {"username":username, "password":passwd});
    if(resp.statusCode!=200){
      return false;
    }
    if(resp.data is Map){
      final token = resp.data["token"];
      await StorageUtils.setString('bearer_token', 'Bearer $token');
      return true;
    }
    return false;
  }

  static Future<void> logout() async {
    await removeToken();
  }

  static Future<bool> isTokenExperied(String backend, String token) async{
    Dio dio = Dio();
    Response resp = await dio.post(
        "$backend/isAuthenticated",
        options: Options(
          headers: {
            "Authorization": token,
          }
        )
    );
    if(resp.statusCode==200){
      return true;
    }
    return false;
  }
}
