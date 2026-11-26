#!/bin/bash
# PreToolUse (Bash): перед git commit напоминает текущую ветку. Не блокирует.
cmd=$(jq -r '.tool_input.command // empty')
printf '%s' "$cmd" | grep -qE '(^|[;&|[:space:]])git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+commit' || exit 0
cd "${CLAUDE_PROJECT_DIR:-$(dirname "$0")/../..}" || exit 0
b=$(git branch --show-current 2>/dev/null)
case "$b" in
  lexistream-dev) app="LexiStream" ;;
  main) app="WordLearner" ;;
  *) app="эксперимент (не lexistream-dev и не main)" ;;
esac
jq -n --arg b "$b" --arg a "$app" \
  '{systemMessage:("Коммит в ветку " + $b + " → " + $a),
    hookSpecificOutput:{hookEventName:"PreToolUse",
      additionalContext:("Напоминание о ветке: коммит пойдёт в «" + $b + "» (" + $a + "). Правило: LexiStream → lexistream-dev, WordLearner → main. Если работа для другого приложения — остановись и спроси пользователя.")}}'
exit 0
