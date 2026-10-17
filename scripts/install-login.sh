#!/bin/zsh
set -eu
cd "${0:A:h:h}"
app="$HOME/Applications/Headless Display.app"
agent="$HOME/Library/LaunchAgents/io.github.undivisible.headless-display.plist"
[[ -d 'build/Headless Display.app' ]] || { print -u2 'Build the app first.'; exit 1; }
[[ ! -e "$app" && ! -e "$agent" ]] || { print -u2 'An installation already exists. Quit and remove the old installation before reinstalling.'; exit 1; }
mkdir -p "$HOME/Applications" "$HOME/Library/LaunchAgents"
ditto 'build/Headless Display.app' "$app"
/usr/libexec/PlistBuddy -c 'Clear dict' "$agent"
/usr/libexec/PlistBuddy -c 'Add :Label string io.github.undivisible.headless-display' "$agent"
/usr/libexec/PlistBuddy -c 'Add :ProgramArguments array' "$agent"
/usr/libexec/PlistBuddy -c 'Add :ProgramArguments:0 string /usr/bin/open' "$agent"
/usr/libexec/PlistBuddy -c 'Add :ProgramArguments:1 string -a' "$agent"
/usr/libexec/PlistBuddy -c "Add :ProgramArguments:2 string $app" "$agent"
/usr/libexec/PlistBuddy -c 'Add :RunAtLoad bool true' "$agent"
launchctl bootstrap "gui/$(id -u)" "$agent"
print 'Installed. Enable Headless Display under Privacy & Security > Accessibility.'
