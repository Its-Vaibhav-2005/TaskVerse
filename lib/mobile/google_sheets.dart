import 'dart:async';
import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'backup.dart';

const googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
const driveScope = 'https://www.googleapis.com/auth/drive.file';

class MobileGoogleSheets {
  final GoogleSignIn signIn = GoogleSignIn.instance;
  final String webClientId;
  GoogleSignInAccount? account;
  bool get connected => account != null;
  String? get accountId => account?.id;
  String? get email => account?.email;
  Future<void>? _initializing;
  final http.Client client;
  MobileGoogleSheets({
    http.Client? client,
    this.webClientId = googleWebClientId,
  }) : client = client ?? http.Client();
  bool get configured => webClientId.isNotEmpty;
  Future<void> initialize() =>
      _initializing ??= signIn.initialize(serverClientId: webClientId);
  Future<void> connect() async {
    if (!configured) {
      throw StateError(
        'Google sign-in needs the Android OAuth registration. See docs/android.md.',
      );
    }
    await initialize();
    final selected = await signIn.authenticate();
    await selected.authorizationClient.authorizeScopes([driveScope]);
    account = selected;
  }

  Future<void> restore() async {
    if (!configured) return;
    await initialize();
    final restored = await signIn.attemptLightweightAuthentication();
    if (restored != null &&
        await restored.authorizationClient.authorizationForScopes([
              driveScope,
            ]) !=
            null) {
      account = restored;
    }
  }

  Future<void> disconnect() async {
    await signIn.signOut();
    account = null;
  }

  Future<Map<String, dynamic>> request(
    String host,
    String path, {
    String method = 'GET',
    Map<String, String>? query,
    Object? body,
  }) async {
    final user = account;
    if (user == null) throw StateError('Connect Google to sync.');
    final auth = await user.authorizationClient.authorizationForScopes([
      driveScope,
    ]);
    if (auth == null) {
      throw StateError(
        'Tap Connect Google to grant access to your tracker sheets.',
      );
    }
    final req = http.Request(method, Uri.https(host, path, query));
    req.headers.addAll({
      'Authorization': 'Bearer ${auth.accessToken}',
      'Content-Type': 'application/json',
    });
    if (body != null) req.body = jsonEncode(body);
    http.Response response;
    try {
      response = await http.Response.fromStream(
        await client.send(req),
      ).timeout(const Duration(seconds: 25));
    } on Exception {
      throw StateError(
        'Google is unreachable. Changes are saved on this device; sync will retry.',
      );
    }
    if (response.statusCode == 401) {
      await user.authorizationClient.clearAuthorizationToken(
        accessToken: auth.accessToken,
      );
      throw StateError(
        'Google access expired. Tap Sync again, or reconnect Google.',
      );
    }
    if (response.statusCode == 403) {
      throw StateError(
        'Google denied access. Check your account and enable Drive and Sheets APIs.',
      );
    }
    if (response.statusCode == 404) {
      throw StateError('The sheet is unavailable. Your local tracker is safe.');
    }
    if (response.statusCode >= 400) {
      throw StateError(
        'Google sync failed (${response.statusCode}). Your local tracker is safe.',
      );
    }
    return response.body.isEmpty
        ? {}
        : Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<List<Map<String, dynamic>>> discover() async {
    final files = <Map<String, dynamic>>[];
    String? page;
    do {
      final response = await request(
        'www.googleapis.com',
        '/drive/v3/files',
        query: {
          'q':
              "trashed = false and mimeType = 'application/vnd.google-apps.spreadsheet' and appProperties has { key='trackverse' and value='1' }",
          'fields': 'nextPageToken,files(id,name,appProperties)',
          'pageSize': '100',
          'pageToken': ?page,
        },
      );
      files.addAll(
        (response['files'] as List).map(
          (f) => Map<String, dynamic>.from(f as Map),
        ),
      );
      page = response['nextPageToken'] as String?;
    } while (page != null);
    return files;
  }

  Future<String> create(String alias) async {
    final response = await request(
      'sheets.googleapis.com',
      '/v4/spreadsheets',
      method: 'POST',
      body: {
        'properties': {'title': 'TrackVerse · $alias'},
        'sheets': [
          {
            'properties': {'title': 'Habits', 'sheetId': 0},
          },
          {
            'properties': {'title': historyTab, 'sheetId': 1},
          },
        ],
      },
    );
    final id = response['spreadsheetId'] as String;
    await request(
      'www.googleapis.com',
      '/drive/v3/files/$id',
      method: 'PATCH',
      query: {'fields': 'id'},
      body: {
        'appProperties': {'trackverse': '1', 'alias': alias},
      },
    );
    await request(
      'sheets.googleapis.com',
      '/v4/spreadsheets/$id/values:batchUpdate',
      method: 'POST',
      body: {
        'valueInputOption': 'RAW',
        'data': [
          {
            'range': "'$historyTab'!A1:G2",
            'values': [
              [
                journalMagic,
                'Versioned TrackVerse backups. Do not edit these rows.',
              ],
              journalColumns,
            ],
          },
          {
            'range': "'Habits'!A1:B2",
            'values': [
              ['TrackVerse', alias],
              ['Backups', 'Manage habits inside TrackVerse.'],
            ],
          },
        ],
      },
    );
    return id;
  }

  Future<void> inspect(String id) async {
    final info = await request(
      'www.googleapis.com',
      '/drive/v3/files/$id',
      query: {'fields': 'capabilities(canEdit),appProperties'},
    );
    if (info['capabilities']?['canEdit'] != true ||
        info['appProperties']?['trackverse'] != '1') {
      throw StateError('Choose an editable sheet created by TrackVerse.');
    }
  }

  Future<List<List<dynamic>>> read(String id) async {
    final data = await request(
      'sheets.googleapis.com',
      '/v4/spreadsheets/$id/values/\'$historyTab\'!A:G',
    );
    return (data['values'] as List? ?? [])
        .map((r) => List<dynamic>.from(r as List))
        .toList();
  }

  Future<void> append(String id, List<dynamic> rows) => request(
    'sheets.googleapis.com',
    '/v4/spreadsheets/$id/values/\'$historyTab\'!A:G:append',
    method: 'POST',
    query: {'valueInputOption': 'RAW', 'insertDataOption': 'INSERT_ROWS'},
    body: {'majorDimension': 'ROWS', 'values': rows},
  ).then((_) {});
  void close() => client.close();
}
