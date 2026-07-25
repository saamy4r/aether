import 'dart:async';
import 'dart:io';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models/sftp_entry.dart';
import '../core/utils/shell_escape.dart';
import 'vps_connection_provider.dart';

enum ViewMode { list, grid }

typedef Clipboard = ({
  List<String> names,
  String sourcePath,
  bool isCut,
});

class FileManagerState {
  const FileManagerState({
    this.currentPath = '/',
    this.entries = const [],
    this.isLoading = false,
    this.errorMessage,
    this.transferProgress,
    this.transferName,
    this.viewMode = ViewMode.list,
    this.clipboard,
  });
  final String currentPath;
  final List<SftpEntry> entries;
  final bool isLoading;
  final String? errorMessage;
  final double? transferProgress;
  final String? transferName;
  final ViewMode viewMode;
  final Clipboard? clipboard;

  bool get hasClipboard => clipboard != null && clipboard!.names.isNotEmpty;

  FileManagerState copyWith({
    String? currentPath,
    List<SftpEntry>? entries,
    bool? isLoading,
    String? errorMessage,
    double? transferProgress,
    String? transferName,
    ViewMode? viewMode,
    Object? clipboard = _keep,
  }) => FileManagerState(
    currentPath: currentPath ?? this.currentPath,
    entries: entries ?? this.entries,
    isLoading: isLoading ?? this.isLoading,
    errorMessage: errorMessage,
    transferProgress: transferProgress,
    transferName: transferName ?? this.transferName,
    viewMode: viewMode ?? this.viewMode,
    clipboard: identical(clipboard, _keep) ? this.clipboard : clipboard as Clipboard?,
  );

  static const Object _keep = Object();
}

class FileManagerNotifier extends FamilyAsyncNotifier<FileManagerState, String> {
  SftpClient? _sftp;
  SSHClient? _sshClient;

  String get vpsId => arg;

  @override
  Future<FileManagerState> build(String arg) async {
    ref.onDispose(_cleanup);
    await _openSftp();
    final home = await _resolveHome();
    return _listDir(home);
  }

  Future<void> _openSftp() async {
    final client = ref.read(vpsConnectionProvider(vpsId)).valueOrNull?.client;
    if (client == null) throw StateError('Not connected');
    _sshClient = client;
    _sftp = await client.sftp();
  }

  Future<String> _resolveHome() async {
    try {
      final home = (await _execSsh('echo \$HOME')).trim();
      if (home.isNotEmpty && home.startsWith('/')) return home;
    } catch (_) {}
    try {
      final pwd = (await _execSsh('pwd')).trim();
      if (pwd.isNotEmpty && pwd.startsWith('/')) return pwd;
    } catch (_) {}
    return '/';
  }

  // Long timeout: file operations (cp -r, zip) can legitimately take a while.
  Future<String> _execSsh(String cmd) => ref
      .read(vpsConnectionProvider(vpsId).notifier)
      .exec(cmd, timeout: const Duration(minutes: 5));

  Future<FileManagerState> _listDir(String path) async {
    final current = state.valueOrNull;
    final items = await _sftp!.listdir(path);
    final entries = items
        .where((i) => i.filename != '.')
        .map((i) => SftpEntry(
              name: i.filename,
              isDirectory: i.attr.isDirectory,
              size: i.attr.size ?? 0,
              permissions: i.attr.mode?.value ?? 0,
              modifyTime: i.attr.modifyTime != null
                  ? DateTime.fromMillisecondsSinceEpoch(
                      i.attr.modifyTime! * 1000)
                  : DateTime.now(),
            ))
        .toList()
      ..sort((a, b) {
        if (a.isDirectory && !b.isDirectory) return -1;
        if (!a.isDirectory && b.isDirectory) return 1;
        return a.name.compareTo(b.name);
      });
    return FileManagerState(
      currentPath: path,
      entries: entries,
      viewMode: current?.viewMode ?? ViewMode.list,
      clipboard: current?.clipboard,
    );
  }

