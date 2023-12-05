import 'package:source_span/source_span.dart';

extension SourceFileOffsetUtils on SourceFile {
  /// Return the offset of the first character on the line following the line
  /// containing the given [offset].
  int getOffsetOfLineAfter(int offset) => getOffset(getLine(offset) + 1);
}