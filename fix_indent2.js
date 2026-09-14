const fs = require('fs');

const f = 'lib\\services\\ai_service.dart';
let lines = fs.readFileSync(f, 'utf-8').split('\n');

let changed = false;

for (let i = 0; i < lines.length; i++) {
  const line = lines[i];

  // Fix debugPrint 'Not configured' line - extract the debugPrint(...) part and re-indent
  if (line.includes("debugPrint('[AI] Not configured")) {
    const match = line.match(/debugPrint\('(\[AI\] Not configured.*)\);$/);
    if (match) {
      lines[i] = '      debugPrint(\'' + match[1] + '\');';
      console.log('Fixed line ' + (i + 1) + ': Not configured -> re-indented');
      changed = true;
    }
  }

  // Fix debugPrint 'Empty history' line
  if (line.includes("debugPrint('[AI] Empty history")) {
    const match = line.match(/debugPrint\('(\[AI\] Empty history.*)\);$/);
    if (match) {
      lines[i] = '      debugPrint(\'' + match[1] + '\');';
      console.log('Fixed line ' + (i + 1) + ': Empty history -> re-indented');
      changed = true;
    }
  }

  // Fix trailing space on blank line before switch (line 275)
  if (line === ' ' && i > 0 && i < lines.length - 1) {
    if (lines[i - 1].trim().endsWith('}') && lines[i + 1].trim() === 'switch (provider) {') {
      lines[i] = '';
      console.log('Fixed trailing space on line ' + (i + 1));
      changed = true;
    }
  }

  // Add request-start debug log before the switch statement
  if (line.trim() === 'switch (provider) {' && lines[i - 1].trim() === '') {
    // Check if there's already a debugPrint before the switch
    let hasLog = false;
    for (let j = i - 1; j >= Math.max(0, i - 6); j--) {
      if (lines[j].includes('[AI] Request started')) {
        hasLog = true;
        break;
      }
    }
    if (!hasLog) {
      lines.splice(i, 0, '');
      lines.splice(i, 0, "    debugPrint(");
      lines.splice(i, 0, "      '[AI] Request started: provider=$provider(${provider.name}), '");
      lines.splice(i, 0, "      '${history.length} turns, ${tools.length} tools, '");
      lines.splice(i, 0, "      '${EnvConfig.useAiBackend ? \"backend proxy\" : \"direct API\"}',");
      lines.splice(i, 0, '    );');
      i += 6;
      console.log('Added request-start debug log before switch');
      changed = true;
    }
  }
}

if (changed) {
  fs.writeFileSync(f, lines.join('\n'), 'utf-8');
  console.log('File saved');
} else {
  console.log('No changes needed');
}
