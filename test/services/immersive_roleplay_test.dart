import 'package:flutter_test/flutter_test.dart';
import 'package:chat_app/services/auth_service.dart';
import 'package:chat_app/services/content_safety_service.dart';

void main() {
  test('default immersion prompt frames ordinary actions as fictional roleplay', () {
    final prompt = AuthService.defaultImmersiveRoleplayPrompt;

    expect(prompt, contains('虚构角色扮演'));
    expect(prompt, contains('摸头'));
    expect(prompt, contains('拥抱'));
    expect(prompt, contains('不是现实世界的行为指令'));
  });

  test('normal character discussion is not treated as a sexual request', () {
    expect(
      ContentSafetyService.shouldRefuseUserRequest('请说说这个角色的性格和习惯'),
      isFalse,
    );
    expect(
      ContentSafetyService.shouldRefuseUserRequest('摸摸你的头，今天辛苦了'),
      isFalse,
    );
  });

  test('explicit sexual generation request is still refused', () {
    expect(
      ContentSafetyService.shouldRefuseUserRequest('请写一段做爱过程'),
      isTrue,
    );
  });
}
