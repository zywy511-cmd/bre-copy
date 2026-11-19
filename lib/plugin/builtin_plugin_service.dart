import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/object_box/objectbox.g.dart';
import 'package:zephyr/plugin/plugin_install_service.dart';

/// 内置漫源「拷贝漫画 Copy4000」的 uuid。
const String kBuiltinCopy4000Uuid = '371d33c6-a901-434a-a0ae-d4ea80c7612f';

/// 内置漫源脚本在 asset 里的路径。
const String _kBuiltinCopy4000Asset = 'asset/plugin/copy4000.cjs';

/// 首次启动时把内置漫源装进插件库，用户无需手动导入。
///
/// 必须在 `PluginRegistryService.init` 之后调用（安装流程会用注册表做去重）。
///
/// 只要本地已装脚本文本与随包脚本不一致（含旧版本、被删除过），
/// 就用随包脚本覆盖，保证升级 App 后拿到的就是这一版。
/// 任何失败都只记日志，绝不影响启动。
Future<void> ensureBuiltinPluginsInstalled() async {
  try {
    final data = await rootBundle.load(_kBuiltinCopy4000Asset);
    final script = utf8
        .decode(data.buffer.asUint8List(), allowMalformed: true)
        .trim();
    if (script.isEmpty) {
      logger.w('[builtin-plugin] 内置脚本为空，跳过');
      return;
    }

    final existing = _findInfoByUuid(kBuiltinCopy4000Uuid);
    if (existing != null &&
        !existing.isDeleted &&
        existing.originScript.trim() == script) {
      return;
    }

    await PluginInstallService.I.savePluginByScript(
      script,
      sourceLabel: '内置漫源',
      allowReplaceExisting: true,
      expectedUuid: kBuiltinCopy4000Uuid,
    );
    logger.d('[builtin-plugin] 已安装/更新内置漫源: $kBuiltinCopy4000Uuid');
  } catch (e, st) {
    logger.e(e, stackTrace: st);
  }
}

PluginInfo? _findInfoByUuid(String uuid) {
  final query = objectbox.pluginInfoBox
      .query(PluginInfo_.uuid.equals(uuid))
      .build();
  try {
    return query.findFirst();
  } finally {
    query.close();
  }
}
