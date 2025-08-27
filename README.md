# Qsl Manage  


  Qsl Manage是一个帮助站台更好地管理QSL卡片的项目。项目由三个部分组成：
- 管理后端：包含D1数据库用于管理卡片信息、KV数据库用于管理用户（对集体电台来说）、以及一个cf worker后端用于和网页前端及app的交互。
- 网页前端：cf page，用于开放给其他站台，用于查询Qsl卡信息。
- Android App：flutter构建的安卓应用，用于本站台人员管理更新卡片信息。


## How to use/使用指南

### Before Starting/开始之前  
请确保已经安装了nodejs，推荐使用[nvs](https://github.com/jasongin/nvs)进行nodejs版本管理。如果要自行构建安卓App（在app/目录下），需要配置[Flutter](https://docs.flutter.cn/get-started/install/windows/mobile)和[Android Studio](https://developer.android.com/studio/install#windows)开发环境。  

### 开始部署


下载此项目：  
```bash
git clone 
cd 
```
1. 首先部署后端。在qsl-manager/wrangler.jsonc中配置好数据库、定时任务等，然后执行以下命令完成数据库初始化：
```bash
cd qsl-manager
# 安装依赖 
npm install 
# 初始化数据库，注意原有的QSLInfo表会被删除
npx wrangler d1 execute qsl_manger --remote --file=./schema.sql
```  
然后部署后端worker服务：
```bash
npx wrangler deploy 
```
部署好后可以在worker的设置-变量和机密里设置两个密钥`API_SECRET`和`JWT_PUBLIC_KEY`分别作为API口令（用于编辑用户，推荐管理员保管）和鉴权公钥（用于用户登录鉴权及token分发，建议至少128位并严格保密），之后可以绑定自定义域名。    
2. 部署网页前端，在web/config.js中配置好后端地址，然后新建一个pages项目，将整个web文件夹拖进去部署即可，可自定义域名并在台站主页公开。    
3. App端配置及编译：请见app/README.md。  