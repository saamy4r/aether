import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/constants/colors.dart';
import '../../../core/models/sftp_entry.dart';
import '../../../providers/file_manager_provider.dart';

class FileManagerWindowContent extends ConsumerStatefulWidget {
  const FileManagerWindowContent({super.key, required this.vpsId});
  final String vpsId;

  @override
  ConsumerState<FileManagerWindowContent> createState() =>
      _FileManagerWindowContentState();
}

class _FileManagerWindowContentState
    extends ConsumerState<FileManagerWindowContent> {
  bool _searchActive = false;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(fileManagerProvider(widget.vpsId));
    final notifier = ref.read(fileManagerProvider(widget.vpsId).notifier);

    return async.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AetherColors.accent),
      ),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AetherColors.accentRed, size: 32),
            const SizedBox(height: 8),
            Text('$e',
                style: const TextStyle(
                    color: AetherColors.accentRed, fontSize: 12),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => ref.invalidate(fileManagerProvider(widget.vpsId)),
              child: const Text('Retry',
                  style: TextStyle(color: AetherColors.accent)),
            ),
          ],
        ),
      ),
      data: (state) {
        final entries = _searchQuery.isEmpty
            ? state.entries
            : state.entries
                .where((e) => e.name
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase()))
                .toList();

        return Column(
          children: [
            _BreadcrumbBar(
              path: state.currentPath,
              notifier: notifier,
              viewMode: state.viewMode,
              searchActive: _searchActive,
              onSearchToggle: () => setState(() {
                _searchActive = !_searchActive;
                if (!_searchActive) {
                  _searchQuery = '';
                  _searchController.clear();
                }
              }),
            ),
            if (_searchActive)
              Container(
                color: AetherColors.titleBarBase,
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: const TextStyle(
                      color: AetherColors.textPrimary, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Search files…',
                    hintStyle: const TextStyle(
                        color: AetherColors.textSecondary, fontSize: 12),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 6),
                    filled: true,
                    fillColor: AetherColors.glassBase,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? GestureDetector(
                            onTap: () => setState(() {
                              _searchQuery = '';
                              _searchController.clear();
                            }),
                            child: const Icon(Icons.close,
                                size: 14,
                                color: AetherColors.textSecondary),
                          )
                        : null,
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
            if (state.errorMessage != null)
              Container(
                color: AetherColors.accentRed.withOpacity(0.15),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(state.errorMessage!,
                          style: const TextStyle(
                              color: AetherColors.accentRed, fontSize: 11)),
                    ),
                    GestureDetector(
                      onTap: () =>
                          ref.invalidate(fileManagerProvider(widget.vpsId)),
                      child: const Icon(Icons.close,
                          size: 14, color: AetherColors.accentRed),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _FileListArea(
                entries: entries,
                state: state,
                notifier: notifier,
                vpsId: widget.vpsId,
              ),
            ),
            if (state.transferProgress != null)
              _TransferTray(
                name: state.transferName ?? '',
                progress: state.transferProgress!,
              ),
          ],
        );
      },
    );
  }
}

// ─── Breadcrumb Bar ──────────────────────────────────────────────────────────

class _BreadcrumbBar extends StatelessWidget {
  const _BreadcrumbBar({
    required this.path,
    required this.notifier,
    required this.viewMode,
    required this.searchActive,
    required this.onSearchToggle,
  });
  final String path;
  final FileManagerNotifier notifier;
  final ViewMode viewMode;
  final bool searchActive;
  final VoidCallback onSearchToggle;

