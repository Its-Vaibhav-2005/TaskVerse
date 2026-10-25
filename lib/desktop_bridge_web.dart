import 'dart:js_interop';

@JS('trackverseDesktop')
external JSObject? get _bridge;
@JS('trackverseDesktop.request')
external JSPromise<JSString> _request(JSString operation, JSString payload);
@JS('window.open')
external JSAny? _open(JSString url, JSString target, JSString features);
bool get isWindowsDesktop => _bridge != null;
Future<String> desktopRequest(String operation, [String payload = '']) async =>
    (await _request(operation.toJS, payload.toJS).toDart).toDart;

Future<void> openAppLink(String operation) async {
  final url = switch (operation) {
    'openPrivacyPolicy' =>
      'https://its-vaibhav-2005.github.io/TaskVerse/privacy.html',
    'contactSupport' => 'mailto:vaibhavpandey.cs31@gmail.com',
    _ => throw ArgumentError('Unknown app link'),
  };
  if (isWindowsDesktop) {
    await desktopRequest(operation);
  } else {
    _open(url.toJS, '_blank'.toJS, 'noopener,noreferrer'.toJS);
  }
}
