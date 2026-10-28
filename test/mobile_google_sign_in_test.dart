import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trackverse/mobile/google_sheets.dart';

class FakeGooglePlatform extends GoogleSignInPlatform {
  InitParameters? initialization;
  final requests = <AuthorizationRequestDetails>[];
  bool grant = true, cachedGrant = true;
  int initializations = 0;
  final result = const AuthenticationResults(
    user: GoogleSignInUserData(email: 'tester@example.com', id: 'test-user'),
    authenticationTokens: AuthenticationTokenData(idToken: null),
  );
  @override
  Future<void> init(InitParameters params) async {
    initialization = params;
    initializations++;
  }

  @override
  Future<AuthenticationResults> authenticate(
    AuthenticateParameters params,
  ) async => result;
  @override
  Future<AuthenticationResults?> attemptLightweightAuthentication(
    AttemptLightweightAuthenticationParameters params,
  ) async => result;
  @override
  bool supportsAuthenticate() => true;
  @override
  bool authorizationRequiresUserInteraction() => true;
  @override
  Future<ClientAuthorizationTokenData?> clientAuthorizationTokensForScopes(
    ClientAuthorizationTokensForScopesParameters params,
  ) async {
    requests.add(params.request);
    if (params.request.promptIfUnauthorized && !grant) {
      throw const GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
      );
    }
    return cachedGrant || params.request.promptIfUnauthorized
        ? const ClientAuthorizationTokenData(accessToken: 'test-only-token')
        : null;
  }

  @override
  Future<ServerAuthorizationTokenData?> serverAuthorizationTokensForScopes(
    ServerAuthorizationTokensForScopesParameters params,
  ) async => null;
  @override
  Future<void> signOut(SignOutParams params) async {}
  @override
  Future<void> disconnect(DisconnectParams params) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeGooglePlatform platform;
  setUp(() {
    platform = FakeGooglePlatform();
    GoogleSignInPlatform.instance = platform;
  });
  test(
    'passes the Web client ID, grants per-file access, and calls Sheets with the authorized identity',
    () async {
      final google = MobileGoogleSheets(
        webClientId: '123-test.apps.googleusercontent.com',
        client: MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer test-only-token');
          expect(request.url.host, 'sheets.googleapis.com');
          expect(Uri.decodeComponent(request.url.path), contains('_TrackVerse History'));
          return http.Response('{"values":[]}', 200);
        }),
      );
      addTearDown(google.close);
      await google.connect();
      await google.initialize();
      expect(
        platform.initialization!.serverClientId,
        '123-test.apps.googleusercontent.com',
      );
      expect(platform.initializations, 1);
      expect(platform.requests.single.scopes, [driveScope]);
      expect(google.email, 'tester@example.com');
      expect(await google.read('test-sheet'), isEmpty);
    },
  );
  test(
    'canceled authorization does not leave an apparently connected account',
    () async {
      platform.grant = false;
      final google = MobileGoogleSheets(
        webClientId: '123-test.apps.googleusercontent.com',
      );
      addTearDown(google.close);
      await expectLater(
        google.connect(),
        throwsA(isA<GoogleSignInException>()),
      );
      expect(google.connected, isFalse);
    },
  );
  test(
    'restoring an identity without Drive permission keeps Connect Google available',
    () async {
      platform.cachedGrant = false;
      final google = MobileGoogleSheets(
        webClientId: '123-test.apps.googleusercontent.com',
      );
      addTearDown(google.close);
      await google.restore();
      expect(google.connected, isFalse);
      expect(platform.requests.single.promptIfUnauthorized, isFalse);
      await google.connect();
      expect(google.connected, isTrue);
    },
  );
  test(
    'a missing build configuration cannot initialize an incorrect OAuth client',
    () async {
      final google = MobileGoogleSheets(webClientId: '');
      addTearDown(google.close);
      await expectLater(google.connect(), throwsStateError);
      expect(platform.initializations, 0);
    },
  );
}
