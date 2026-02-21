import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'screens/workspace_screen.dart';
import 'screens/settings_screen.dart';
import 'providers/audiobook_provider.dart';
import 'providers/library_provider.dart';
import 'providers/sources_provider.dart';
import 'services/document_format.dart';
import 'services/examples_loader_service.dart';
import 'widgets/audiobooks/audiobook_jobs_panel.dart';
import 'widgets/audiobooks/audiobooks_panel.dart';

void main() {
  runApp(const ProviderScope(child: MayariApp()));
}

class MayariApp extends StatelessWidget {
  const MayariApp({super.key});

  @override
  Widget build(BuildContext context) {
    final isMacOS = !kIsWeb && Platform.isMacOS;

    return MaterialApp(
      title: 'Mayari',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        platform: isMacOS ? TargetPlatform.macOS : null,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        platform: isMacOS ? TargetPlatform.macOS : null,
      ),
      themeMode: ThemeMode.system,
      home: const MainShell(),
    );
  }
}

enum _BottomDeckView { jobs, audiobooks }

enum _LibraryMenuAction { examples }

/// Main navigation shell with tabs for Reader and Settings
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _selectedIndex = 0;
  _BottomDeckView _bottomDeckView = _BottomDeckView.jobs;
  double _bottomDeckHeight = 200; // Resizable height for Jobs/Audio panel
  static const double _minBottomDeckHeight = 100;
  static const double _maxBottomDeckHeight = 400;

  static const List<Widget> _screens = [WorkspaceScreen(), SettingsScreen()];

  @override
  Widget build(BuildContext context) {
    final folderPath = ref.watch(libraryFolderProvider);
    final libraryFiles = ref.watch(libraryFilesProvider);
    final activeSource = ref.watch(activeSourceProvider);
    final sources = ref.watch(sourcesProvider);

    return Scaffold(
      body: Row(
        children: [
          // Left navigation deck
          Container(
            width: 200,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              border: Border(
                right: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Navigation rail at top
                SizedBox(
                  height: 148,
                  child: NavigationRail(
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: (index) {
                      setState(() => _selectedIndex = index);
                    },
                    extended: true,
                    minExtendedWidth: 200,
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.menu_book_outlined),
                        selectedIcon: Icon(Icons.menu_book),
                        label: Text('Reader'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.settings_outlined),
                        selectedIcon: Icon(Icons.settings),
                        label: Text('Settings'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // PDF Library section
                _buildLibraryHeader(context, folderPath),
                Expanded(
                  child: folderPath == null
                      ? _buildEmptyLibrary(context)
                      : libraryFiles.isEmpty
                      ? _buildNoFiles(context)
                      : _buildLibraryList(
                          context,
                          libraryFiles,
                          activeSource,
                          sources,
                        ),
                ),
                // Resize handle
                MouseRegion(
                  cursor: SystemMouseCursors.resizeRow,
                  child: GestureDetector(
                    onVerticalDragUpdate: (details) {
                      setState(() {
                        _bottomDeckHeight =
                            (_bottomDeckHeight - details.delta.dy).clamp(
                              _minBottomDeckHeight,
                              _maxBottomDeckHeight,
                            );
                      });
                    },
                    child: Container(
                      height: 8,
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      child: Center(
                        child: Container(
                          width: 32,
                          height: 3,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.outline,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Jobs/Audio toggle
                _buildBottomDeckToggle(context),
                // Jobs or Audiobooks panel (resizable)
                SizedBox(
                  height: _bottomDeckHeight,
                  child: _bottomDeckView == _BottomDeckView.jobs
                      ? const AudiobookJobsPanel()
                      : const AudiobooksPanel(),
                ),
              ],
            ),
          ),
          // Main content
          Expanded(child: _screens[_selectedIndex]),
        ],
      ),
    );
  }

  Widget _buildLibraryHeader(BuildContext context, String? folderPath) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Row(
        children: [
          const Icon(Icons.folder_open, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              folderPath != null ? p.basename(folderPath) : 'Library',
              style: Theme.of(context).textTheme.titleSmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.folder, size: 18),
            onPressed: _pickFolder,
            tooltip: 'Open folder',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          PopupMenuButton<_LibraryMenuAction>(
            tooltip: 'Library menu',
            onSelected: (action) async {
              if (action == _LibraryMenuAction.examples) {
                await _loadExamples(context);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem<_LibraryMenuAction>(
                value: _LibraryMenuAction.examples,
                child: Row(
                  children: [
                    Icon(Icons.auto_stories_outlined, size: 16),
                    SizedBox(width: 8),
                    Text('Load Examples'),
                  ],
                ),
              ),
            ],
            icon: const Icon(Icons.more_horiz, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyLibrary(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_outlined,
              size: 36,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 8),
            Text(
              'Open a folder\nwith PDF, DOCX, or EPUB',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: _pickFolder,
              icon: const Icon(Icons.folder_open, size: 16),
              label: const Text('Open', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoFiles(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 36,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 8),
            Text(
              'No supported files\nin this folder',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLibraryList(
    BuildContext context,
    List<FileSystemEntity> files,
    dynamic activeSource,
    List sources,
  ) {
    return ListView.builder(
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        final fileName = p.basenameWithoutExtension(file.path);
        final isActive = activeSource?.filePath == file.path;
        final hasSource = sources.any((s) => s.filePath == file.path);
        final type = documentTypeFromPath(file.path);

        IconData icon;
        switch (type) {
          case SupportedDocumentType.pdf:
            icon = Icons.picture_as_pdf;
            break;
          case SupportedDocumentType.docx:
            icon = Icons.description;
            break;
          case SupportedDocumentType.epub:
            icon = Icons.menu_book;
            break;
          case SupportedDocumentType.unknown:
            icon = Icons.insert_drive_file_outlined;
            break;
        }

        return ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          selected: isActive,
          selectedTileColor: Theme.of(
            context,
          ).colorScheme.primaryContainer.withValues(alpha: 0.5),
          leading: Icon(
            icon,
            size: 18,
            color: hasSource
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline,
          ),
          title: Text(
            fileName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: hasSource
              ? Text(
                  sources.firstWhere((s) => s.filePath == file.path).author,
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                )
              : null,
          onTap: () => _openDocument(file.path),
        );
      },
    );
  }

  Widget _buildBottomDeckToggle(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: SegmentedButton<_BottomDeckView>(
        segments: const [
          ButtonSegment<_BottomDeckView>(
            value: _BottomDeckView.jobs,
            label: Text('Jobs'),
            icon: Icon(Icons.work_history, size: 14),
          ),
          ButtonSegment<_BottomDeckView>(
            value: _BottomDeckView.audiobooks,
            label: Text('Audio'),
            icon: Icon(Icons.audiotrack, size: 14),
          ),
        ],
        selected: {_bottomDeckView},
        onSelectionChanged: (selection) {
          setState(() => _bottomDeckView = selection.first);
        },
        showSelectedIcon: false,
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          textStyle: WidgetStateProperty.all(
            Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ),
    );
  }

  Future<void> _pickFolder() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      ref.read(libraryFolderProvider.notifier).state = result;
    }
  }

  Future<void> _openDocument(String filePath) async {
    final source = await ref
        .read(sourcesProvider.notifier)
        .ensureSourceForFile(filePath);
    ref.read(activeSourceIdProvider.notifier).state = source.id;
    // Switch to Reader view when opening a PDF
    if (_selectedIndex != 0) {
      setState(() => _selectedIndex = 0);
    }
  }

  Future<void> _loadExamples(BuildContext context) async {
    try {
      final bundle = await ExamplesLoaderService().loadExamples();
      ref.read(libraryFolderProvider.notifier).state =
          bundle.documentsDirectory;

      String? firstSourceId;
      for (final doc in bundle.documents) {
        final source = await ref
            .read(sourcesProvider.notifier)
            .ensureSourceForFile(doc.path);
        final updated = source.copyWith(
          title: doc.title,
          author: doc.author,
          year: doc.year,
          publisher: doc.publisher,
        );
        await ref.read(sourcesProvider.notifier).updateSource(updated);
        firstSourceId ??= source.id;
      }

      final audiobooks = bundle.audiobooks
          .map(
            (seed) => Audiobook(
              id: const Uuid().v4(),
              title: seed.title,
              path: seed.path,
              durationSeconds: seed.durationSeconds,
              chunks: seed.chunks,
              voice: seed.voice,
              speed: seed.speed,
              createdAt: DateTime.now(),
            ),
          )
          .toList();
      await ref
          .read(audiobooksProvider.notifier)
          .importBundledExamples(audiobooks);

      if (firstSourceId != null) {
        ref.read(activeSourceIdProvider.notifier).state = firstSourceId;
      }
      if (_selectedIndex != 0) {
        setState(() => _selectedIndex = 0);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Examples loaded: PDF, DOCX, EPUB and ready-made audiobooks.',
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load examples: $e')));
      }
    }
  }
}
