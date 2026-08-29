import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:xml/xml.dart';

/// 坚果云等 WebDAV 服务的连接凭据。按请求注入，客户端本身不持有也不持久化凭据。
class WebDavCredentials {
  final String url;
  final String user;
  final String token;

  const WebDavCredentials(
      {required this.url, required this.user, required this.token});
}

/// 云端备份条目（PROPFIND 解析结果）。
class CloudBackupEntry {
  final String name;
  final DateTime? exportedAt;
  final int sizeBytes;

  const CloudBackupEntry(
      {required this.name, this.exportedAt, this.sizeBytes = 0});
}

/// 连接测试结果（ok=false 时 message 直接面向用户）。
class SyncTestResult {
  final bool ok;
  final String message;

  const SyncTestResult(this.ok, this.message);
}

/// WebDAV 业务异常：认证失败 / 远端错误 / 参数缺失，message 面向用户。
class SyncException implements Exception {
  final String message;

  const SyncException(this.message);

  @override
  String toString() => message;
}

/// 坚果云等 WebDAV 服务封装（移植自 SmartVault WebDavClient.cs）。
/// 仅承载协议能力；诊断信息不打印账号 / 应用密码。
/// 方法均为可覆写虚方法，测试中用子类替换网络部分。
class WebDavClient {
  /// 云端固定备份目录名（位于 WebDAV 根下）。
  static const remoteDir = 'WarmPantry';

  /// PROPFIND 请求体：索取大小、修改时间、资源类型。
  static const _propfindBody =
      '<?xml version="1.0" encoding="utf-8"?><D:propfind xmlns:D="DAV:">'
      '<D:prop><D:getcontentlength/><D:getlastmodified/><D:resourcetype/></D:prop>'
      '</D:propfind>';

  static const _timeout = Duration(seconds: 15);

  final HttpClient _http = HttpClient()..connectionTimeout = _timeout;

  void close() => _http.close();

  /// 测试连接：对根目录发 Depth:0 的 PROPFIND，验证凭据与可达性。
  Future<SyncTestResult> testConnection(WebDavCredentials c) async {
    try {
      final resp = await _propfind(c, _baseUri(c), depth: '0');
      await resp.drain<void>();
      if (_authFailed(resp.statusCode)) {
        return const SyncTestResult(false, '认证失败，请检查账号与应用密码');
      }
      if (!_okOrMultiStatus(resp.statusCode)) {
        return SyncTestResult(false, '服务器返回 ${resp.statusCode}');
      }
      return const SyncTestResult(true, '连接成功');
    } on SyncException catch (e) {
      return SyncTestResult(false, e.message);
    } on TimeoutException {
      return const SyncTestResult(false, '连接超时，请检查网络');
    } on SocketException catch (e) {
      return SyncTestResult(false, '网络错误：${e.message}');
    } on HttpException catch (e) {
      return SyncTestResult(false, '网络错误：${e.message}');
    }
  }

  /// 列出云端备份目录下全部 .zip 备份，按时间倒序。
  Future<List<CloudBackupEntry>> listBackups(WebDavCredentials c) => _guard(() async {
        final resp = await _propfind(c, _dirUri(c), depth: '1');
        if (_authFailed(resp.statusCode)) {
          await resp.drain<void>();
          throw const SyncException('认证失败，请检查账号与应用密码');
        }
        // 目录不存在视为空列表（用户尚未上传过），不报错
        if (resp.statusCode == HttpStatus.notFound) {
          await resp.drain<void>();
          return const <CloudBackupEntry>[];
        }
        if (!_okOrMultiStatus(resp.statusCode)) {
          await resp.drain<void>();
          throw SyncException('读取云端列表失败：${resp.statusCode}');
        }
        final body = await utf8.decoder.bind(resp).join();
        return parsePropfindEntries(body);
      });

  /// 确保云端备份目录存在（已存在则跳过）。
  Future<void> ensureDir(WebDavCredentials c) => _guard(() async {
        final resp = await _send(c, 'MKCOL', _dirUri(c));
        await resp.drain<void>();
        // 201 新建 / 405 已存在（方法不允许）/ 200 某些服务器已存在都视为成功
        if (resp.statusCode == HttpStatus.created ||
            resp.statusCode == HttpStatus.methodNotAllowed ||
            resp.statusCode == HttpStatus.ok) {
          return;
        }
        throw SyncException('创建云端目录失败：${resp.statusCode}');
      });

  /// 上传字节内容到云端指定文件名（覆盖同名）。
  Future<void> put(WebDavCredentials c, String name, List<int> content) =>
      _guard(() async {
        final resp = await _send(c, 'PUT', _fileUri(c, name), body: content, contentType: 'application/zip');
        await resp.drain<void>();
        _throwIfAuthFailed(resp.statusCode);
        if (resp.statusCode < 200 || resp.statusCode >= 300) {
          throw SyncException('上传失败：${resp.statusCode}');
        }
      });

  /// 下载云端指定备份为字节数组。
  Future<List<int>> download(WebDavCredentials c, String name) =>
      _guard(() async {
        final resp = await _send(c, 'GET', _fileUri(c, name));
        _throwIfAuthFailed(resp.statusCode);
        if (resp.statusCode == HttpStatus.notFound) {
          await resp.drain<void>();
          throw const SyncException('云端备份不存在或已被删除');
        }
        if (resp.statusCode < 200 || resp.statusCode >= 300) {
          await resp.drain<void>();
          throw SyncException('下载失败：${resp.statusCode}');
        }
        return await resp.expand((chunk) => chunk).toList();
      });

