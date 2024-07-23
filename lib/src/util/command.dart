import 'dart:io';

Future<String> runCommandAndThrowIfFailed(String command, List<String> args,
    {String? workingDirectory, bool returnErr = false}) async {
  final result = await Process.run(command, args, workingDirectory: workingDirectory);

  if (result.exitCode != 0) {
    throw ProcessException(command, args, result.stderr as String, result.exitCode);
  }

  return ((returnErr ? result.stderr : result.stdout) as String).trim();
}

Future<void> runCommandAndThrowIfFailedInheritIo(String command, List<String> args,
    {String? workingDirectory}) async {
  final process = await Process.start(command, args,
      workingDirectory: workingDirectory, mode: ProcessStartMode.inheritStdio);

  final exitCode = await process.exitCode;

  if (exitCode != 0) {
    throw ProcessException(command, args, '', exitCode);
  }
}