  @override
  Widget build(BuildContext context) {
    final parts = path.split('/').where((p) => p.isNotEmpty).toList();
    return Container(
      height: 32,
      color: AetherColors.titleBarBase,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 14),
            onPressed: notifier.navigateUp,
            padding: EdgeInsets.zero,
            color: AetherColors.textSecondary,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => notifier.navigate('/'),
                    child: const Text('/',
                        style: TextStyle(
                            color: AetherColors.accent, fontSize: 12)),
                  ),
                  ...parts.asMap().entries.map((e) {
                    final subPath =
                        '/${parts.sublist(0, e.key + 1).join('/')}';
                    return Row(children: [
                      const Text(' / ',
                          style: TextStyle(
                              color: AetherColors.textSecondary,
                              fontSize: 12)),
                      GestureDetector(
                        onTap: () => notifier.navigate(subPath),
                        child: Text(e.value,
                            style: const TextStyle(
                                color: AetherColors.accent, fontSize: 12)),
                      ),
                    ]);
                  }),
                ],
              ),
            ),
          ),
          IconButton(
            icon: Icon(searchActive ? Icons.search_off : Icons.search,
                size: 14),
            onPressed: onSearchToggle,
            padding: EdgeInsets.zero,
            color: searchActive
                ? AetherColors.accent
                : AetherColors.textSecondary,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
          IconButton(
            icon: Icon(
              viewMode == ViewMode.list ? Icons.grid_view : Icons.view_list,
              size: 14,
            ),
            onPressed: notifier.toggleViewMode,
            padding: EdgeInsets.zero,
            color: AetherColors.textSecondary,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }
}

// ─── File List Area (with empty-space context menu) ──────────────────────────

class _FileListArea extends StatelessWidget {
  const _FileListArea({
    required this.entries,
    required this.state,
    required this.notifier,
    required this.vpsId,
  });
  final List<SftpEntry> entries;
  final FileManagerState state;
  final FileManagerNotifier notifier;
  final String vpsId;

  void _showEmptySpaceMenu(BuildContext context, Offset globalPos) async {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final rect = RelativeRect.fromRect(
      globalPos & const Size(1, 1),
      Offset.zero & overlay.size,
    );
    final action = await showMenu<String>(
      context: context,
      position: rect,
      color: AetherColors.surfaceDeep,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AetherColors.glassBorder)),
      items: const [
        PopupMenuItem(value: 'upload',
            child: _MenuRow(Icons.upload_file, 'Upload File', AetherColors.accent)),
        PopupMenuItem(value: 'new_folder',
            child: _MenuRow(Icons.create_new_folder_outlined, 'New Folder', AetherColors.accentTeal)),
        PopupMenuItem(value: 'new_file',
            child: _MenuRow(Icons.note_add_outlined, 'New File', AetherColors.textSecondary)),
        PopupMenuItem(value: 'refresh',
            child: _MenuRow(Icons.refresh, 'Refresh', AetherColors.textSecondary)),
      ],
    );
    if (!context.mounted) return;
    switch (action) {
      case 'upload':
        final result = await FilePicker.platform.pickFiles(allowMultiple: false);
        if (result != null && result.files.single.path != null) {
          notifier.upload(result.files.single.path!);
        }
      case 'new_folder':
        _showNameDialog(context, 'New Folder', (name) => notifier.createDirectory(name));
      case 'new_file':
        _showNameDialog(context, 'New File', (name) => notifier.createFile(name));
      case 'refresh':
        notifier.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTapUp: (d) => _showEmptySpaceMenu(context, d.globalPosition),
      onLongPressStart: (d) => _showEmptySpaceMenu(context, d.globalPosition),
      child: state.viewMode == ViewMode.grid
          ? _buildGrid(context)
          : _buildList(context),
    );
  }

  Widget _buildList(BuildContext context) {
    return RefreshIndicator(
      color: AetherColors.accent,
      backgroundColor: AetherColors.surfaceDeep,
      onRefresh: () => notifier.refresh(),
      child: entries.isEmpty
          ? const _EmptyFolder()
          : ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: entries.length,
              itemBuilder: (context, i) => _EntryTile(
                entry: entries[i],
                state: state,
                notifier: notifier,
              ),
            ),
    );
  }

  Widget _buildGrid(BuildContext context) {
    return RefreshIndicator(
      color: AetherColors.accent,
      backgroundColor: AetherColors.surfaceDeep,
      onRefresh: () => notifier.refresh(),
      child: entries.isEmpty
          ? const _EmptyFolder()
          : GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 0.85,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: entries.length,
              itemBuilder: (context, i) => _EntryGridCell(
                entry: entries[i],
                state: state,
                notifier: notifier,
              ),
            ),
    );
  }
}

