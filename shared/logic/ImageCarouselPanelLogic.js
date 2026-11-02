// Common behavior for variant-specific presentations.
.pragma library

function thumbUrlFor(riseOwner, riseEnvironment, img) {
    var riseState = riseOwner;

        if (!img || !img.thumbnailPath || img.thumbnailPath === img.filePath) return ""
        return "file://" + img.thumbnailPath
    }

function syncOpen(riseOwner, riseEnvironment) {
    var riseState = riseOwner;

        if (riseOwner.root.imagePickerVisible && riseState.active) {
            if (!riseState.imagesLoaded) {
                riseOwner.layoutSettled = false
                riseOwner.filterText    = ""
                riseOwner.imageArray    = []
                riseOwner.selFilt       = 0
                riseOwner.reveal        = 0
                riseEnvironment.currentProc.running = false; riseEnvironment.currentProc.running = true
            }
        } else {
            riseOwner.imagesLoaded  = false; riseOwner.scanDone = false
            riseOwner.layoutSettled = false
            riseOwner.reveal        = 0
        }
    }

function scanHasOriginalThumbs(riseOwner, riseEnvironment, text) {
    var riseState = riseOwner;

        var rows = String(text || "").split("\n")
        for (var i = 0; i < rows.length; i++) {
            var row = rows[i]
            if (!row) continue
            var cols = row.split("\t")
            if (cols.length < 2 || !cols[1] || cols[0] === cols[1]) return true
        }
        return false
    }

function applyScan(riseOwner, riseEnvironment, text, fromCache) {
    var riseState = riseOwner;

        var t = String(text || "")
        if (fromCache && !t.trim()) return   // cache empty → wait for live scan; live empty → fall through to empty-state
        if (fromCache && riseState.scanHasOriginalThumbs(t)) return
        if (fromCache && riseState.imagesLoaded) return
        if (!fromCache && t.trim() === riseState._lastScan.trim() && riseState.imagesLoaded) { riseOwner.warmVisible(); riseEnvironment.warmTimer.restart(); return }
        riseState._lastScan = t
        var images = riseEnvironment.Model.loadRows(t)
        riseOwner.imageArray   = images
        riseOwner.selFilt      = riseEnvironment.Model.indexForSelectedImage(images, riseOwner.currentImage)
        riseOwner.imagesLoaded = images.length > 0; riseOwner.scanDone = true
        riseEnvironment.Qt.callLater(function() {
            if (riseOwner.root.imagePickerVisible && riseOwner.active) {
                riseOwner.layoutSettled = true
                if (riseOwner.imageArray.length > 0) riseEnvironment.stage.forceActiveFocus()   // keep Esc-catcher focused when empty
                riseOwner.fetchMeta()
                if (!fromCache) { riseOwner.warmMeta(); riseOwner.warmVisible(); riseEnvironment.warmTimer.restart() }
            }
        })
    }

