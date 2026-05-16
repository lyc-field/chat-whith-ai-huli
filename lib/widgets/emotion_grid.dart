import 'package:flutter/material.dart';
import '../models/emotion_state.dart';
import '../services/emotion_service.dart';

/// Shared 5×5 emotion grid widget used by EmotionDetailPage and AdminPanelPage.
/// Eliminates duplicate grid-building code across the two pages.
class EmotionGrid extends StatelessWidget {
  final List<List<String>> grid;
  final int highlightRow;
  final int highlightCol;
  final String? title;
  final String? xLabel;
  final String? yLabel;
  final List<String> xBrackets;
  final List<String> yBrackets;
  final bool compact;

  const EmotionGrid({
    super.key,
    required this.grid,
    required this.highlightRow,
    required this.highlightCol,
    this.title,
    this.xLabel,
    this.yLabel,
    this.xBrackets = const ['0', '12.5', '25', '37.5', '50'],
    this.yBrackets = const ['50', '37.5', '25', '12.5', '0'],
    this.compact = false,
  });

  /// Factory for the "towards user" grid.
  factory EmotionGrid.towardsUser({
    required EmotionState state,
    double? affectionOverride,
    double? libidoOtherOverride,
    double? aggressionOtherOverride,
    bool compact = false,
  }) {
    final effectiveState = EmotionState(
      id: state.id,
      conversationId: state.conversationId,
      affection: affectionOverride ?? state.affection,
      currentLibidoOther: libidoOtherOverride ?? state.currentLibidoOther,
      currentAggressionOther: aggressionOtherOverride ?? state.currentAggressionOther,
    );
    final grid = EmotionTables.getTowardsUserGrid(effectiveState);
    final bracket = EmotionTables.getTowardsUserBracket(effectiveState);
    final showAff = affectionOverride ?? state.affection;
    return EmotionGrid(
      grid: grid,
      highlightRow: bracket.row,
      highlightCol: bracket.col,
      title: compact ? '对用户 (好感=${showAff.toStringAsFixed(0)})' : null,
      xLabel: compact ? null : '他力比多 →',
      yLabel: compact ? null : '他\n攻\n击\n性\n↓',
      compact: compact,
    );
  }

  /// Factory for the "self" grid.
  factory EmotionGrid.self({
    required EmotionState state,
    double? libidoSelfOverride,
    double? aggressionSelfOverride,
    bool compact = false,
  }) {
    final effectiveState = EmotionState(
      id: state.id,
      conversationId: state.conversationId,
      currentLibidoSelf: libidoSelfOverride ?? state.currentLibidoSelf,
      currentAggressionSelf: aggressionSelfOverride ?? state.currentAggressionSelf,
    );
    final grid = EmotionTables.getSelfGrid();
    final bracket = EmotionTables.getSelfBracket(effectiveState);
    return EmotionGrid(
      grid: grid,
      highlightRow: bracket.row,
      highlightCol: bracket.col,
      title: compact ? '自身' : null,
      xLabel: compact ? null : '自力比多 →',
      yLabel: compact ? null : '自\n攻\n击\n性\n↓',
      compact: compact,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cellW = compact ? 52.0 : 64.0;
    final cellH = compact ? 28.0 : 36.0;
    final fontSize = compact ? 9.0 : 10.0;
    final bracketFontSize = compact ? 8.0 : 9.0;
    final yLabelWidth = compact ? 24.0 : 28.0;

    Widget gridWidget = Column(
      children: [
        // X bracket header
        Row(children: [
          SizedBox(width: yLabelWidth),
          ...xBrackets.map((b) => SizedBox(
            width: cellW,
            child: Center(child: Text(b,
                style: TextStyle(fontSize: bracketFontSize, color: Colors.grey))),
          )),
        ]),
        // Data rows
        ...List.generate(grid.length, (r) => Row(
          children: [
            SizedBox(
              width: yLabelWidth,
              child: Center(child: Text(yBrackets[r],
                  style: TextStyle(fontSize: bracketFontSize, color: Colors.grey))),
            ),
            ...List.generate(grid[r].length, (c) {
              final isCurrent = r == highlightRow && c == highlightCol;
              return Container(
                width: cellW, height: cellH,
                margin: const EdgeInsets.all(0.5),
                decoration: BoxDecoration(
                  color: isCurrent ? Colors.green.shade100 : Colors.white,
                  border: Border.all(
                    color: isCurrent ? Colors.green : Colors.grey.shade300,
                    width: isCurrent ? 1.5 : 0.5,
                  ),
                  borderRadius: BorderRadius.circular(compact ? 2.0 : 3.0),
                ),
                alignment: Alignment.center,
                child: Text(grid[r][c],
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis),
              );
            }),
          ],
        )),
      ],
    );

    // Wrap in horizontal scroll
    final scrollable = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: gridWidget,
    );

    if (compact) {
      if (title != null) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            scrollable,
          ],
        );
      }
      return scrollable;
    }

    // Full-size layout with axis labels
    Widget body = Column(children: [
      if (xLabel != null)
        Center(child: Text(xLabel!,
            style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.outline))),
      if (xLabel != null) const SizedBox(height: 4),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (yLabel != null)
            SizedBox(
              width: 20,
              child: Text(yLabel!,
                  style: TextStyle(fontSize: 9, color: Theme.of(context).colorScheme.outline),
                  textAlign: TextAlign.center),
            ),
          if (yLabel != null) const SizedBox(width: 4),
          Expanded(child: scrollable),
        ],
      ),
    ]);

    return Card(
      child: Padding(padding: const EdgeInsets.all(8), child: body),
    );
  }
}
