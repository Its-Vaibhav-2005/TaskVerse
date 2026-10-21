import 'dart:js_interop';

@JS('trackverseDesktop')
external JSObject? get _bridge;
@JS('trackverseDesktop.request')
external JSPromise<JSString> _request(JSString operation, JSString payload);
bool get isWindowsDesktop => _bridge != null;
Future<String> desktopRequest(String operation, [String payload = '']) async =>
    (await _request(operation.toJS, payload.toJS).toDart).toDart;
