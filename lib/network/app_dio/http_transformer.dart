import 'dart:async';

import 'package:dio/dio.dart';
import 'package:enum_to_string/enum_to_string.dart';
import 'package:fehviewer/common/global.dart';
import 'package:fehviewer/common/parser/eh_parser.dart';
import 'package:fehviewer/common/parser/mpv_parser.dart';
import 'package:fehviewer/const/const.dart';
import 'package:fehviewer/models/base/eh_models.dart';
import 'package:fehviewer/pages/gallery/controller/archiver_controller.dart';
import 'package:flutter/foundation.dart';

import 'exception.dart';
import 'http_response.dart';

/// Response 解析
abstract class HttpTransformer {
  FutureOr<DioHttpResponse<dynamic>> parse(Response response);
}

class DefaultHttpTransformer extends HttpTransformer {
// 假设接口返回类型
//   {
//     "code": 100,
//     "data": {},
//     "message": "success"
// }
  /// 内部构造方法，可避免外部暴露构造函数，进行实例化
  DefaultHttpTransformer._internal();

  /// 工厂构造方法，这里使用命名构造函数方式进行声明
  factory DefaultHttpTransformer.getInstance() => _instance;

  /// 单例对象
  static final DefaultHttpTransformer _instance =
      DefaultHttpTransformer._internal();

  @override
  FutureOr<DioHttpResponse<dynamic>> parse(Response response) {
    // if (response.data["code"] == 100) {
    //   return HttpResponse.success(response.data["data"]);
    // } else {
    // return HttpResponse.failure(errorMsg:response.data["message"],errorCode: response.data["code"]);
    // }
    return DioHttpResponse.success(response.data['data']);
  }
}

/// 画廊列表解析
class GalleryListHttpTransformer extends HttpTransformer {
  factory GalleryListHttpTransformer() => _instance;
  GalleryListHttpTransformer._internal();
  static late final GalleryListHttpTransformer _instance =
      GalleryListHttpTransformer._internal();

  @override
  FutureOr<DioHttpResponse<GalleryList>> parse(
      Response<dynamic> response) async {
    final html = response.data as String;

    // 列表样式检查 不符合则设置参数重新请求
    final bool isDml = isGalleryListDmL(html);
    if (isDml) {
      final GalleryList _list = await compute(parseGalleryList, html);

      // 查询和写入simpletag的翻译
      final _listWithTagTranslate = await _list.qrySimpleTagTranslate;

      return DioHttpResponse<GalleryList>.success(_listWithTagTranslate);
    } else {
      return DioHttpResponse<GalleryList>.failureFromError(
          ListDisplayModeException());
    }
  }
}

/// 画廊列表解析 - 收藏夹页
class FavoriteListHttpTransformer extends HttpTransformer {
  factory FavoriteListHttpTransformer() => _instance;
  FavoriteListHttpTransformer._internal();
  static late final FavoriteListHttpTransformer _instance =
      FavoriteListHttpTransformer._internal();

  @override
  FutureOr<DioHttpResponse<GalleryList>> parse(
      Response<dynamic> response) async {
    final html = response.data as String;

    // 排序方式检查
    final FavoriteOrder order = EnumToString.fromString(
            FavoriteOrder.values, Global.profile.ehConfig.favoritesOrder) ??
        FavoriteOrder.fav;
    // 排序参数
    final String _order = EHConst.favoriteOrder[order] ?? EHConst.FAV_ORDER_FAV;
    // final bool isOrderFav = isFavoriteOrder(html);
    final bool isOrderFav = await compute(isFavoriteOrder, html);

    final bool needReOrder = isOrderFav ^ (order == FavoriteOrder.fav);

    // 列表样式检查 不符合则设置参数重新请求
    // final bool isDml = isGalleryListDmL(html);
    final bool isDml = await compute(isGalleryListDmL, html);

    if (!isDml) {
      return DioHttpResponse<GalleryList>.failureFromError(
          ListDisplayModeException());
    } else if (needReOrder) {
      return DioHttpResponse<GalleryList>.failureFromError(
          FavOrderException(order: _order));
    } else {
      final GalleryList _list = await compute(parseGalleryListOfFav, html);

      // 查询和写入simpletag的翻译
      final _listWithTagTranslate = await _list.qrySimpleTagTranslate;

      return DioHttpResponse<GalleryList>.success(_listWithTagTranslate);
    }
  }
}

/// 画廊解析
class GalleryHttpTransformer extends HttpTransformer {
  factory GalleryHttpTransformer() => _instance;
  GalleryHttpTransformer._internal();
  static late final GalleryHttpTransformer _instance =
      GalleryHttpTransformer._internal();

