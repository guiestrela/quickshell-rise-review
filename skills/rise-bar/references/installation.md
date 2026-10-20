# Install Quickshell Rise

Use this procedure when the user requests installation of the Rise bar on Omarchy. It installs the bar, not the Codex skill. For an existing installation, inspect local modifications and the enabled plugin list before deciding whether installation or update is appropriate.

For a complete installation with one command, including fonts, `cava`, Rise,
AI usage collectors, the post-update recovery hook, and a shell restart, run:

```bash
omarchy pkg add ttf-jetbrains-mono-nerd ttf-material-symbols-variable cava && \
  omarchy plugin add https://github.com/guiestrela/quickshell-rise-review.git --enable && \
  "$HOME/.config/omarchy/plugins/io.github.guiestrela.quickshell-rise/scripts/install-ai-backends" \
    "$HOME/.config/omarchy/plugins/io.github.guiestrela.quickshell-rise" && \
  omarchy hook install post-update \
    "$HOME/.config/omarchy/plugins/io.github.guiestrela.quickshell-rise/contrib/post-boot.d/quickshell-rise" && \
  omarchy restart shell
```


Confirm the repository when Omarchy asks. The commands are joined with `&&`, so later steps run only after the preceding step succeeds. The last command restarts the Omarchy shell.

The plugin manager does not install fonts or run the legacy `install.sh`. Material Symbols Rounded prevents icon names from appearing as overlapping text. CAVA needs PipeWire support for the media waveform. The four collectors are installed with user systemd timers; provider authentication remains a separate setup step.

After installation:

```bash
omarchy plugin validate "$HOME/.config/omarchy/plugins/io.github.guiestrela.quickshell-rise"
omarchy plugin list
omarchy-shell shell ping
```

Use the installed checkout's `docs/integrations.md` for provider-specific dependencies and authentication. Do not request or print account tokens.
