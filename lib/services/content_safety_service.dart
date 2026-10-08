/// Conservative local screening for high-confidence generation requests.
class ContentSafetyService {
  ContentSafetyService._();

  static final RegExp _blockedPattern = RegExp(
    r'(做爱|性爱|性交|口交|肛交|强奸|乱伦|媚药|春药|裸体|裸照|成人视频|约炮|嫖娼|卖淫|援交|性奴|调教|内射|颜射|乳交|\bSM\b|捆绑|后入|呻吟|高潮|精液|阴茎|龟头|阴道|子宫|乳房|乳头|私处|下体|黄文|情色|18禁|r18|nsfw|porn|blowjob|nude|naked|escort|prostitute|毒品|制毒|贩毒|枪支改造|爆炸物|恐怖袭击|刺杀|极端组织|颠覆国家|煽动颠覆|台独|港独|疆独)',
    caseSensitive: false,
  );

  static final RegExp _sexualTopicPattern = RegExp(
    r'(成人内容|色情|情色|黄色|情欲|性爱|性行为|性描写|床上|亲热|做爱|调情|约炮|色色|涩涩|18禁|r18|nsfw)',
    caseSensitive: false,
  );

  static final RegExp _generationVerbPattern = RegExp(
    r'(写|讲|说|描述|展开|继续|来点|给我|扮演|模拟|发|演|做|要|想|求|生成)',
    caseSensitive: false,
  );

  static bool containsBlockedContent(String text) {
    return text.trim().isNotEmpty && _blockedPattern.hasMatch(text);
  }

  static bool shouldRefuseUserRequest(String text) {
    final value = text.trim();
    if (value.isEmpty) return false;
    if (containsBlockedContent(value)) return true;
    return _sexualTopicPattern.hasMatch(value) &&
        _generationVerbPattern.hasMatch(value);
  }
}
