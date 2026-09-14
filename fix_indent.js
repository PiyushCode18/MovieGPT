const fs = require('fs');

const f = 'lib\\services\\ai_service.dart';
let text = fs.readFileSync(f, 'utf-8');

// Fix debugPrint indentation in complete() method (wrong indentation from earlier edits)
text = text.replace(
  /^[ \t]+debugPrint\('\[AI\] Not configured/,
  '      debugPrint(\'[AI] Not configured',
  'gm'
);
text = text.replace(
  /^[ \t]+debugPrint\('\[AI\] Empty history/,
  '      debugPrint(\'[AI] Empty history',
  'gm'
);

// Fix _createDio indentation (extra space)
text = text.replace('    static Dio _createDio() {', '  static Dio _createDio() {');

// Fix providerName @override indentation
text = text.replace('    @override\n  String get providerName {', '  @override\n  String get providerName {');

// Add request-start debug log before the switch statement
// Match: throw...empty history...} ... (with trailing space on blank line) ... switch
const oldSwitch = "    }\n \n    switch (provider) {";
const newSwitch = "    }\n\n    debugPrint(\n      '[AI] Request started: provider=$provider(${provider.name}), '\n      '${history.length} turns, ${tools.length} tools, '\n      '${EnvConfig.useAiBackend ? \"backend proxy\" : \"direct API\"}',\n    );\n\n    switch (provider) {";

if (text.includes(oldSwitch)) {
  text = text.replace(oldSwitch, newSwitch);
  console.log('Added request-start debug log');
} else {
  console.log('WARNING: Could not find switch pattern');
}

fs.writeFileSync(f, text, 'utf-8');
console.log('Done');
