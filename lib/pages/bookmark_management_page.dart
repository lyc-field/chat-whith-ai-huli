import 'package:flutter/material.dart';
import '../models/message.dart';
import '../services/database_service.dart';

class BookmarkManagementPage extends StatefulWidget {
  final String conversationId;
  const BookmarkManagementPage({super.key, required this.conversationId});

  @override
  State<BookmarkManagementPage> createState() => _BookmarkManagementPageState();
}

class _BookmarkManagementPageState extends State<BookmarkManagementPage> {
  List<Message> _bookmarks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bm = await DatabaseService.getBookmarkedMessages(widget.conversationId);
    if (mounted) setState(() { _bookmarks = bm; _loading = false; });
  }

  Future<void> _toggleBookmark(Message msg) async {
    await DatabaseService.updateMessageBookmark(msg.id, false);
    _bookmarks.removeWhere((m) => m.id == msg.id);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Group into user+assistant pairs
    final pairs = <List<Message>>[];
    for (int i = 0; i < _bookmarks.length; i++) {
      if (_bookmarks[i].role == 'user') {
        final pair = <Message>[_bookmarks[i]];
        if (i + 1 < _bookmarks.length && _bookmarks[i + 1].role == 'assistant') {
          pair.add(_bookmarks[i + 1]);
          i++;
        }
        pairs.add(pair);
      } else {
        pairs.add([_bookmarks[i]]);
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('书签管理'), centerTitle: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : pairs.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.flag, size: 48, color: theme.colorScheme.outline),
                    const SizedBox(height: 12),
                    Text('暂无书签', style: theme.textTheme.bodyLarge),
                  ]))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: pairs.length,
                  itemBuilder: (_, i) => _buildPair(pairs[i], theme),
                ),
    );
  }

  Widget _buildPair(List<Message> msgs, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: msgs.map((m) {
            final isUser = m.role == 'user';
            final canUnmark = !(isUser &&
                msgs.length > 1 &&
                msgs.any((x) => x.role == 'assistant' && x.isBookmarked));

            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isUser
                          ? theme.colorScheme.primaryContainer
                          : theme.colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(isUser ? '用户' : 'AI',
                        style: TextStyle(fontSize: 10, color: isUser
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onTertiaryContainer)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(m.content,
                        style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                        maxLines: 6, overflow: TextOverflow.ellipsis),
                  ),
                  if (canUnmark)
                    IconButton(
                      icon: Icon(Icons.flag, size: 16, color: Colors.green.shade600),
                      tooltip: '取消书签',
                      onPressed: () => _toggleBookmark(m),
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: EdgeInsets.zero,
                    )
                  else
                    Icon(Icons.link, size: 14, color: theme.colorScheme.outline),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
