import re

f = r'lib\services\ai_service.dart'
text = open(f, encoding='utf-8').read()

# Fix debugPrint indentation in complete() method
text = text.replace(
    "                  debugPrint('[AI] Not configured \u2014 no AI backend or API key available.');",
    "      debugPrint('[AI] Not configured \u2014 no AI backend or API key available.');"
)
text = text.replace(
    "            debugPrint('[AI] Empty history \u2014 cannot complete request.');",
    "      debugPrint('[AI] Empty history \u2014 cannot complete request.');"
)

# Fix _createDio indentation
text = text.replace(
    "    static Dio _createDio() {",
    "  static Dio _createDio() {"
)

# Fix providerName @override indentation  
text = text.replace(
    "    @override\n  String get providerName {",
    "  @override\n  String get providerName {"
)

# Add request-start debug log before the switch statement
old_switch = "    }\n \n    switch (provider) {"
new_switch = "    }\n\n    debugPrint(\n      '[AI] Request started: provider=$provider(${provider.name}), '\n      '${history.length} turns, ${tools.length} tools, '\n      '${EnvConfig.useAiBackend ? \"backend proxy\" : \"direct API\"}',\n    );\n\n    switch (provider) {"
text = text.replace(old_switch, new_switch)

open(f, 'w', encoding='utf-8').write(text)
print('Done - fixed indentation and added request-start log')
