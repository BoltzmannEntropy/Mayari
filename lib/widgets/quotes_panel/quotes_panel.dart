import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/source.dart';
import '../../models/quote.dart';
import '../../providers/sources_provider.dart';
import '../../services/export_service.dart';
import '../dialogs/source_metadata_dialog.dart';
import '../dialogs/quote_edit_dialog.dart';
import 'source_header.dart';
import 'quote_card.dart';

class QuotesPanel extends ConsumerStatefulWidget {
  const QuotesPanel({super.key});

  @override
  ConsumerState<QuotesPanel> createState() => _QuotesPanelState();
}

class _QuotesPanelState extends ConsumerState<QuotesPanel> {
  final Set<String> _expandedSources = {};
  final _exportService = ExportService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final activeId = ref.read(activeSourceIdProvider);
      if (activeId != null) {
        _expandedSources.add(activeId);
      }
    });
  }

  Future<void> _openPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result == null || result.files.isEmpty) return;

    final filePath = result.files.first.path;
    if (filePath == null) return;

    final sources = ref.read(sourcesProvider);
    final existing = sources.where((s) => s.filePath == filePath).firstOrNull;

    if (existing != null) {
      ref.read(activeSourceIdProvider.notifier).state = existing.id;
      setState(() => _expandedSources.add(existing.id));
      return;
    }

    if (!mounted) return;

    final metadata = await showDialog<SourceMetadataResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const SourceMetadataDialog(),
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
    setState(() => _expandedSources.add(source.id));
  }

  Future<void> _editSource(Source source) async {
    final metadata = await showDialog<SourceMetadataResult>(
      context: context,
      builder: (context) => SourceMetadataDialog(
        initialTitle: source.title,
        initialAuthor: source.author,
        initialYear: source.year,
        initialPublisher: source.publisher,
      ),
    );

    if (metadata == null) return;

    ref.read(sourcesProvider.notifier).updateSource(source.copyWith(
          title: metadata.title,
          author: metadata.author,
          year: metadata.year,
          publisher: metadata.publisher,
        ));
  }

  Future<void> _editQuote(Quote quote) async {
    final updated = await showDialog<Quote>(
      context: context,
      builder: (context) => QuoteEditDialog(quote: quote),
    );

    if (updated != null) {
      ref.read(sourcesProvider.notifier).updateQuote(updated);
    }
  }

  Future<void> _deleteQuote(Quote quote) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Quote'),
        content: const Text('Are you sure you want to delete this quote?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      ref.read(sourcesProvider.notifier).removeQuote(quote.sourceId, quote.id);
    }
  }

  Future<void> _export() async {
    final sources = ref.read(sourcesProvider);
    if (sources.isEmpty) return;

    final markdown = _exportService.exportToMarkdown(sources);

    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Quotes',
      fileName: 'quotes.md',
      type: FileType.custom,
      allowedExtensions: ['md'],
    );

    if (result != null) {
      await File(result).writeAsString(markdown);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quotes exported successfully')),
        );
      }
    }
  }

  Future<void> _copyToClipboard() async {
    final sources = ref.read(sourcesProvider);
    if (sources.isEmpty) return;

    final markdown = _exportService.exportToMarkdown(sources);
    await Clipboard.setData(ClipboardData(text: markdown));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quotes copied to clipboard')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sources = ref.watch(sourcesProvider);
    final activeId = ref.watch(activeSourceIdProvider);

    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: sources.isEmpty
              ? const Center(
                  child: Text(
                    'No sources yet.\nOpen a PDF to start collecting quotes.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: sources.length,
                  itemBuilder: (context, index) {
                    final source = sources[index];
                    final isExpanded = _expandedSources.contains(source.id);
                    final isActive = activeId == source.id;

                    return Column(
                      children: [
                        SourceHeader(
                          source: source,
                          isExpanded: isExpanded,
                          isActive: isActive,
                          onTap: () {
                            setState(() {
                              if (isExpanded) {
                                _expandedSources.remove(source.id);
                              } else {
                                _expandedSources.add(source.id);
                              }
                            });
                          },
                          onEdit: () => _editSource(source),
                          onActivate: () {
                            ref.read(activeSourceIdProvider.notifier).state =
                                source.id;
                          },
                        ),
                        if (isExpanded) _buildQuotesList(source),
                      ],
                    );
                  },
                ),
        ),
        _buildFooter(sources),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          Text(
            'Quotes',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _openPdf,
            tooltip: 'Open PDF',
          ),
        ],
      ),
    );
  }

  Widget _buildQuotesList(Source source) {
    final quotes = List.of(source.quotes)
      ..sort((a, b) => a.order.compareTo(b.order));

    if (quotes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: const Text(
          'No quotes yet. Select text in the PDF to add quotes.',
          style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
        ),
      );
    }

    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: quotes.length,
      onReorder: (oldIndex, newIndex) {
        if (newIndex > oldIndex) newIndex--;
        ref
            .read(sourcesProvider.notifier)
            .reorderQuotes(source.id, oldIndex, newIndex);
      },
      itemBuilder: (context, index) {
        final quote = quotes[index];
        return QuoteCard(
          key: ValueKey(quote.id),
          quote: quote,
          onEdit: () => _editQuote(quote),
          onDelete: () => _deleteQuote(quote),
        );
      },
    );
  }

  Widget _buildFooter(List<Source> sources) {
    final totalQuotes = sources.fold<int>(0, (sum, s) => sum + s.quotes.length);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          Text(
            '$totalQuotes quotes from ${sources.length} sources',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: sources.isEmpty ? null : _copyToClipboard,
            tooltip: 'Copy to clipboard',
          ),
          FilledButton.icon(
            onPressed: sources.isEmpty ? null : _export,
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Export'),
          ),
        ],
      ),
    );
  }
}