  @override
  FutureOr<DioHttpResponse<GalleryItem>> parse(
      Response<dynamic> response) async {
    final html = response.data as String;
    final GalleryItem item = await parseGalleryDetail(html);
    return DioHttpResponse<GalleryItem>.success(item);
  }
}

class GalleryImageHttpTransformer extends HttpTransformer {
  factory GalleryImageHttpTransformer() => _instance;
  GalleryImageHttpTransformer._internal();
  static late final GalleryImageHttpTransformer _instance =
      GalleryImageHttpTransformer._internal();

  @override
  FutureOr<DioHttpResponse<GalleryImage>> parse(
      Response<dynamic> response) async {
    final html = response.data as String;
    final GalleryImage image = await compute(paraImage, html);
    return DioHttpResponse<GalleryImage>.success(image);
  }
}

class GalleryMpvImageHttpTransformer extends HttpTransformer {
  GalleryMpvImageHttpTransformer(this.ser);

  final String ser;

  @override
  FutureOr<DioHttpResponse<GalleryImage>> parse(
      Response<dynamic> response) async {
    final html = response.data as String;
    final mpvImage = await compute(parserMpvImage, html);

    // 请求 api 获取大图信息

    return DioHttpResponse<GalleryImage>.success(GalleryImage(ser: 1));
  }
}

class GalleryImageListHttpTransformer extends HttpTransformer {
  factory GalleryImageListHttpTransformer() => _instance;
  GalleryImageListHttpTransformer._internal();
  static late final GalleryImageListHttpTransformer _instance =
      GalleryImageListHttpTransformer._internal();

  @override
  FutureOr<DioHttpResponse<List<GalleryImage>>> parse(
      Response<dynamic> response) async {
    final html = response.data as String;
    // final List<GalleryImage> image = parseGalleryImageFromHtml(html);
    final List<GalleryImage> image =
        await compute(parseGalleryImageFromHtml, html);

    return DioHttpResponse<List<GalleryImage>>.success(image);
  }
}

class GalleryArchiverHttpTransformer extends HttpTransformer {
  factory GalleryArchiverHttpTransformer() => _instance;
  GalleryArchiverHttpTransformer._internal();
  static late final GalleryArchiverHttpTransformer _instance =
      GalleryArchiverHttpTransformer._internal();

  @override
  FutureOr<DioHttpResponse<ArchiverProvider>> parse(
      Response<dynamic> response) async {
    final html = response.data as String;
    final ArchiverProvider archiverProvider = parseArchiver(html);
    return DioHttpResponse<ArchiverProvider>.success(archiverProvider);
  }
}

class GalleryArchiverRemoteDownloadResponseTransformer extends HttpTransformer {
  factory GalleryArchiverRemoteDownloadResponseTransformer() => _instance;
  GalleryArchiverRemoteDownloadResponseTransformer._internal();
  static late final GalleryArchiverRemoteDownloadResponseTransformer _instance =
      GalleryArchiverRemoteDownloadResponseTransformer._internal();

  @override
  FutureOr<DioHttpResponse<String>> parse(Response<dynamic> response) async {
    final html = response.data as String;
    final String msg = parseArchiverDownload(html);
    return DioHttpResponse<String>.success(msg);
  }
}

class GalleryArchiverLocalDownloadResponseTransformer extends HttpTransformer {
  factory GalleryArchiverLocalDownloadResponseTransformer() => _instance;
  GalleryArchiverLocalDownloadResponseTransformer._internal();
  static late final GalleryArchiverLocalDownloadResponseTransformer _instance =
      GalleryArchiverLocalDownloadResponseTransformer._internal();

  @override
  FutureOr<DioHttpResponse<String>> parse(Response<dynamic> response) async {
    final html = response.data as String;
    final String _href =
        RegExp(r'document.location = "(.+)"').firstMatch(html)?.group(1) ?? '';
    return DioHttpResponse<String>.success('$_href?start=1');
  }
}

class UconfigHttpTransformer extends HttpTransformer {
  factory UconfigHttpTransformer() => _instance;
  UconfigHttpTransformer._internal();
  static late final UconfigHttpTransformer _instance =
      UconfigHttpTransformer._internal();

  @override
  FutureOr<DioHttpResponse<EhSettings>> parse(
      Response<dynamic> response) async {
    final html = response.data as String;
    final EhSettings uconfig = await compute(parseUconfig, html);
    return DioHttpResponse<EhSettings>.success(uconfig);
  }
}