// ─── Entry Tile (list view) ───────────────────────────────────────────────────

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.entry,
    required this.state,
    required this.notifier,
  });
  final SftpEntry entry;
  final FileManagerState state;
  final FileManagerNotifier notifier;

  void _showContextMenu(BuildContext context, Offset globalPos) async {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final rect = RelativeRect.fromRect(
      globalPos & const Size(1, 1),
      Offset.zero & overlay.size,
    );

    final isArchive = _isArchive(entry.name);

    final action = await showMenu<String>(
      context: context,
      position: rect,
      color: AetherColors.surfaceDeep,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AetherColors.glassBorder)),
      items: [
        const PopupMenuItem(value: 'rename',
            child: _MenuRow(Icons.drive_file_rename_outline, 'Rename', AetherColors.textPrimary)),
        if (!entry.isDirectory)
          const PopupMenuItem(value: 'download',
              child: _MenuRow(Icons.download, 'Download', AetherColors.accent)),
        if (isArchive)
          const PopupMenuItem(value: 'extract',
              child: _MenuRow(Icons.unarchive_outlined, 'Extract Here', AetherColors.accentTeal)),
        if (!entry.isDirectory)
          const PopupMenuItem(value: 'compress',
              child: _MenuRow(Icons.archive_outlined, 'Compress to Zip', AetherColors.textSecondary)),
        const PopupMenuItem(value: 'delete',
            child: _MenuRow(Icons.delete_outline, 'Delete', AetherColors.accentRed)),
      ],
    );

    if (!context.mounted) return;
    switch (action) {
      case 'rename':
        _showRenameDialog(context, entry.name, notifier);
      case 'download':
        final dir = await getDownloadsDirectory();
        notifier.download(entry.name, dir?.path ?? '.');
      case 'extract':
        notifier.extractZip(entry.name);
      case 'compress':
        notifier.compressToZip([entry.name], '${entry.name}.zip');
      case 'delete':
        _showDeleteDialog(context, entry, notifier);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (entry.isDirectory) {
          notifier.navigate('${state.currentPath}/${entry.name}');
        }
      },
      onSecondaryTapUp: (d) => _showContextMenu(context, d.globalPosition),
      onLongPressStart: (d) => _showContextMenu(context, d.globalPosition),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            Icon(
              _iconForEntry(entry),
              size: 16,
              color: _colorForEntry(entry),
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
}

// ─── Entry Grid Cell ──────────────────────────────────────────────────────────

class _EntryGridCell extends StatelessWidget {
  const _EntryGridCell({
    required this.entry,
    required this.state,
    required this.notifier,
  });
  final SftpEntry entry;
  final FileManagerState state;
  final FileManagerNotifier notifier;

  void _showContextMenu(BuildContext context, Offset globalPos) async {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final rect = RelativeRect.fromRect(
      globalPos & const Size(1, 1),
      Offset.zero & overlay.size,
    );
    final isArchive = _isArchive(entry.name);
    final action = await showMenu<String>(
      context: context,
      position: rect,
      color: AetherColors.surfaceDeep,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AetherColors.glassBorder)),
      items: [
        const PopupMenuItem(value: 'rename',
            child: _MenuRow(Icons.drive_file_rename_outline, 'Rename', AetherColors.textPrimary)),
        if (!entry.isDirectory)
          const PopupMenuItem(value: 'download',
              child: _MenuRow(Icons.download, 'Download', AetherColors.accent)),
        if (isArchive)
          const PopupMenuItem(value: 'extract',
              child: _MenuRow(Icons.unarchive_outlined, 'Extract Here', AetherColors.accentTeal)),
        if (!entry.isDirectory)
          const PopupMenuItem(value: 'compress',
              child: _MenuRow(Icons.archive_outlined, 'Compress to Zip', AetherColors.textSecondary)),
        const PopupMenuItem(value: 'delete',
            child: _MenuRow(Icons.delete_outline, 'Delete', AetherColors.accentRed)),
      ],
    );
    if (!context.mounted) return;
    switch (action) {
      case 'rename':
        _showRenameDialog(context, entry.name, notifier);
      case 'download':
        final dir = await getDownloadsDirectory();
        notifier.download(entry.name, dir?.path ?? '.');
      case 'extract':
        notifier.extractZip(entry.name);
      case 'compress':
        notifier.compressToZip([entry.name], '${entry.name}.zip');
      case 'delete':
        _showDeleteDialog(context, entry, notifier);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (entry.isDirectory) {
          notifier.navigate('${state.currentPath}/${entry.name}');
        }
      },
      onSecondaryTapUp: (d) => _showContextMenu(context, d.globalPosition),
      onLongPressStart: (d) => _showContextMenu(context, d.globalPosition),
      child: Container(
        decoration: BoxDecoration(
          color: AetherColors.glassBase,
          borderRadius: BorderRadius.circular(6),
        ),
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_iconForEntry(entry), size: 28, color: _colorForEntry(entry)),
            const SizedBox(height: 4),
            Text(
              entry.name,
              style: const TextStyle(
                  color: AetherColors.textPrimary, fontSize: 10),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              textAlign: TextAlign.center,
            ),
            if (!entry.isDirectory)
              Text(entry.sizeFormatted,
                  style: const TextStyle(
                      color: AetherColors.textSecondary, fontSize: 9)),
          ],
        ),
      ),
    );
  }
}

