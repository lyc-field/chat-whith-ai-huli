import 'package:flutter_test/flutter_test.dart';
import 'package:chat_app/models/ai_persona.dart';
import 'package:chat_app/services/persona_io.dart';

void main() {
  test(
      'exports and imports the complete selected persona without current affection',
      () {
    final source = AIPersona(
      name: '璃月',
      personaMode: AIPersona.detailedMode,
      speechStyle: '轻声',
      relationship: '旅伴',
      goals: '找书',
      exampleDialogues: '用户：嗨\n璃月：嗯？',
      affection: 73,
      initialAffection: 35,
    );

    final raw = PersonaIO.buildExportJson(
      selectedPersonas: [source],
      userPersona: '旅行者',
      openingLine: '欢迎回来',
      worldBackground: '图书馆',
    );
    final parsed = PersonaIO.parseImportJson(raw);

    expect(parsed.error, isNull);
    expect(parsed.personas.single.personaMode, AIPersona.detailedMode);
    expect(parsed.personas.single.exampleDialogues, contains('璃月'));
    expect(parsed.personas.single.initialAffection, 35);
    expect(parsed.personas.single.affection, 35);
    expect(raw, isNot(contains('"affection": 73')));
  });
}
