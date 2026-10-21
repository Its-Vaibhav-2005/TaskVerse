bool get isWindowsDesktop => false;
Future<String> desktopRequest(String operation, [String payload = '']) =>
    throw UnsupportedError(
      'Desktop bridge is not used by Flutter native builds',
    );