// ─── Transfer Tray ────────────────────────────────────────────────────────────

class _TransferTray extends StatelessWidget {
  const _TransferTray({required this.name, required this.progress});
  final String name;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      color: AetherColors.surfaceDeep,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: AetherColors.accent,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(name,
                    style: const TextStyle(
                        color: AetherColors.textSecondary, fontSize: 10),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AetherColors.glassBase,
                  valueColor:
                      const AlwaysStoppedAnimation(AetherColors.accent),
                  minHeight: 3,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('${(progress * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                  color: AetherColors.textSecondary, fontSize: 10)),
        ],
      ),
    );
  }
}

// ─── Empty folder placeholder ─────────────────────────────────────────────────

class _EmptyFolder extends StatelessWidget {
  const _EmptyFolder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_open, color: AetherColors.textSecondary, size: 32),
          SizedBox(height: 8),
          Text('Empty folder',
              style: TextStyle(
                  color: AetherColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

class _MenuRow extends StatelessWidget {
  const _MenuRow(this.icon, this.label, this.color);
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }
}

bool _isArchive(String name) {
  final lower = name.toLowerCase();
  return lower.endsWith('.zip') ||
      lower.endsWith('.tar.gz') ||
      lower.endsWith('.tgz') ||
      lower.endsWith('.tar') ||
      lower.endsWith('.gz') ||
      lower.endsWith('.bz2') ||
      lower.endsWith('.xz') ||
      lower.endsWith('.rar') ||
      lower.endsWith('.7z');
}

IconData _iconForEntry(SftpEntry e) {
  if (e.isDirectory) return Icons.folder;
  final ext =
      e.name.contains('.') ? e.name.split('.').last.toLowerCase() : '';
  return switch (ext) {
    'zip' || 'tar' || 'gz' || 'bz2' || 'xz' || '7z' || 'rar' || 'tgz' =>
      Icons.archive,
    'jpg' || 'jpeg' || 'png' || 'gif' || 'bmp' || 'svg' || 'webp' =>
      Icons.image,
    'mp4' || 'mkv' || 'avi' || 'mov' || 'webm' => Icons.video_file,
    'mp3' || 'wav' || 'flac' || 'aac' || 'ogg' => Icons.audio_file,
    'py' ||
    'js' ||
    'ts' ||
    'dart' ||
    'go' ||
    'rs' ||
    'cpp' ||
    'c' ||
    'java' ||
    'sh' ||
    'rb' ||
    'php' =>
      Icons.code,
    'html' || 'css' || 'xml' || 'json' || 'yaml' || 'yml' || 'toml' =>
      Icons.code,
    'txt' || 'md' || 'log' => Icons.description,
    'pdf' => Icons.picture_as_pdf,
    'doc' || 'docx' || 'odt' => Icons.article,
    'xls' || 'xlsx' || 'csv' || 'ods' => Icons.table_chart,
    'ppt' || 'pptx' || 'odp' => Icons.slideshow,
    'db' || 'sqlite' || 'sql' => Icons.storage,
    _ => Icons.insert_drive_file,
  };
}

Color _colorForEntry(SftpEntry e) {
  if (e.isDirectory) return AetherColors.accentYellow;
  final ext =
      e.name.contains('.') ? e.name.split('.').last.toLowerCase() : '';
  return switch (ext) {
    'zip' || 'tar' || 'gz' || 'bz2' || 'xz' || '7z' || 'rar' || 'tgz' =>
      AetherColors.accentYellow,
    'jpg' || 'jpeg' || 'png' || 'gif' || 'bmp' || 'svg' || 'webp' =>
      AetherColors.accentTeal,
    'mp4' || 'mkv' || 'avi' || 'mov' || 'webm' => const Color(0xFF9B59B6),
    'mp3' || 'wav' || 'flac' || 'aac' || 'ogg' => const Color(0xFFE91E63),
    'py' ||
    'js' ||
    'ts' ||
    'dart' ||
    'go' ||
    'rs' ||
    'cpp' ||
    'c' ||
    'java' ||
    'sh' ||
    'rb' ||
    'php' =>
      AetherColors.accent,
    'html' || 'css' || 'xml' || 'json' || 'yaml' || 'yml' || 'toml' =>
      AetherColors.accent,
    'pdf' => AetherColors.accentRed,
    'txt' || 'md' || 'log' => AetherColors.textSecondary,
    _ => AetherColors.textSecondary,
  };
}

void _showNameDialog(
    BuildContext context, String title, void Function(String) onConfirm) {
  final controller = TextEditingController();
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: AetherColors.surfaceDeep,
      title: Text(title,
          style: const TextStyle(color: AetherColors.textPrimary)),
      content: TextField(
        controller: controller,
        autofocus: true,
        style: const TextStyle(color: AetherColors.textPrimary, fontSize: 13),
        decoration: const InputDecoration(
          hintText: 'Enter name…',
          hintStyle: TextStyle(color: AetherColors.textSecondary),
          enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AetherColors.glassBorder)),
          focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AetherColors.accent)),
        ),
        onSubmitted: (v) {
          if (v.trim().isNotEmpty) {
            Navigator.pop(context);
            onConfirm(v.trim());
          }
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel',
              style: TextStyle(color: AetherColors.textSecondary)),
        ),
        TextButton(
          onPressed: () {
            final v = controller.text.trim();
            if (v.isNotEmpty) {
              Navigator.pop(context);
              onConfirm(v);
            }
          },
          child: const Text('Create',
              style: TextStyle(color: AetherColors.accent)),
        ),
      ],
    ),
  );
}

