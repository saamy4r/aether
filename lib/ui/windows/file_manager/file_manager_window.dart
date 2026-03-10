import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colors.dart';
import '../../../core/models/sftp_entry.dart';
import '../../../providers/file_manager_provider.dart';

class FileManagerWindowContent extends ConsumerWidget {
  const FileManagerWindowContent({super.key, required this.vpsId});
  final String vpsId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(fileManagerProvider(vpsId));
    final notifier = ref.read(fileManagerProvider(vpsId).notifier);

    return async.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AetherColors.accent),
      ),
      error: (e, _) => Center(
        child: Text('$e', style: const TextStyle(color: AetherColors.accentRed)),
      ),
      data: (state) => Column(
        children: [
          _BreadcrumbBar(path: state.currentPath, notifier: notifier),
          if (state.errorMessage != null)
            Container(
              color: AetherColors.accentRed.withOpacity(0.15),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(state.errorMessage!,
                        style: const TextStyle(
                            color: AetherColors.accentRed, fontSize: 11)),
                  ),
                  GestureDetector(
                    onTap: () => ref.invalidate(fileManagerProvider(vpsId)),
                    child: const Icon(Icons.close, size: 14,
                        color: AetherColors.accentRed),
                  ),
                ],
              ),
            ),
          if (state.transferProgress != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(state.transferName ?? '',
                      style: const TextStyle(
                          color: AetherColors.textSecondary, fontSize: 10)),
                  const SizedBox(height: 2),
                  LinearProgressIndicator(
                    value: state.transferProgress,
                    backgroundColor: AetherColors.glassBase,
                    valueColor: const AlwaysStoppedAnimation(AetherColors.accent),
                    minHeight: 4,
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: state.entries.length,
              itemBuilder: (context, i) =>
                  _EntryTile(entry: state.entries[i], state: state,
                      notifier: notifier, vpsId: vpsId),
            ),
          ),
          _ActionBar(notifier: notifier, path: state.currentPath),
        ],
      ),
    );
  }
}

class _BreadcrumbBar extends StatelessWidget {
  const _BreadcrumbBar({required this.path, required this.notifier});
  final String path;
  final FileManagerNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final parts = path.split('/').where((p) => p.isNotEmpty).toList();
    return Container(
      height: 32,
      color: AetherColors.titleBarBase,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, size: 14),
              onPressed: notifier.navigateUp,
              padding: EdgeInsets.zero,
              color: AetherColors.textSecondary,
            ),
            GestureDetector(
              onTap: () => notifier.navigate('/'),
              child: const Text('/',
                  style: TextStyle(color: AetherColors.accent, fontSize: 12)),
            ),
            ...parts.asMap().entries.map((e) {
              final subPath = '/${parts.sublist(0, e.key + 1).join('/')}';
              return Row(children: [
                const Text(' / ',
                    style: TextStyle(
                        color: AetherColors.textSecondary, fontSize: 12)),
                GestureDetector(
                  onTap: () => notifier.navigate(subPath),
                  child: Text(e.value,
                      style: const TextStyle(
                          color: AetherColors.accent, fontSize: 12)),
                ),
              ]);
            }),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.entry,
    required this.state,
    required this.notifier,
    required this.vpsId,
  });
  final SftpEntry entry;
  final FileManagerState state;
  final FileManagerNotifier notifier;
  final String vpsId;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (entry.isDirectory) {
          notifier.navigate('${state.currentPath}/${entry.name}');
        }
      },
      onLongPress: () => _showContextMenu(context),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            Icon(
              entry.isDirectory ? Icons.folder : Icons.insert_drive_file,
              size: 16,
              color: entry.isDirectory
                  ? AetherColors.accentYellow
                  : AetherColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(entry.name,
                  style: const TextStyle(
                      color: AetherColors.textPrimary, fontSize: 12),
                  overflow: TextOverflow.ellipsis),
            ),
            if (!entry.isDirectory)
              Text(entry.sizeFormatted,
                  style: const TextStyle(
                      color: AetherColors.textSecondary, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AetherColors.surfaceDeep,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!entry.isDirectory)
              ListTile(
                leading: const Icon(Icons.download, color: AetherColors.accent),
                title: const Text('Download',
                    style: TextStyle(color: AetherColors.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  notifier.download(entry.name, '/sdcard/Download');
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete, color: AetherColors.accentRed),
              title: const Text('Delete',
                  style: TextStyle(color: AetherColors.accentRed)),
              onTap: () {
                Navigator.pop(context);
                notifier.delete(entry.name);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.notifier, required this.path});
  final FileManagerNotifier notifier;
  final String path;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      color: AetherColors.titleBarBase,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 14),
            onPressed: notifier.refresh,
            color: AetherColors.textSecondary,
            padding: EdgeInsets.zero,
          ),
          IconButton(
            icon: const Icon(Icons.upload_file, size: 14),
            color: AetherColors.accent,
            padding: EdgeInsets.zero,
            onPressed: () async {
              final result = await FilePicker.platform.pickFiles(
                allowMultiple: false,
              );
              if (result != null && result.files.single.path != null) {
                notifier.upload(result.files.single.path!);
              }
            },
          ),
        ],
      ),
    );
  }
}
