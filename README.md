# CmdV Paste Claude

This is a workaround to bypass Claude Code's pasting images with Ctrl+V.

I want to paste everything, including images, with Cmd+V. 

The workaround works by having a macOS menu bar app that converts every __"image"__ in the clipboard into a __"file"__, which can be pasted freely with Cmd+V.

I created this workaround because I'm used to pasting with Cmd+V in every other app. I don't want to use a different shortcut for Claude Code.

# History

Sometime around October 2025, Claude Code introduced a workaround where images in the clipboard have to be pasted with Ctrl+V.
The reasoning I've found is "due to some restrictions from the terminal".
- https://github.com/anthropics/claude-code/issues/6712
- https://github.com/anthropics/claude-code/issues/7975
- https://github.com/anthropics/claude-code/issues/12407
- https://github.com/anthropics/claude-code/issues/1006

**I would very much rather use Cmd+V for everything.**

## How it works

When you copy an image (Cmd+C) or take a screenshot (Cmd+Shift+3/4/5), this app automatically:

1. Detects the image in your clipboard
2. Saves it as a PNG file in a temp directory
3. Replaces the clipboard contents with a file reference

## Requirements

- macOS 13.0+
- Accessibility permissions (required to detect clipboard changes)

## Building

```bash
./build.sh
```

Then drag `CmdVPasteClaude.app` to `/Applications`.

