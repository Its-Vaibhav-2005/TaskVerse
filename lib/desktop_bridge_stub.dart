bool get isWindowsDesktop => false;
Future<void> openAppLink(String operation) => Future.error(
  UnsupportedError('App links require the desktop or browser app'),
);
Future<String> desktopRequest(String operation, [String payload = '']) =>
    throw UnsupportedError(
      'Desktop bridge is not used by Flutter native builds',
    );
