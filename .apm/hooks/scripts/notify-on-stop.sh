#!/bin/sh
# エージェントの応答完了時に通知音を鳴らす。音を出せない環境では何もせず終了する。
# OS ごとの再生方法と音源 (on-agent-complete.wav) は
# pascalporedda/awesome-claude-code (MIT License, Copyright (c) 2024 Pascal Weinberger) を元にしている。

sound="$1"

play_windows() {
  powershell.exe -NoProfile -Command "(New-Object Media.SoundPlayer '$1').PlaySync()"
}

play_sound() {
  case "$(uname -s)" in
    Darwin)
      afplay /System/Library/Sounds/Glass.aiff ;;
    MINGW* | MSYS* | CYGWIN*)
      play_windows "$(cygpath -w "$sound")" ;;
    Linux)
      if grep -qi microsoft /proc/version 2>/dev/null; then
        play_windows "$(wslpath -w "$sound")"
      else
        aplay -q "$sound" || paplay "$sound" || play "$sound"
      fi ;;
  esac
}

[ -f "$sound" ] || exit 0
# 再生を待たずに返して、エージェントを止めない
(play_sound >/dev/null 2>&1 &)
exit 0
