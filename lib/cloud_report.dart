import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'domain.dart';

class CloudReport {
  CloudReport(String url) : _endpoint = _reportEndpoint(url);

  final Uri _endpoint;

  static Uri _reportEndpoint(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        !RegExp(r'^[a-z0-9-]+(?:\.[a-z0-9-]+)?\.run\.app$')
            .hasMatch(uri.host) ||
        uri.hasPort ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw const FormatException('https://로 시작하는 Cloud Run 서비스 주소를 입력해 주세요.');
    }
    return uri.replace(path: '/app-report');
  }

  Future<String> advice(MonthSummary summary) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10)
      ..connectionFactory = _connect;
    try {
      return await _fetch(client, summary).timeout(const Duration(seconds: 50));
    } finally {
      client.close(force: true);
    }
  }

  Future<ConnectionTask<Socket>> _connect(
    Uri uri,
    String? proxyHost,
    int? proxyPort,
  ) async {
    if (proxyHost != null && proxyPort != null) {
      return Socket.startConnect(proxyHost, proxyPort);
    }
    try {
      final addresses = await InternetAddress.lookup(uri.host)
          .timeout(const Duration(seconds: 4));
      if (addresses.isNotEmpty) {
        return await SecureSocket.startConnect(uri.host, uri.port);
      }
    } on SocketException {
      // The emulator can reach the internet even when its DNS is unavailable.
    } on TimeoutException {
      // Resolve the report hostname over HTTPS before making the POST.
    }
    return _tlsAt(uri, await _resolveWithGoogleDns(uri.host));
  }

  Future<InternetAddress> _resolveWithGoogleDns(String hostname) async {
    final dns = HttpClient()
      ..connectionTimeout = const Duration(seconds: 5)
      ..connectionFactory = (uri, _, _) =>
          _tlsAt(uri, InternetAddress('8.8.8.8'));
    try {
      final uri = Uri.https('dns.google', '/resolve', {
        'name': hostname,
        'type': 'A',
      });
      final request = await dns.getUrl(uri).timeout(const Duration(seconds: 6));
      request.followRedirects = false;
      final response = await request.close().timeout(
        const Duration(seconds: 6),
      );
      if (response.statusCode == 200) {
        final result = jsonDecode(
          await utf8.decoder
              .bind(response)
              .join()
              .timeout(const Duration(seconds: 6)),
        );
        if (result case {'Status': 0, 'Answer': final List answers}) {
          for (final answer in answers) {
            if (answer case {'type': 1, 'data': final String data}) {
              final address = InternetAddress.tryParse(data);
              if (address?.type == InternetAddressType.IPv4) return address!;
            }
          }
        }
      }
      throw const SocketException('Cloud Run DNS resolution failed');
    } finally {
      dns.close(force: true);
    }
  }

  Future<ConnectionTask<Socket>> _tlsAt(
    Uri uri,
    InternetAddress address,
  ) async {
    final task = await Socket.startConnect(address, uri.port);
    Socket? connected;
    return ConnectionTask.fromSocket(
      task.socket.then((socket) {
        connected = socket;
        // Keep SNI and certificate verification on the original HTTPS hostname.
        return SecureSocket.secure(socket, host: uri.host);
      }),
      () {
        task.cancel();
        connected?.destroy();
      },
    );
  }

  Future<String> _fetch(HttpClient client, MonthSummary summary) async {
    final body = utf8.encode(
      jsonEncode({
        'month': monthKey(summary.month),
        'category_totals_won': {
          for (final item in summary.categoryTotals) item.name: item.spent,
        },
        'budget_won': summary.budget.total,
        'previous_total_won': summary.previousTotal,
      }),
    );
    final request = await client.postUrl(_endpoint);
    request.followRedirects = false;
    request.headers.contentType = ContentType.json;
    request.contentLength = body.length;
    request.add(body);
    final response = await request.close();
    if (response.statusCode == 429) {
      throw const FormatException('요청이 많아요. 잠시 후 Gemini 조언을 다시 요청해 주세요.');
    }
    if (response.statusCode != 200) {
      throw const FormatException('서버에서 리포트를 받을 수 없어요.');
    }
    final bytes = <int>[];
    await for (final chunk in response) {
      if (bytes.length + chunk.length > 8192) {
        throw const FormatException('서버 응답이 너무 커요.');
      }
      bytes.addAll(chunk);
    }
    final result = jsonDecode(utf8.decode(bytes));
    if (result case {'mode': 'gemini', 'advice': final String text}
        when text.isNotEmpty && text.length <= 500) {
      return text;
    }
    throw const FormatException('Gemini 조언을 받을 수 없어요. 기기에서 리포트를 생성할 수 있어요.');
  }
}
