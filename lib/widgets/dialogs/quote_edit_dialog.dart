import 'package:flutter/material.dart';
import '../../models/quote.dart';

class QuoteEditDialog extends StatefulWidget {
  final Quote quote;

  const QuoteEditDialog({super.key, required this.quote});

  @override
  State<QuoteEditDialog> createState() => _QuoteEditDialogState();
}

class _QuoteEditDialogState extends State<QuoteEditDialog> {
  late final TextEditingController _textController;
  late final TextEditingController _notesController;
  late final TextEditingController _pageController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.quote.text);
    _notesController = TextEditingController(text: widget.quote.notes ?? '');
    _pageController =
        TextEditingController(text: widget.quote.pageNumber.toString());
  }

  @override
  void dispose() {
    _textController.dispose();
    _notesController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _submit() {
    final page = int.tryParse(_pageController.text.trim());
    if (_textController.text.trim().isEmpty || page == null) return;

    Navigator.of(context).pop(widget.quote.copyWith(
      text: _textController.text.trim(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      pageNumber: page,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Quote'),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _textController,
              decoration: const InputDecoration(
                labelText: 'Quote text',
                border: OutlineInputBorder(),
              ),
              maxLines: 5,
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _pageController,
              decoration: const InputDecoration(
                labelText: 'Page number',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
