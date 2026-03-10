import 'dart:async';
import 'dart:io';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models/sftp_entry.dart';
import 'vps_connection_provider.dart';

class FileManagerState {
  const FileManagerState({
    this.currentPath = '/',
    this.entries = const [],
    this.isLoading = false,
    this.errorMessage,
    this.transferProgress,
    this.transferName,
  });
  final String currentPath;
  final List<SftpEntry> entries;
  final bool isLoading;
  final String? errorMessage;
  final double? transferProgress;
  final String? transferName;

  FileManagerState copyWith({
    String? currentPath,
    List<SftpEntry>? entries,
    bool? isLoading,
    String? errorMessage,
    double? transferProgress,
    String? transferName,
  }) => FileManagerState(
    currentPath: currentPath ?? this.currentPath,
    entries: entries ?? this.entries,
    isLoading: isLoading ?? this.isLoading,
    errorMessage: errorMessage,
    transferProgress: transferProgress,
    transferName: transferName ?? this.transferName,
  );
}

class FileManagerNotifier extends FamilyAsyncNotifier<FileManagerState, String> {
  SftpClient? _sftp;

  String get vpsId => arg;

  @override
  Future<FileManagerState> build(String arg) async {
    ref.onDispose(_cleanup);
    await _openSftp();
    final home = await _resolvePath('~');
    return _listDir(home);
  }

  Future<void> _openSftp() async {
    final client = ref.read(vpsConnectionProvider(vpsId)).valueOrNull?.client;
    if (client == null) throw StateError('Not connected');
    _sftp = await client.sftp();
  }

  Future<String> _resolvePath(String path) async {
    try {
      return await _sftp!.absolute(path);
    } catch (_) {
      return '/';
    }
  }

  Future<FileManagerState> _listDir(String path) async {
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
    return FileManagerState(currentPath: path, entries: entries);
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

  Future<void> delete(String name) async {
    final current = state.valueOrNull;
    if (current == null || _sftp == null) return;
    final path = '${current.currentPath}/$name';
    try {
      await _sftp!.remove(path);
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

  void _cleanup() {
    _sftp?.close();
    _sftp = null;
  }
}

final fileManagerProvider = AsyncNotifierProvider.family<
    FileManagerNotifier, FileManagerState, String>(
  FileManagerNotifier.new,
);
