import 'package:flutter/material.dart';
import '../../models/source.dart';

class SourceHeader extends StatelessWidget {
  final Source source;
  final bool isExpanded;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onActivate;

  const SourceHeader({
    super.key,
    required this.source,
    required this.isExpanded,
    required this.isActive,
    required this.onTap,
    required this.onEdit,
    required this.onActivate,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.5)
              : null,
          border: Border(
            bottom: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isExpanded ? Icons.expand_more : Icons.chevron_right,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '"${source.title}"',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: isActive
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${source.author} (${source.year})',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                source.documentType.name.toUpperCase(),
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: Colors.grey),
              ),
            ),
            const SizedBox(width: 6),
            if (!isActive)
              IconButton(
                icon: const Icon(Icons.visibility, size: 18),
                onPressed: onActivate,
                tooltip: 'View PDF',
                visualDensity: VisualDensity.compact,
              ),
            IconButton(
              icon: const Icon(Icons.edit, size: 18),
              onPressed: onEdit,
              tooltip: 'Edit source info',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}