function buildScanCmd(riseOwner, riseEnvironment) {
    var riseState = riseOwner;

        if (riseState.isThemeMode) {
            return ["bash", "-c", [
                "shopt -s nullglob nocaseglob;",
                "CACHE=$HOME/.cache/quickshell-theme-picker; mkdir -p \"$CACHE\";",
                "D=$HOME/.cache/quickshell-img-thumbs; mkdir -p \"$D\";",
                "HASHCACHE=$HOME/.cache/quickshell-img-thumb-hashes.tsv; touch \"$HASHCACHE\";",
                "hash_for() { local s=\"$1\" r m key h tmp; r=$(readlink -f \"$s\" 2>/dev/null || printf '%s' \"$s\"); m=$(stat -Lc '%s:%Y:%Z' \"$s\" 2>/dev/null) || return 1; key=\"$r|$m\"; h=$(awk -F '\\t' -v k=\"$key\" '$1 == k { v=$2 } END { print v }' \"$HASHCACHE\" 2>/dev/null); if [ -z \"$h\" ]; then h=$(sha256sum \"$s\" 2>/dev/null | cut -d' ' -f1); [ -n \"$h\" ] || return 1; tmp=\"$HASHCACHE.$$\"; { awk -F '\\t' -v k=\"$key\" '$1 != k' \"$HASHCACHE\" 2>/dev/null; printf '%s\\t%s\\n' \"$key\" \"$h\"; } > \"$tmp\" && mv -f \"$tmp\" \"$HASHCACHE\"; fi; printf '%s' \"$h\"; };",
                "thumb_for() { local s=\"$1\" k; k=$(hash_for \"$s\") || return 1; printf '%s/%s-512.jpg' \"$D\" \"$k\"; };",
                "declare -A seen_themes=();",
                "for d in ~/.config/omarchy/themes/* " + riseOwner.shq(riseOwner.root.omarchyInstallRoot + "/themes") + "/* ~/.local/share/omarchy/themes/* /usr/share/omarchy/themes/*; do",
                "  [ -d \"$d\" ] || continue;",
                "  name=$(basename \"$d\");",
                "  [[ ${seen_themes[$name]+yes} ]] && continue;",
                "  prev=\"\";",
                "  for c in \"$d\"/preview.png \"$d\"/preview.jpg \"$d\"/preview.jpeg; do [ -f \"$c\" ] && { prev=\"$c\"; break; }; done;",
                "  if [ -z \"$prev\" ]; then bgs=(\"$d\"/backgrounds/*.jpg \"$d\"/backgrounds/*.jpeg \"$d\"/backgrounds/*.png \"$d\"/backgrounds/*.webp); prev=\"${bgs[0]}\"; fi;",
                "  [ -z \"$prev\" ] && continue;",
                "  seen_themes[$name]=1;",
                "  ext=\"${prev##*.}\"; link=\"$CACHE/$name.$ext\";",
                "  ln -sfn \"$prev\" \"$link\";",
                "  thumb=$(thumb_for \"$link\") || continue;",
                "  printf '%s\\t%s\\t%s\\n' \"$link\" \"$thumb\" \"$d\";",
                "done | sort -u"
            ].join(" ")]
        } else {
            return ["bash", "-c", [
                "D=$HOME/.cache/quickshell-img-thumbs; mkdir -p \"$D\";",
                "HASHCACHE=$HOME/.cache/quickshell-img-thumb-hashes.tsv; touch \"$HASHCACHE\";",
                "hash_for() { local s=\"$1\" r m key h tmp; r=$(readlink -f \"$s\" 2>/dev/null || printf '%s' \"$s\"); m=$(stat -Lc '%s:%Y:%Z' \"$s\" 2>/dev/null) || return 1; key=\"$r|$m\"; h=$(awk -F '\\t' -v k=\"$key\" '$1 == k { v=$2 } END { print v }' \"$HASHCACHE\" 2>/dev/null); if [ -z \"$h\" ]; then h=$(sha256sum \"$s\" 2>/dev/null | cut -d' ' -f1); [ -n \"$h\" ] || return 1; tmp=\"$HASHCACHE.$$\"; { awk -F '\\t' -v k=\"$key\" '$1 != k' \"$HASHCACHE\" 2>/dev/null; printf '%s\\t%s\\n' \"$key\" \"$h\"; } > \"$tmp\" && mv -f \"$tmp\" \"$HASHCACHE\"; fi; printf '%s' \"$h\"; };",
                "thumb_for() { local s=\"$1\" k; k=$(hash_for \"$s\") || return 1; printf '%s/%s-512.jpg' \"$D\" \"$k\"; };",
                "find -L " + riseState.wallpaperFindRoots() + " -xdev -maxdepth 32 -type f " +
                "\\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.bmp' -o -iname '*.gif' \\) " +
                "2>/dev/null | head -n 10000 | sort | while IFS= read -r f; do thumb=$(thumb_for \"$f\") || continue; printf '%s\\t%s\\n' \"$f\" \"$thumb\"; done"
            ].join(" ")]
        }
    }

