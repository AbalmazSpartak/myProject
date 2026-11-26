#!/bin/bash
# PreToolUse (Bash): перед git commit напоминает ветку. Сейчас в разработке только LexiStream (lexistream-dev);
# main (WordLearner) заморожен — коммит туда требует подтверждения пользователя.
cmd=$(jq -r '.tool_input.command // empty')
# Срабатывает только на настоящий вызов git commit: в начале команды или после ; && || | ( , с необязательными
# "cd …" / "git -C путь". Текст в кавычках или heredoc со словами «git commit» сюда не попадает.
printf '%s\n' "$cmd" | grep -qE '(^|[;&|(][[:space:]]*)git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+commit([[:space:]]|$)' || exit 0
cd "${CLAUDE_PROJECT_DIR:-$(dirname "$0")/../..}" || exit 0
b=$(git branch --show-current 2>/dev/null)
case "$b" in
  lexistream-dev)
    jq -n '{systemMessage:"Коммит в lexistream-dev (LexiStream)"}'
    ;;
  main)
    jq -n '{systemMessage:"Внимание: коммит в main — WordLearner заморожен",
      hookSpecificOutput:{hookEventName:"PreToolUse", permissionDecision:"ask",
        permissionDecisionReason:"Ветка main (WordLearner) заморожена: сейчас в разработке только LexiStream (lexistream-dev). Коммитить в main только по прямой просьбе пользователя."}}'
    ;;
  *)
    jq -n --arg b "$b" '{systemMessage:("Коммит в ветку " + $b + " (эксперимент)"),
      hookSpecificOutput:{hookEventName:"PreToolUse",
        additionalContext:("Коммит идёт в ветку «" + $b + "», а не в lexistream-dev. Это допустимо только для временного эксперимента — если нет, остановись и спроси пользователя.")}}'
    ;;
esac
exit 0