void _showRenameDialog(
    BuildContext context, String oldName, FileManagerNotifier notifier) {
  final controller = TextEditingController(text: oldName);
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: AetherColors.surfaceDeep,
      title: const Text('Rename',
          style: TextStyle(color: AetherColors.textPrimary)),
      content: TextField(
        controller: controller,
        autofocus: true,
        style: const TextStyle(color: AetherColors.textPrimary, fontSize: 13),
        decoration: const InputDecoration(
          enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AetherColors.glassBorder)),
          focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AetherColors.accent)),
        ),
        onSubmitted: (v) {
          if (v.trim().isNotEmpty && v.trim() != oldName) {
            Navigator.pop(context);
            notifier.rename(oldName, v.trim());
          }
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel',
              style: TextStyle(color: AetherColors.textSecondary)),
        ),
        TextButton(
          onPressed: () {
            final v = controller.text.trim();
            if (v.isNotEmpty && v != oldName) {
              Navigator.pop(context);
              notifier.rename(oldName, v);
            }
          },
          child: const Text('Rename',
              style: TextStyle(color: AetherColors.accent)),
        ),
      ],
    ),
  );
}

void _showDeleteDialog(
    BuildContext context, SftpEntry entry, FileManagerNotifier notifier) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: AetherColors.surfaceDeep,
      title: Text('Delete "${entry.name}"?',
          style: const TextStyle(color: AetherColors.textPrimary)),
      content: Text(
        entry.isDirectory
            ? 'This will permanently delete the folder and all its contents.'
            : 'This file will be permanently deleted.',
        style: const TextStyle(
            color: AetherColors.textSecondary, fontSize: 13),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel',
              style: TextStyle(color: AetherColors.textSecondary)),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            notifier.deleteEntry(entry);
          },
          child: const Text('Delete',
              style: TextStyle(color: AetherColors.accentRed)),
        ),
      ],
    ),
  );
}
