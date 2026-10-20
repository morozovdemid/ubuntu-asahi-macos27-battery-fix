#!/usr/bin/env bash
# Download exact Ubuntu Asahi kernel source, apply upstream macOS 27 SMC fix,
# and compile only the macsmc-power loadable kernel module.
set -Eeuo pipefail
# shellcheck source=scripts/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"

check_target
for cmd in wget tar patch make modinfo gcc; do need "$cmd"; done
[[ -d "/lib/modules/$KERNEL/build" ]] || \
    fail "Matching headers missing: sudo apt install linux-headers-$KERNEL"
[[ -f "$MODULE_ORIGINAL" ]] || fail "Expected packaged driver missing: $MODULE_ORIGINAL"

mkdir -p "$WORK_DIR" "$WORK_DIR/stage/drivers/power/supply"
archive="$WORK_DIR/$SOURCE_ARCHIVE"
patch_file="$WORK_DIR/$PATCH_COMMIT.patch"
stage="$WORK_DIR/stage/drivers/power/supply"

log "Downloading exact Ubuntu source ($SOURCE_ARCHIVE, approximately 254 MiB)..."
wget -c -O "$archive" "$SOURCE_URL"
log 'Downloading pinned upstream Linux commit patch...'
wget -O "$patch_file" "$PATCH_URL"
head -n 1 "$patch_file" | grep -Fq "From $PATCH_COMMIT " || \
    fail 'Downloaded patch does not match the expected upstream commit.'

log 'Extracting only the battery driver source...'
tar -xOzf "$archive" --wildcards '*/drivers/power/supply/macsmc-power.c' \
    > "$stage/macsmc-power.c"
[[ -s "$stage/macsmc-power.c" ]] || fail 'Source file extraction failed.'

log 'Checking patch compatibility (zero fuzz)...'
patch --batch --dry-run --fuzz=0 -p1 -d "$WORK_DIR/stage" < "$patch_file" || \
    fail 'Upstream patch does not apply cleanly. Do NOT force it.'
log 'Applying upstream patch to work tree (not the installed kernel)...'
patch --batch --fuzz=0 -p1 -d "$WORK_DIR/stage" < "$patch_file"
grep -Fq 'macsmc_swap_b0rm' "$stage/macsmc-power.c" || fail 'B0RM fix not found after patch.'
grep -Fq 'macsmc_battery_read_bcf0' "$stage/macsmc-power.c" || fail 'BCF0 fix not found after patch.'

printf 'obj-m += macsmc-power.o\n' > "$stage/Makefile"
log 'Compiling macsmc-power as an out-of-tree module...'
make -C "/lib/modules/$KERNEL/build" M="$stage" modules
check_built_module
log "Build successful: $MODULE_BUILT"
modinfo "$MODULE_BUILT" | grep -E '^(filename|depends|vermagic):'
log 'NOT installed. Next: ./scripts/install.sh (read README safety notes first).'
