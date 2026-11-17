#!/bin/sh
# Run by XcodeGen after generating Bifaz.xcodeproj (options.postGenCommand).
# Fixes two things XcodeGen 2.45 cannot express in project.yml:
#  1. The Icon Composer file type of AppIcon.icon (XcodeGen writes "wrapper.icon").
#  2. The project's known regions: String Catalogs have no .lproj folders, so
#     XcodeGen only lists Base and en. Bifaz ships en, es and fr.
# Fails loudly if either substitution stops matching a future XcodeGen output.
set -eu
PBX="Bifaz.xcodeproj/project.pbxproj"
sed -i '' 's/lastKnownFileType = wrapper.icon;/lastKnownFileType = folder.iconcomposer.icon;/' "$PBX"
perl -0pi -e 's/knownRegions = \(\s*Base,\s*en,\s*\);/knownRegions = (\n\t\t\t\tBase,\n\t\t\t\ten,\n\t\t\t\tes,\n\t\t\t\tfr,\n\t\t\t);/' "$PBX"
grep -q 'lastKnownFileType = folder.iconcomposer.icon;' "$PBX" || { echo "postgen: AppIcon.icon type not fixed" >&2; exit 1; }
grep -q '^[[:space:]]*fr,$' "$PBX" || { echo "postgen: knownRegions missing fr" >&2; exit 1; }
