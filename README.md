# CmdV Paste Claude

A macOS menu bar app that automatically converts a clipboard image "image" into a "file".
This is a workaround to enable pasting images into Claude Code using Cmd+V.

Claude Code introduced a workaround a few months ago where images in the clipboard have to be pasted with Ctrl+V while Cmd+V continues to work for text and files. 

**I would very much rather use Cmd+V for everything.**

## How it works

When you copy an image (Cmd+C) or take a screenshot (Cmd+Shift+3/4/5), this app automatically:

1. Detects the image in your clipboard
2. Saves it as a PNG file in a temp directory
3. Replaces the clipboard contents with a file reference

This allows you to paste images directly into Claude Code using Cmd+V.

## Requirements

- macOS 13.0+
- Accessibility permissions (required to monitor keyboard events)

## Building

```bash
./build.sh
```

Then drag `CmdVPasteClaude.app` to `/Applications`.