  Future<void> navigate(String path) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _listDir(path));
  }

  Future<void> navigateUp() async {
    final current = state.valueOrNull?.currentPath ?? '/';
    if (current == '/') return;
    final parent = current.substring(0, current.lastIndexOf('/'));
    await navigate(parent.isEmpty ? '/' : parent);
  }

  Future<void> refresh() async {
    final path = state.valueOrNull?.currentPath ?? '/';
    await navigate(path);
  }

  void toggleViewMode() {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data(current.copyWith(
      viewMode: current.viewMode == ViewMode.list ? ViewMode.grid : ViewMode.list,
    ));
  }

  // ── Clipboard ──────────────────────────────────────────────────────────────

  void setClipboard(List<String> names, {required bool isCut}) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data(current.copyWith(
      clipboard: (names: names, sourcePath: current.currentPath, isCut: isCut),
    ));
  }

  Future<void> paste() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasClipboard) return;
    final cb = current.clipboard!;
    final dest = current.currentPath;
    try {
      for (final name in cb.names) {
        final src = '${cb.sourcePath}/$name';
        final dst = '$dest/$name';
        if (cb.isCut) {
          await _execSsh('mv ${shQuote(src)} ${shQuote(dst)}');
        } else {
          await _execSsh('cp -r ${shQuote(src)} ${shQuote(dst)}');
        }
      }
      // After cut+paste clear clipboard; after copy keep it for multi-paste
      state = AsyncValue.data(current.copyWith(
        clipboard: cb.isCut ? null : cb,
      ));
      await refresh();
    } catch (e) {
      state = AsyncValue.data(current.copyWith(
        errorMessage: 'Paste failed: $e',
      ));
    }
  }

  // ── File operations ────────────────────────────────────────────────────────

  Future<void> createDirectory(String name) async {
    final current = state.valueOrNull;
    if (current == null || _sftp == null) return;
    try {
      await _sftp!.mkdir('${current.currentPath}/$name');
      await refresh();
    } catch (e) {
      state = AsyncValue.data(current.copyWith(
        errorMessage: 'Create folder failed: $e',
      ));
    }
  }

  Future<void> createFile(String name) async {
    final current = state.valueOrNull;
    if (current == null || _sftp == null) return;
    try {
      final f = await _sftp!.open(
        '${current.currentPath}/$name',
        mode: SftpFileOpenMode.create | SftpFileOpenMode.write,
      );
      await f.close();
      await refresh();
    } catch (e) {
      state = AsyncValue.data(current.copyWith(
        errorMessage: 'Create file failed: $e',
      ));
    }
  }

  Future<void> upload(String localPath) async {
    final current = state.valueOrNull;
    if (current == null || _sftp == null) return;
    final name = localPath.split(Platform.pathSeparator).last;
    final remotePath = '${current.currentPath}/$name';

    state = AsyncValue.data(current.copyWith(
      isLoading: true,
      transferName: name,
      transferProgress: 0,
    ));

    try {
      final localFile = File(localPath);
      final totalBytes = await localFile.length();
      final bytes = await localFile.readAsBytes();

      final remoteFile = await _sftp!.open(
        remotePath,
        mode: SftpFileOpenMode.write |
            SftpFileOpenMode.create |
            SftpFileOpenMode.truncate,
      );

      int written = 0;
      const chunkSize = 65536;
      for (int i = 0; i < bytes.length; i += chunkSize) {
        final end = (i + chunkSize).clamp(0, bytes.length);
        await remoteFile.writeBytes(bytes.sublist(i, end), offset: i);
        written += end - i;
        state = AsyncValue.data(current.copyWith(
          isLoading: true,
          transferName: name,
          transferProgress: totalBytes > 0 ? written / totalBytes : 1,
        ));
      }
      await remoteFile.close();
      await refresh();
    } catch (e) {
      state = AsyncValue.data(current.copyWith(
        errorMessage: 'Upload failed: $e',
      ));
    }
  }

  Future<void> download(String remoteName, String localDir) async {
    final current = state.valueOrNull;
    if (current == null || _sftp == null) return;
    final remotePath = '${current.currentPath}/$remoteName';
    final localPath = '$localDir/$remoteName';

    state = AsyncValue.data(current.copyWith(
      isLoading: true,
      transferName: remoteName,
      transferProgress: 0,
    ));

    try {
      final remoteFile = await _sftp!.open(remotePath, mode: SftpFileOpenMode.read);
      final data = await remoteFile.readBytes();
      await remoteFile.close();
      await File(localPath).writeAsBytes(data);
      state = AsyncValue.data(current.copyWith(errorMessage: null));
    } catch (e) {
      state = AsyncValue.data(current.copyWith(
        errorMessage: 'Download failed: $e',
      ));
    }
  }

  Future<void> deleteEntry(SftpEntry entry) async {
    final current = state.valueOrNull;
    if (current == null || _sftp == null) return;
    final path = '${current.currentPath}/${entry.name}';
    try {
      if (entry.isDirectory) {
        await _execSsh('rm -rf ${shQuote(path)}');
      } else {
        await _sftp!.remove(path);
      }
      await refresh();
    } catch (e) {
      state = AsyncValue.data(current.copyWith(
        errorMessage: 'Delete failed: $e',
      ));
    }
  }

  Future<void> deleteEntries(List<String> names) async {
    final current = state.valueOrNull;
    if (current == null) return;
    try {
      final entryMap = {for (final e in current.entries) e.name: e};
      for (final name in names) {
        final path = '${current.currentPath}/$name';
        final entry = entryMap[name];
        if (entry?.isDirectory == true) {
          await _execSsh('rm -rf ${shQuote(path)}');
        } else {
          await _sftp!.remove(path);
        }
      }
      await refresh();
    } catch (e) {
      state = AsyncValue.data(current.copyWith(
        errorMessage: 'Delete failed: $e',
      ));
    }
  }

  Future<void> rename(String oldName, String newName) async {
    final current = state.valueOrNull;
    if (current == null || _sftp == null) return;
    final oldPath = '${current.currentPath}/$oldName';
    final newPath = '${current.currentPath}/$newName';
    try {
      await _sftp!.rename(oldPath, newPath);
      await refresh();
    } catch (e) {
      state = AsyncValue.data(current.copyWith(
        errorMessage: 'Rename failed: $e',
      ));
    }
  }

  Future<void> extractZip(String name) async {
    final current = state.valueOrNull;
    if (current == null || _sshClient == null) return;
    try {
      await _execSsh(
          'cd ${shQuote(current.currentPath)} && unzip -o ${shQuote(name)} -d .');
      await refresh();
    } catch (e) {
      state = AsyncValue.data(current.copyWith(
        errorMessage: 'Extract failed: $e',
      ));
    }
  }

  Future<void> compressToZip(List<String> names, String archiveName) async {
    final current = state.valueOrNull;
    if (current == null || _sshClient == null) return;
    final dir = current.currentPath;
    final files = names.map(shQuote).join(' ');
    try {
      // Try zip first; fall back to python3 zipfile if zip isn't installed
      try {
        await _execSsh(
            'cd ${shQuote(dir)} && zip -r ${shQuote(archiveName)} $files');
      } catch (_) {
        // zip not available — use python3, passing names via argv so they are
        // never embedded in the python source
        await _execSsh(
          'cd ${shQuote(dir)} && python3 -c '
          "'import sys, zipfile; "
          'z = zipfile.ZipFile(sys.argv[1], "w", zipfile.ZIP_DEFLATED); '
          '[z.write(f) for f in sys.argv[2:]]; '
          "z.close()' ${shQuote(archiveName)} $files",
        );
      }
      await refresh();
    } catch (e) {
      state = AsyncValue.data(current.copyWith(
        errorMessage: 'Compress failed: $e',
      ));
    }
  }

  void _cleanup() {
    _sftp?.close();
    _sftp = null;
    _sshClient = null;
  }
}

final fileManagerProvider = AsyncNotifierProvider.family<
    FileManagerNotifier, FileManagerState, String>(
  FileManagerNotifier.new,
);