function applySelected(riseOwner, riseEnvironment) {
    var riseState = riseOwner;

        if (!riseState.imagesLoaded || riseState.filtered.length === 0) return
        if (riseState.selFilt < 0 || riseState.selFilt >= riseState.filtered.length) return
        var path = riseState.filtered[riseState.selFilt].filePath; if (!path) return
        if (riseState.isThemeMode) {
            var name = riseEnvironment.Model.nameForPath(path)
            riseEnvironment.applyThemeProc.command = ["env", "OMARCHY_PATH=" + riseOwner.root.omarchyInstallRoot, "omarchy-theme-set", name]
            riseEnvironment.applyThemeProc.running = false; riseEnvironment.applyThemeProc.running = true
        } else if (riseOwner.root.wallpaperManagerFolder !== ""
                   && path.indexOf(riseOwner.root.wallpaperManagerFolder + "/") === 0) {
            riseOwner.root.pinWallpaper(path)
        } else {
            riseEnvironment.applyBgProc.command = ["bash", "-c", "omarchy-theme-bg-set '" + path.replace(/'/g, "'\\''") + "'"]
            riseEnvironment.applyBgProc.running = false; riseEnvironment.applyBgProc.running = true
        }
        riseOwner.root.imagePickerVisible = false
    }

function chooseWallpaperFolder(riseOwner, riseEnvironment) {
    var riseState = riseOwner;

        if (riseEnvironment.wallpaperFolderChooser.running) return
        riseEnvironment.wallpaperFolderChooser.selectedFolder = ""
        riseEnvironment.wallpaperFolderChooser.running = true
    }

function wallpaperFindRoots(riseOwner, riseEnvironment) {
    var riseState = riseOwner;

        var paths = riseOwner.root.wallpaperSourcePaths || []
        var args = []
        for (var i = 0; i < paths.length; i++)
            if (paths[i]) args.push(riseOwner.shq(paths[i]))
        return args.join(" ")
    }

function paletteReadCmd(riseOwner, riseEnvironment, pathExpr) {
    var riseState = riseOwner;

        return "awk -F'\"' 'function valid(v){ return v ~ /^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$/ } { k=$1; gsub(/[[:space:]=]/,\"\",k); if (valid($2)) c[k]=$2 } END { split(\"color1 red color2 green color3 yellow color4 blue color5 magenta color6 cyan\", a, \" \"); for (i=1; i<=6; i++) { p=a[i*2-1]; q=a[i*2]; v=c[p]; if (v == \"\") v=c[q]; if (v != \"\") { if (out != \"\") out=out \",\"; out=out v } } print out }' " + pathExpr + " 2>/dev/null"
    }

function noteThumbReady(riseOwner, riseEnvironment, line) {
    var riseState = riseOwner;

        var path = String(line || "").trim()
        if (!path) return
        riseOwner.readyThumbUrl = "file://" + path
        riseOwner.thumbEpoch++
    }

function warmCommand(riseOwner, riseEnvironment, srcs, niceLevel) {
    var riseState = riseOwner;

        var nice = niceLevel === 10 ? 10 : 19
        return ["bash", "-c",
            "D=$HOME/.cache/quickshell-img-thumbs; mkdir -p \"$D\"; command -v magick >/dev/null 2>&1 || exit 0; " +
            "HASHCACHE=$HOME/.cache/quickshell-img-thumb-hashes.tsv; touch \"$HASHCACHE\"; " +
            "tmp=$(mktemp); trap 'rm -f \"$tmp\"' EXIT; " +
            "hash_for() { local s=\"$1\" r m key h t; r=$(readlink -f \"$s\" 2>/dev/null || printf '%s' \"$s\"); m=$(stat -Lc '%s:%Y:%Z' \"$s\" 2>/dev/null) || return 1; key=\"$r|$m\"; h=$(awk -F '\\t' -v k=\"$key\" '$1 == k { v=$2 } END { print v }' \"$HASHCACHE\" 2>/dev/null); if [ -z \"$h\" ]; then h=$(sha256sum \"$s\" 2>/dev/null | cut -d' ' -f1); [ -n \"$h\" ] || return 1; t=\"$HASHCACHE.$$\"; { awk -F '\\t' -v k=\"$key\" '$1 != k' \"$HASHCACHE\" 2>/dev/null; printf '%s\\t%s\\n' \"$key\" \"$h\"; } > \"$t\" && mv -f \"$t\" \"$HASHCACHE\"; fi; printf '%s' \"$h\"; }; " +
            "for s in \"$@\"; do k=$(hash_for \"$s\") || continue; " +
            "o=\"$D/$k-512.jpg\"; [ -s \"$o\" ] && continue; printf '%s\\n%s\\n' \"$s\" \"$o\" >> \"$tmp\"; done; " +
            "if [ -s \"$tmp\" ]; then nice -n " + nice + " xargs -d '\\n' -P 3 -n 2 sh -c 'magick -define jpeg:size=1024x1024 \"$0[0]\" -auto-orient -strip -thumbnail 512x512^ -quality 82 \"$1\" >/dev/null 2>&1 || true; [ -s \"$1\" ] && printf \"%s\\n\" \"$1\"; exit 0' < \"$tmp\"; fi",
            "warm"].concat(srcs)
    }

function startWarm(riseOwner, riseEnvironment, proc, srcs, niceLevel) {
    var riseState = riseOwner;

        if (srcs.length === 0) return
        proc.command = riseOwner.warmCommand(srcs, niceLevel)
        proc.running = false; proc.running = true
    }

function visibleSourcePaths(riseOwner, riseEnvironment) {
    var riseState = riseOwner;

        var srcs = [], seen = {}
        for (var distance = 0; distance <= riseState.maxVisible; distance++) {
            var indices = distance === 0 ? [riseState.selFilt] : [riseState.selFilt - distance, riseState.selFilt + distance]
            for (var j = 0; j < indices.length; j++) {
                var i = indices[j]
                if (i < 0 || i >= riseState.filtered.length) continue
                var p = riseState.filtered[i].filePath
                if (p && !seen[p]) { seen[p] = true; srcs.push(p) }
            }
        }
        return srcs
    }

function backgroundSourcePaths(riseOwner, riseEnvironment) {
    var riseState = riseOwner;

        var visible = {}, priority = riseState.visibleSourcePaths(), srcs = [], seen = {}
        for (var i = 0; i < priority.length; i++) visible[priority[i]] = true
        for (var j = 0; j < riseState.imageArray.length; j++) {
            var p = riseState.imageArray[j].filePath
            if (p && !visible[p] && !seen[p]) { seen[p] = true; srcs.push(p) }
        }
        return srcs
    }

function fetchMeta(riseOwner, riseEnvironment) {
    var riseState = riseOwner;

        if (!riseState.isThemeMode || !riseState.sel || !riseState.sel.dir || riseState.metaCache[riseState.sel.dir]) return
        riseOwner._metaDir = riseState.sel.dir
        riseEnvironment.metaProc.command = ["bash", "-c",
            "d=" + riseState.shq(riseState.sel.dir) + "; repo=''; author='';" +
            "if [ -f \"$d/.git/config\" ]; then " +
            "  repo=$(sed -nE 's#^[[:space:]]*url = (.*)$#\\1#p' \"$d/.git/config\" | head -1);" +
            "  author=$(printf '%s' \"$repo\" | sed -nE 's#.*github\\.com[:/]+([^/]+)/.*#\\1#p');" +
            "fi;" +
            "pal=$(" + riseState.paletteReadCmd("\"$d/colors.toml\"") + ");" +
            "printf '%s\\t%s\\t%s\\n' \"$author\" \"$repo\" \"$pal\""]
        riseEnvironment.metaProc.running = false; riseEnvironment.metaProc.running = true
    }

function openRepo(riseOwner, riseEnvironment) {
    var riseState = riseOwner;

        if (!riseState.selMeta || !riseState.selMeta.repo) return
        var url = String(riseState.selMeta.repo)
            .replace(/^git@github\.com:/, "https://github.com/")
            .replace(/\.git$/, "")
        riseEnvironment.Quickshell.execDetached(["xdg-open", url])
    }

function warmMeta(riseOwner, riseEnvironment) {
    var riseState = riseOwner;

        if (!riseState.isThemeMode) return
        var dirs = []
        for (var i = 0; i < riseState.imageArray.length; i++)
            if (riseState.imageArray[i].dir) dirs.push(riseState.imageArray[i].dir)
        if (dirs.length === 0) return
        riseEnvironment.metaWarmProc.command = ["bash", "-c",
            "for d in \"$@\"; do repo=''; author='';" +
            "if [ -f \"$d/.git/config\" ]; then repo=$(sed -nE 's#^[[:space:]]*url = (.*)$#\\1#p' \"$d/.git/config\" | head -1);" +
            "author=$(printf '%s' \"$repo\" | sed -nE 's#.*github\\.com[:/]+([^/]+)/.*#\\1#p'); fi;" +
            "pal=$(" + riseState.paletteReadCmd("\"$d/colors.toml\"") + ");" +
            "printf '%s\\t%s\\t%s\\t%s\\n' \"$d\" \"$author\" \"$repo\" \"$pal\"; done",
            "warm"].concat(dirs)
        riseEnvironment.metaWarmProc.running = false; riseEnvironment.metaWarmProc.running = true
    }

function stripWidthFor(riseOwner, riseEnvironment, d) {
    var riseState = riseOwner;

        if (d <= 0) return riseState.focusedW
        if (d === 1) return riseState.peekW
        return riseState.stripW
    }
