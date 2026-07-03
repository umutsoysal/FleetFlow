import 'package:flutter/material.dart';

class DocumentSection {
  final String heading;
  final String body;

  const DocumentSection({required this.heading, required this.body});
}

class LegalDocumentScreen extends StatelessWidget {
  final String title;
  final String summary;
  final List<DocumentSection> sections;

  const LegalDocumentScreen({
    super.key,
    required this.title,
    required this.summary,
    required this.sections,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(summary, style: theme.textTheme.bodyLarge),
            ),
          ),
          const SizedBox(height: 16),
          ...sections.map(
            (section) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(section.heading, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      SelectableText(
                        section.body,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