  /// 删除云端指定备份（不存在视为成功）。
  Future<void> delete(WebDavCredentials c, String name) => _guard(() async {
        final resp = await _send(c, 'DELETE', _fileUri(c, name));
        await resp.drain<void>();
        _throwIfAuthFailed(resp.statusCode);
        if ((resp.statusCode < 200 || resp.statusCode >= 300) &&
            resp.statusCode != HttpStatus.notFound) {
          throw SyncException('删除失败：${resp.statusCode}');
        }
      });

  // ============ 协议细节 ============

  Future<HttpClientResponse> _propfind(
          WebDavCredentials c, Uri uri, {required String depth}) =>
      _guard(() => _send(c, 'PROPFIND', uri,
          body: utf8.encode(_propfindBody),
          contentType: 'application/xml',
          extraHeaders: {'Depth': depth}));

  Future<HttpClientResponse> _send(
    WebDavCredentials c,
    String method,
    Uri uri, {
    List<int>? body,
    String? contentType,
    Map<String, String> extraHeaders = const {},
  }) async {
    final req = await _http.openUrl(method, uri).timeout(_timeout);
    req.headers.set(HttpHeaders.authorizationHeader,
        'Basic ${base64Encode(utf8.encode('${c.user}:${c.token}'))}');
    if (contentType != null) {
      req.headers.set(HttpHeaders.contentTypeHeader, contentType);
    }
    extraHeaders.forEach(req.headers.set);
    if (body != null) {
      req.headers.contentLength = body.length;
      req.add(body);
    }
    return req.close().timeout(_timeout);
  }

  /// 网络层异常统一转业务异常；超时略短于用户耐心阈值，给足坚果云响应窗口。
  Future<T> _guard<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } on SyncException {
      rethrow;
    } on TimeoutException {
      throw const SyncException('连接超时，请检查网络');
    } on SocketException catch (e) {
      throw SyncException('网络错误：${e.message}');
    } on HttpException catch (e) {
      throw SyncException('网络错误：${e.message}');
    }
  }

  static bool _authFailed(int status) =>
      status == HttpStatus.unauthorized || status == HttpStatus.forbidden;

  static void _throwIfAuthFailed(int status) {
    if (_authFailed(status)) {
      throw const SyncException('认证失败，请检查账号与应用密码');
    }
  }

  /// 2xx 或 207 MultiStatus（PROPFIND 的正常返回）。
  static bool _okOrMultiStatus(int status) =>
      (status >= 200 && status < 300) || status == 207;

  /// 规范化 WebDAV 基地址，保证以 / 结尾。
  static Uri _baseUri(WebDavCredentials c) {
    final u = c.url.trim();
    if (u.isEmpty) throw const SyncException('未配置 WebDAV 地址');
    final uri = Uri.parse(u.endsWith('/') ? u : '$u/');
    // Android usesCleartextTraffic 只约束 Java 层网络库，拦不住 dart:io
    // HttpClient；协议白名单必须在此自校验，避免凭据明文发出。
    if (uri.scheme.toLowerCase() != 'https') {
      throw const SyncException('仅支持 https 地址，请检查 WebDAV 地址');
    }
    return uri;
  }

  static Uri _dirUri(WebDavCredentials c) => _baseUri(c).resolve('$remoteDir/');

  static Uri _fileUri(WebDavCredentials c, String name) =>
      _baseUri(c).resolve('$remoteDir/$name');
}

/// 解析 PROPFIND multistatus 响应，提取 .zip 文件的名称 / 大小 / 修改时间。
/// DAV 命名空间前缀各服务器不一，按 LocalName 匹配以兼容。
/// 独立为顶层函数便于单测；解析失败不致命，返回已成功解析的部分。
List<CloudBackupEntry> parsePropfindEntries(String xml) {
  final result = <CloudBackupEntry>[];
  try {
    final doc = XmlDocument.parse(xml);
    for (final node in doc.descendants) {
      if (node is! XmlElement || node.name.local != 'response') continue;
      final href = _textOfLocal(node, 'href');
      if (href == null || href.isEmpty) continue;
      // 排除目录本身
      final isDir = node.descendants
          .any((e) => e is XmlElement && e.name.local == 'collection');
      if (isDir) continue;
      final segments =
          href.split('/').where((s) => s.isNotEmpty).toList(growable: false);
      if (segments.isEmpty) continue;
      final name = Uri.decodeComponent(segments.last);
      if (!name.toLowerCase().endsWith('.zip')) continue;
      final size =
          int.tryParse(_textOfLocal(node, 'getcontentlength') ?? '') ?? 0;
      DateTime? mtime;
      final raw = _textOfLocal(node, 'getlastmodified');
      if (raw != null) {
        try {
          mtime = HttpDate.parse(raw); // RFC1123（HTTP 日期）→ UTC
        } catch (_) {
          // 保持 null，列表仍可用文件名排序展示
        }
      }
      result.add(
          CloudBackupEntry(name: name, exportedAt: mtime, sizeBytes: size));
    }
  } catch (_) {
    // 部分解析结果仍然返回
  }
  result.sort((a, b) => (b.exportedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
      .compareTo(a.exportedAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
  return result;
}

String? _textOfLocal(XmlElement element, String local) {
  for (final d in element.descendants) {
    if (d is XmlElement && d.name.local == local) return d.innerText.trim();
  }
  return null;
}
