import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:path/path.dart' as p;
import '../../providers/library_provider.dart';
import '../../providers/sources_provider.dart';
import '../dialogs/source_metadata_dialog.dart';

class LibrarySidebar extends ConsumerStatefulWidget {
  const LibrarySidebar({super.key});

  @override
  ConsumerState<LibrarySidebar> createState() => _LibrarySidebarState();
}

class _LibrarySidebarState extends ConsumerState<LibrarySidebar> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final folderPath = ref.watch(libraryFolderProvider);
    final pdfFiles = ref.watch(pdfFilesProvider);
    final activeSource = ref.watch(activeSourceProvider);
    final sources = ref.watch(sourcesProvider);

    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: (details) => _handleDroppedFiles(context, details.files),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: _isDragging
              ? Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withValues(alpha: 0.2)
              : Theme.of(context).colorScheme.surfaceContainerLow,
          border: Border(
            right: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
        child: Column(
          children: [
            _buildHeader(context, ref, folderPath),
            Expanded(
              child: folderPath == null
                  ? _buildEmptyState(context, ref)
                  : pdfFiles.isEmpty
                      ? _buildNoFilesState(context)
                      : _buildFileList(
                          context, ref, pdfFiles, activeSource, sources),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, String? folderPath) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.folder_open, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              folderPath != null ? p.basename(folderPath) : 'Library',
              style: Theme.of(context).textTheme.titleSmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.folder, size: 20),
            onPressed: () => _pickFolder(ref),
            tooltip: 'Open folder',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'Open a folder\ncontaining PDFs\nor drop PDF files here',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: () => _pickFolder(ref),
              icon: const Icon(Icons.folder_open, size: 18),
              label: const Text('Open Folder'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoFilesState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.picture_as_pdf_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No PDF files\nin this folder\nDrop PDFs here to add',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileList(
    BuildContext context,
    WidgetRef ref,
    List<FileSystemEntity> pdfFiles,
    dynamic activeSource,
    List sources,
  ) {
    return ListView.builder(
      itemCount: pdfFiles.length,
      itemBuilder: (context, index) {
        final file = pdfFiles[index];
        final fileName = p.basenameWithoutExtension(file.path);
        final isActive = activeSource?.filePath == file.path;
        final hasSource = sources.any((s) => s.filePath == file.path);

        return ListTile(
          dense: true,
          selected: isActive,
          selectedTileColor:
              Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
          leading: Icon(
            Icons.picture_as_pdf,
            size: 20,
            color: hasSource
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline,
          ),
          title: Text(
            fileName,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: hasSource
              ? Text(
                  '${sources.firstWhere((s) => s.filePath == file.path).quotes.length} quotes',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                )
              : null,
          onTap: () => _openPdf(context, ref, file.path),
        );
      },
    );
  }

  Future<void> _pickFolder(WidgetRef ref) async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      ref.read(libraryFolderProvider.notifier).state = result;
    }
  }

  Future<void> _openPdf(
    BuildContext context,
    WidgetRef ref,
    String filePath,
  ) async {
    final sources = ref.read(sourcesProvider);
    // Check if source already exists
    final existing = sources.where((s) => s.filePath == filePath).firstOrNull;

    if (existing != null) {
      ref.read(activeSourceIdProvider.notifier).state = existing.id;
      return;
    }

    // New PDF - ask for metadata
    final metadata = await showDialog<SourceMetadataResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => SourceMetadataDialog(
        initialTitle: p.basenameWithoutExtension(filePath),
      ),
    );

    if (metadata == null) return;

    final source = await ref.read(sourcesProvider.notifier).addSource(
          title: metadata.title,
          author: metadata.author,
          year: metadata.year,
          publisher: metadata.publisher,
          filePath: filePath,
        );

    ref.read(activeSourceIdProvider.notifier).state = source.id;
  }

  Future<void> _handleDroppedFiles(
    BuildContext context,
    List files,
  ) async {
    setState(() => _isDragging = false);
    if (files.isEmpty) return;

    final paths = files
        .map((file) => (file as dynamic).path)
        .whereType<String>()
        .toList();

    if (paths.isEmpty) return;

    final pdfPaths = paths
        .where((path) =>
            FileSystemEntity.typeSync(path) == FileSystemEntityType.file &&
            p.extension(path).toLowerCase() == '.pdf')
        .toList();

    final directoryPaths = paths
        .where((path) =>
            FileSystemEntity.typeSync(path) == FileSystemEntityType.directory)
        .toList();

    if (pdfPaths.isEmpty && directoryPaths.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Only PDF files or folders are supported')),
        );
      }
      return;
    }

    if (pdfPaths.isNotEmpty) {
      ref.read(libraryFolderProvider.notifier).state =
          p.dirname(pdfPaths.first);
      for (final path in pdfPaths) {
        await _openPdf(context, ref, path);
      }
      return;
    }

    if (directoryPaths.isNotEmpty) {
      ref.read(libraryFolderProvider.notifier).state = directoryPaths.first;
    }
  }
}
