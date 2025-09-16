#!/bin/bash

CHANNEL_DIR="$(dirname "$0")"
STATE_FILE="$CHANNEL_DIR/state.txt"
LOGO_ASS="$CHANNEL_DIR/logo.ass"
ADS_DIR="$CHANNEL_DIR/ads"
SCHEDULE_FILE="$CHANNEL_DIR/schedule.txt"  # Format: 10:00 PM-11:00 PM:'Attack On Titan'

# --- Create text-based logo ASS if not exists ---
if [ ! -f "$LOGO_ASS" ]; then
    cat > "$LOGO_ASS" <<EOF
[Script Info]
ScriptType: v4.00+
PlayResX: 1920
PlayResY: 1080
[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Default,Arial,48,&H00FFFFFF,&H000000FF,&H00000000,&H64000000,1,0,0,0,100,100,0,0,1,3,3,3,2,2,50,1
[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
Dialogue: 0,0:00:00.00,99:59:59.00,Default,,0,0,50,,Shadow TV
EOF
fi

# --- Determine current time ---
H=$(date +%I)
M=$(date +%M)
AMPM=$(date +%p)
H24=$(( H % 12 ))
[ "$AMPM" = "PM" ] && H24=$(( H24 + 12 ))
CURRENT_MIN=$(( H24*60 + M ))
CURRENT_TS=$(date +%s)

# --- Determine active anime folder based on schedule ---
ACTIVE_FOLDER=""
SCHEDULE_START_TS=0
if [ -f "$SCHEDULE_FILE" ]; then
    while IFS= read -r line; do
        [[ -z "$line" || "$line" =~ ^# ]] && continue

        if [[ $line =~ ^([0-9]{1,2}):([0-9]{2})\ ?([AP]M)-([0-9]{1,2}):([0-9]{2})\ ?([AP]M):\'(.+)\'$ ]]; then
            SH=${BASH_REMATCH[1]}
            SM=${BASH_REMATCH[2]}
            START_AMPM=${BASH_REMATCH[3]}
            EH=${BASH_REMATCH[4]}
            EM=${BASH_REMATCH[5]}
            END_AMPM=${BASH_REMATCH[6]}
            FOLDER_NAME=${BASH_REMATCH[7]}

            # Convert to 24h minutes
            SH24=$(( SH % 12 ))
            [ "$START_AMPM" = "PM" ] && SH24=$(( SH24 + 12 ))
            EH24=$(( EH % 12 ))
            [ "$END_AMPM" = "PM" ] && EH24=$(( EH24 + 12 ))

            TEMP_START=$(( SH24*60 + SM ))
            TEMP_END=$(( EH24*60 + EM ))

            IN_SCHEDULE=0
            if (( TEMP_END <= TEMP_START )); then
                (( CURRENT_MIN >= TEMP_START || CURRENT_MIN < TEMP_END )) && IN_SCHEDULE=1
            else
                (( CURRENT_MIN >= TEMP_START && CURRENT_MIN < TEMP_END )) && IN_SCHEDULE=1
            fi

            if (( IN_SCHEDULE )); then
                ACTIVE_FOLDER="$CHANNEL_DIR/$FOLDER_NAME"
                TODAY=$(date +%Y-%m-%d)
                SCHEDULE_START_TS=$(date -d "$TODAY $SH24:$SM" +%s)
                if (( TEMP_END <= TEMP_START && CURRENT_MIN < TEMP_END )); then
                    SCHEDULE_START_TS=$(( SCHEDULE_START_TS - 24*3600 ))
                fi
                break
            fi
        fi
    done < "$SCHEDULE_FILE"
fi

if [ -z "$ACTIVE_FOLDER" ]; then
    echo "No anime scheduled at this time."
    exit 0
fi

echo "Now playing: $ACTIVE_FOLDER"

# --- Find all videos in order ---
VIDEOS=()
while IFS= read -r -d $'\0' file; do
    VIDEOS+=("$file")
done < <(find "$ACTIVE_FOLDER" -maxdepth 1 -type f \( -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.avi" \) -print0 | sort -z -V)

# --- Pick a random ad ---
AD_PATH=""
if [ -d "$ADS_DIR" ] && [ $(ls -1 "$ADS_DIR" | wc -l) -gt 0 ]; then
    AD_FILE=$(ls "$ADS_DIR" | shuf -n1)
    AD_PATH="$ADS_DIR/$AD_FILE"
fi

# --- Determine elapsed time ---
SCHEDULE_ELAPSED=$(( CURRENT_TS - SCHEDULE_START_TS ))
if [ -f "$STATE_FILE" ] && [ -s "$STATE_FILE" ]; then
    STATE_ELAPSED=$(cat "$STATE_FILE")
else
    STATE_ELAPSED=0
fi

# Use the larger of schedule elapsed or saved state
ELAPSED=$(( SCHEDULE_ELAPSED > STATE_ELAPSED ? SCHEDULE_ELAPSED : STATE_ELAPSED ))

# --- Determine which video and seek position ---
CURRENT_FILE=""
SEEK=0
for VIDEO in "${VIDEOS[@]}"; do
    DURATION=$(ffprobe -v error -show_entries format=duration \
        -of default=noprint_wrappers=1:nokey=1 "$VIDEO")
    DURATION=${DURATION%.*}

    if (( ELAPSED >= DURATION )); then
        ELAPSED=$(( ELAPSED - DURATION ))
    else
        CURRENT_FILE="$VIDEO"
        SEEK=$ELAPSED
        break
    fi
done

[ -z "$CURRENT_FILE" ] && { CURRENT_FILE="${VIDEOS[0]}"; SEEK=0; }

# --- Build playlist ---
PLAYLIST=("$CURRENT_FILE")
FOUND=0
for VIDEO in "${VIDEOS[@]}"; do
    if [ "$VIDEO" == "$CURRENT_FILE" ]; then
        FOUND=1
        continue
    fi
    [ "$FOUND" -eq 1 ] && PLAYLIST+=("$VIDEO")
done
[ -n "$AD_PATH" ] && PLAYLIST+=("$AD_PATH")

# --- MPV options ---
WATCH_DIR="$CHANNEL_DIR/watch_later"
mkdir -p "$WATCH_DIR"

MPV_COMMON="--fullscreen --loop-playlist=inf \
--no-input-default-bindings --no-osd-bar --osd-level=0 \
--force-window=no --sub-files=$LOGO_ASS \
--no-resume-playback --watch-later-directory=$WATCH_DIR"

# --- Start MPV ---
if (( SEEK > 0 )); then
    mpv $MPV_COMMON --start="$SEEK" "${PLAYLIST[@]}"
else
    mpv $MPV_COMMON "${PLAYLIST[@]}"
fi

# --- Update state.txt ---
ELAPSED=$(( SEEK + $(date +%s) - CURRENT_TS ))
echo $ELAPSED > "$STATE_FILE"
echo "Channel position updated. Next run will resume correctly."
