#!/bin/bash
# PostToolUse (Edit|Write): после правки words.csv — проверка словаря и обновление existing_words.txt (правило из CLAUDE.md).
f=$(jq -r '.tool_input.file_path // .tool_response.filePath // empty')
case "$f" in
  */myProject/Resources/words.csv) ;;
  *) exit 0 ;;
esac
cd "${CLAUDE_PROJECT_DIR:-$(dirname "$0")/../..}" || exit 0
out=$(python3 scripts/validate_words.py 2>&1); code=$?
exp=$(python3 scripts/export_word_list.py 2>&1)
if [ $code -ne 0 ]; then
  jq -n --arg r "validate_words.py нашёл ошибки в words.csv — исправь их:
$out" '{decision:"block", reason:$r, systemMessage:"Словарь: есть ошибки, Claude исправляет"}'
else
  last=$(printf '%s\n' "$out" | tail -n 2 | tr '\n' ' ')
  jq -n --arg c "Хук словаря: validate_words.py без ошибок ($last); existing_words.txt обновлён ($exp)." \
    '{systemMessage:"Словарь проверен: ошибок нет, existing_words.txt обновлён", hookSpecificOutput:{hookEventName:"PostToolUse", additionalContext:$c}}'
fi
exit 0
