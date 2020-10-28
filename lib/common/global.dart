import 'dart:convert';

import 'package:FEhViewer/common/tag_database.dart';
import 'package:FEhViewer/models/index.dart';
import 'package:FEhViewer/models/profile.dart';
import 'package:FEhViewer/route/application.dart';
import 'package:FEhViewer/route/routes.dart';
import 'package:FEhViewer/utils/storage.dart';
import 'package:FEhViewer/values/storages.dart';
import 'package:fluro/fluro.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

// 全局配置
// ignore: avoid_classes_with_only_static_members
class Global {
  // 是否第一次打开
  static bool isFirstOpen = false;
  static Profile profile = Profile();

  static final logger = Logger(
    printer: PrettyPrinter(
      lineLength: 100,
      colors: false,
    ),
  );

  static final loggerNoStack = Logger(
    printer: PrettyPrinter(
      lineLength: 100,
      methodCount: 0,
      colors: false,
    ),
  );

  // init
  static Future init() async {
    // 运行初始
    WidgetsFlutterBinding.ensureInitialized();

    //statusBar设置为透明，去除半透明遮罩
    const SystemUiOverlayStyle _style =
        SystemUiOverlayStyle(statusBarColor: Colors.transparent);
    SystemChrome.setSystemUIOverlayStyle(_style);

    // 工具初始
    await StorageUtil.init();

    try {
      EhTagDatabase.generateTagTranslat();
    } catch (e) {
      debugPrint('更新翻译异常 $e');
    }

    final _profile = StorageUtil().getJSON(PROFILE);
    if (_profile != null) {
      try {
        profile = Profile.fromJson(jsonDecode(_profile));
      } catch (e) {
        print(e);
      }
    }

    if (profile.ehConfig == null) {
      profile.ehConfig = EhConfig()
        ..siteEx = false
        ..tagTranslat = false
        ..jpnTitle = false
        ..favLongTap = false
        ..favPicker = false
        ..galleryImgBlur = false;
      saveProfile();
    }

    // 路由
    final FluroRouter router = FluroRouter();
    EHRoutes.configureRoutes(router);
    Application.router = router;

    // 读取设备第一次打开
    isFirstOpen = !StorageUtil().getBool(STORAGE_DEVICE_ALREADY_OPEN_KEY);
    if (isFirstOpen) {
      StorageUtil().setBool(STORAGE_DEVICE_ALREADY_OPEN_KEY, true);
    }
  }

  // 持久化Profile信息
  static saveProfile() {
//    logger.v(profile.toJson());
    return StorageUtil().setJSON(PROFILE, profile);
  }
}
