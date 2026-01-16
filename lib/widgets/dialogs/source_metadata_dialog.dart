import 'package:flutter/material.dart';

class SourceMetadataResult {
  final String title;
  final String author;
  final int year;
  final String? publisher;

  SourceMetadataResult({
    required this.title,
    required this.author,
    required this.year,
    this.publisher,
  });
}

class SourceMetadataDialog extends StatefulWidget {
  final String? initialTitle;
  final String? initialAuthor;
  final int? initialYear;
  final String? initialPublisher;

  const SourceMetadataDialog({
    super.key,
    this.initialTitle,
    this.initialAuthor,
    this.initialYear,
    this.initialPublisher,
  });

  @override
  State<SourceMetadataDialog> createState() => _SourceMetadataDialogState();
}

class _SourceMetadataDialogState extends State<SourceMetadataDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _authorController;
  late final TextEditingController _yearController;
  late final TextEditingController _publisherController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
    _authorController = TextEditingController(text: widget.initialAuthor ?? '');
    _yearController = TextEditingController(
      text: widget.initialYear?.toString() ?? DateTime.now().year.toString(),
    );
    _publisherController =
        TextEditingController(text: widget.initialPublisher ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _yearController.dispose();
    _publisherController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop(SourceMetadataResult(
        title: _titleController.text.trim(),
        author: _authorController.text.trim(),
        year: int.parse(_yearController.text.trim()),
        publisher: _publisherController.text.trim().isEmpty
            ? null
            : _publisherController.text.trim(),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Source Information'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Title is required' : null,
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _authorController,
                decoration: const InputDecoration(
                  labelText: 'Author(s) *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Author is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _yearController,
                decoration: const InputDecoration(
                  labelText: 'Year *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Year is required';
                  final year = int.tryParse(v.trim());
                  if (year == null || year < 1000 || year > 2100) {
                    return 'Enter a valid year';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _publisherController,
                decoration: const InputDecoration(
                  labelText: 'Publisher (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
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
