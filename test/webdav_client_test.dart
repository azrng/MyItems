import 'package:flutter_test/flutter_test.dart';

import 'package:warmpantry/data/services/sync_service.dart';
import 'package:warmpantry/data/services/webdav_client.dart';

/// PROPFIND multistatus 解析单测（对齐坚果云真实返回结构）。
void main() {
  test('解析 D: 前缀 multistatus：排除目录与非 zip，按时间倒序', () {
    const xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<D:multistatus xmlns:D="DAV:">
 <D:response>
  <D:href>/dav/WarmPantry/</D:href>
  <D:propstat>
   <D:prop><D:resourcetype><D:collection/></D:resourcetype></D:prop>
  </D:propstat>
 </D:response>
 <D:response>
  <D:href>/dav/WarmPantry/warmpantry-20260829-080000.zip</D:href>
  <D:propstat>
   <D:prop>
    <D:resourcetype/>
    <D:getcontentlength>1024</D:getcontentlength>
    <D:getlastmodified>Sat, 29 Aug 2026 08:00:00 GMT</D:getlastmodified>
   </D:prop>
  </D:propstat>
 </D:response>
 <D:response>
  <D:href>/dav/WarmPantry/warmpantry-20260828-070000.zip</D:href>
  <D:propstat>
   <D:prop>
    <D:resourcetype/>
    <D:getcontentlength>2048</D:getcontentlength>
    <D:getlastmodified>Fri, 28 Aug 2026 07:00:00 GMT</D:getlastmodified>
   </D:prop>
  </D:propstat>
 </D:response>
 <D:response>
  <D:href>/dav/WarmPantry/notes.txt</D:href>
  <D:propstat>
   <D:prop><D:resourcetype/><D:getcontentlength>10</D:getcontentlength></D:prop>
  </D:propstat>
 </D:response>
</D:multistatus>
''';
    final entries = parsePropfindEntries(xml);
    expect(entries.length, 2, reason: '目录本身与 txt 不计入');
    expect(entries.map((e) => e.name).toList(), [
      'warmpantry-20260829-080000.zip',
      'warmpantry-20260828-070000.zip',
    ], reason: '按修改时间倒序');
    expect(entries.first.sizeBytes, 1024);
    expect(entries.first.exportedAt,
        DateTime.utc(2026, 8, 29, 8, 0, 0));
  });

  test('兼容小写命名空间前缀与 URL 编码文件名', () {
    const xml = '''
<?xml version="1.0"?>
<d:multistatus xmlns:d="DAV:">
 <d:response>
  <d:href>/dav/WarmPantry/%E5%A4%87%E4%BB%BD.zip</d:href>
  <d:propstat>
   <d:prop><d:resourcetype/><d:getcontentlength>7</d:getcontentlength></d:prop>
  </d:propstat>
 </d:response>
</d:multistatus>
''';
    final entries = parsePropfindEntries(xml);
    expect(entries.length, 1);
    expect(entries.first.name, '备份.zip', reason: 'href 需 URL 解码');
    expect(entries.first.sizeBytes, 7);
  });

  test('坏 XML 不抛异常，返回空列表', () {
    expect(parsePropfindEntries('not-a-xml<<<'), isEmpty);
  });

  test('云端文件名：英文前缀 + 本地时间戳', () {
    expect(CloudSyncService.cloudFileName(DateTime(2026, 8, 9, 8, 3, 1)),
        'warmpantry-20260809-080301.zip');
  });

  group('协议白名单（usesCleartextTraffic 拦不住 dart:io，须自校验）', () {
    final client = WebDavClient();

    test('http 地址被拒绝且不发起网络请求', () async {
      final r = await client.testConnection(const WebDavCredentials(
        url: 'http://dav.jianguoyun.com/dav/',
        user: 'u',
        token: 't',
      ));
      expect(r.ok, isFalse);
      expect(r.message, contains('https'));
    });

    test('空地址提示未配置', () async {
      final r = await client.testConnection(const WebDavCredentials(
        url: '   ',
        user: 'u',
        token: 't',
      ));
      expect(r.ok, isFalse);
      expect(r.message, contains('未配置'));
    });
  });
}
