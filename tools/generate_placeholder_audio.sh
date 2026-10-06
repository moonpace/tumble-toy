#!/usr/bin/env bash
set -euo pipefail

mkdir -p assets/audio/sfx assets/audio/music assets/audio/voice

tone() {
  local output="$1" frequency="$2" duration="$3"
  ffmpeg -y -f lavfi -i "sine=frequency=${frequency}:sample_rate=44100:duration=${duration}" \
    -af "volume=0.16,afade=t=in:st=0:d=0.01,afade=t=out:st=0.12:d=0.08" \
    -ac 1 -ar 44100 -c:a pcm_s16le "$output" -loglevel error
}

tone assets/audio/sfx/dice_roll.wav 420 0.35
tone assets/audio/sfx/dice_land.wav 600 0.25
tone assets/audio/sfx/blocked.wav 180 0.45
tone assets/audio/sfx/undo.wav 720 0.40
tone assets/audio/sfx/clear.wav 880 1.00
tone assets/audio/sfx/perfect_clear.wav 1040 1.10

ffmpeg -y -f lavfi -i "sine=frequency=261.63:sample_rate=44100:duration=75" \
  -f lavfi -i "sine=frequency=329.63:sample_rate=44100:duration=75" \
  -filter_complex "[0:a]volume=0.30[a];[1:a]volume=0.22[b];[a][b]amix=inputs=2,volume=8" \
  -ac 2 -ar 44100 -c:a vorbis -strict -2 assets/audio/music/puzzle_loop.ogg -loglevel error
ffmpeg -y -f lavfi -i "sine=frequency=783.99:sample_rate=44100:duration=5" \
  -f lavfi -i "sine=frequency=1046.50:sample_rate=44100:duration=5" \
  -filter_complex "[0:a]volume=0.35[a];[1:a]volume=0.24[b];[a][b]amix=inputs=2,volume=4" \
  -ac 2 -ar 44100 -c:a vorbis -strict -2 assets/audio/music/clear_jingle.ogg -loglevel error

voice() {
  local output="$1" text="$2" temp_file
  temp_file="${output%.wav}.aiff"
  say -v Yuna -r 175 -o "$temp_file" "$text"
  ffmpeg -y -i "$temp_file" -ac 1 -ar 44100 -c:a pcm_s16le "$output" -loglevel error
  rm -f "$temp_file"
}

voice assets/audio/voice/tutorial_move.wav "화면의 방향 화살표를 눌러 주사위를 굴려 보세요."
voice assets/audio/voice/tutorial_goal.wav "목표 숫자와 윗면 숫자가 같아야 해요."
voice assets/audio/voice/tutorial_safe.wav "블록 밖으로 가면 마지막 안전한 곳으로 돌아와요."
voice assets/audio/voice/tutorial_undo.wav "Undo 버튼을 누르면 한 칸 되돌릴 수 있어요."
voice assets/audio/voice/tutorial_par.wav "목표 이동 수 안에 풀면 완벽 클리어예요."
voice assets/audio/voice/tutorial_clear.wav "잘했어요! 다음 방으로 가 볼까요?"
