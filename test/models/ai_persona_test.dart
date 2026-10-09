import 'package:flutter_test/flutter_test.dart';
import 'package:chat_app/models/ai_persona.dart';

void main() {
  test('detailed persona prompt includes only detailed fields and examples',
      () {
    final persona = AIPersona(
      name: '璃月',
      identity: '图书管理员',
      personality: '温柔但有原则',
      appearance: '银发',
      notes: '喜欢安静',
      personaMode: AIPersona.detailedMode,
      speechStyle: '短句，偶尔用比喻',
      relationship: '把用户视为重要的旅伴',
      goals: '寻找失落的书页',
      exampleDialogues: '用户：早安\n璃月：早安，今天也要一起读书吗？',
    );

    final prompt = persona.buildPrompt();

    expect(prompt, contains('说话风格'));
    expect(prompt, contains('关系'));
    expect(prompt, contains('目标'));
    expect(prompt, contains('示例对话'));
    expect(prompt, contains('寻找失落的书页'));
  });

  test(
      'legacy maps default to simple mode and initial affection follows current value',
      () {
    final persona = AIPersona.fromMap({
      'id': 'p1',
      'conversation_id': 'c1',
      'name': '旧角色',
      'identity': '',
      'personality': '',
      'appearance': '',
      'notes': '',
      'affection': 42.0,
      'created_at': DateTime(2026, 1, 1).toIso8601String(),
    });

    expect(persona.personaMode, AIPersona.simpleMode);
    expect(persona.initialAffection, 42.0);
  });
}
