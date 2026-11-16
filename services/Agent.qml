pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Chat with an AI agent from the bar: Claude (`claude -p`) or Codex (`codex exec`). Every
// conversation is kept and continued through the session id its tool reports. The agents may read
// files but not change them. Saved in ~/.local/share/quickshell/agent/chat.json.
Singleton {
    id: root

    // [{ id, backend, session, title, updated (ms), messages: [{ role, text, files }] }], newest first
    property var conversations: []
    // "" is a new chat that has no message yet
    property string currentId: ""
    // the tool a new chat starts with
    property string draftBackend: "claude"
    readonly property var current: conversations.find(c => c.id === currentId) ?? null
    readonly property string backend: current ? current.backend : draftBackend
    readonly property var messages: current ? current.messages : []
    property var available: []
    readonly property bool busy: proc.running
    // the conversation being answered, and its reply while it is written
    property string runningId: ""
    property string streamText: ""
    property string errorText: ""
    readonly property bool answeringHere: busy && runningId === currentId
    // what the agent is doing besides writing ("Reading a file")
    property string activity: ""
    // the commands each tool reports for itself (Claude lists them when a chat starts)
    property var toolCommands: ({
            "claude": [],
            "codex": []
        })
    // the models offered per tool; "" is the tool's own default. Codex's come from the list it keeps
    property var models: ({
            "claude": [
                {
                    "id": "",
                    "label": "Default",
                    "about": "What Claude Code is set to"
                },
                {
                    "id": "fable",
                    "label": "Fable",
                    "about": "Latest Fable"
                },
                {
                    "id": "opus",
                    "label": "Opus",
                    "about": "Latest Opus"
                },
                {
                    "id": "sonnet",
                    "label": "Sonnet",
                    "about": "Latest Sonnet"
                },
                {
                    "id": "haiku",
                    "label": "Haiku",
                    "about": "Latest Haiku, the fastest"
                }
            ],
            "codex": [
                {
                    "id": "",
                    "label": "Default",
                    "about": "What Codex is set to"
                }
            ]
        })
    // the model picked per tool
    property var chosen: ({
            "claude": "",
            "codex": ""
        })
    readonly property string model: chosen[backend] || ""
    readonly property string modelLabel: {
        const m = (models[backend] || []).find(m => m.id === model);
        return m ? m.label : model;
    }

    function pickModel(id) {
        const next = Object.assign({}, chosen);
        next[backend] = id;
        root.chosen = next;
        save();
    }

    // files waiting to go with the next message (paths)
    property var attachments: []
    readonly property string dataDir: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/quickshell/agent"
    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/quickshell/agent"
    readonly property var names: ({
            "claude": "Claude",
            "codex": "Codex"
        })
    // each tool's own icon in the icon theme, when it has one; the symbol is the fallback
    property var icons: ({
            "claude": Quickshell.iconPath("claude-desktop", true),
            "codex": Quickshell.iconPath("codex", true) || Quickshell.iconPath("chatgpt", true)
        })
    // an icon that is only a light outline (the ChatGPT knot of Papirus) is drawn on a dark tile
    property var outlined: []
    readonly property var symbols: ({
            "claude": "auto_awesome",
            "codex": "terminal"
        })

    function update(id, fields) {
        root.conversations = conversations.map(c => c.id === id ? Object.assign({}, c, fields) : c);
    }

    function push(id, role, text, files) {
        const c = conversations.find(c => c.id === id);
        if (c)
            update(id, {
                "updated": Date.now(),
                "messages": c.messages.concat([{
                        "role": role,
                        "text": text,
                        "files": files || []
                    }])
            });
    }

    // Markdown as the rich text Qt draws, with a lighter bold and smaller headings than Qt's own
    // Markdown view; `accent` colours links and code
    function toHtml(md, accent) {
        const esc = t => t.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
        const inline = t => esc(t)
            .replace(/`([^`]+)`/g, "<span style=\"font-family:monospace; color:" + accent + "\">$1</span>")
            .replace(/\*\*(.+?)\*\*/g, "<span style=\"font-weight:600\">$1</span>")
            .replace(/(^|[\s(])\*([^*\s][^*]*?)\*/g, "$1<i>$2</i>")
            .replace(/\[([^\]]+)\]\((https?:[^)\s]+)\)/g, "<a href=\"$2\" style=\"color:" + accent + "\">$1</a>");
        const out = [];
        let para = [];
        let code = null;
        const flush = () => {
            if (para.length > 0)
                out.push("<p style=\"margin:0 0 6px 0\">" + para.join("<br>") + "</p>");
            para = [];
        };
        for (const line of String(md).split("\n")) {
            if (/^\s*```/.test(line)) {
                if (code === null) {
                    flush();
                    code = [];
                } else {
                    out.push("<pre style=\"font-family:monospace; font-size:12px; margin:4px 0 8px 0\">" + esc(code.join("\n")) + "</pre>");
                    code = null;
                }
                continue;
            }
            if (code !== null) {
                code.push(line);
                continue;
            }
            const heading = /^(#{1,6})\s+(.*)$/.exec(line);
            const item = /^(\s*)([-*+]|\d+[.)])\s+(.*)$/.exec(line);
            if (heading) {
                flush();
                out.push("<p style=\"font-size:" + (heading[1].length <= 2 ? 16 : 15) + "px; font-weight:600; margin:6px 0 4px 0\">" + inline(heading[2]) + "</p>");
            } else if (item) {
                flush();
                const mark = /\d/.test(item[2]) ? item[2] : "•";
                out.push("<p style=\"margin:2px 0 2px " + (16 + Math.floor(item[1].length / 2) * 14) + "px; text-indent:-14px\">" + mark + "&nbsp;&nbsp;" + inline(item[3]) + "</p>");
            } else if (line.trim() === "") {
                flush();
            } else {
                para.push(inline(line));
            }
        }
        if (code !== null)
            out.push("<pre style=\"font-family:monospace; font-size:12px; margin:4px 0 8px 0\">" + esc(code.join("\n")) + "</pre>");
        flush();
        return out.join("");
    }

    function isImage(path) {
        return /\.(png|jpe?g|webp|gif|bmp)$/i.test(path);
    }

    function attach(path) {
        const p = decodeURIComponent(String(path).replace(/^file:\/\//, ""));
        if (p !== "" && attachments.indexOf(p) < 0)
            root.attachments = attachments.concat([p]);
    }

    function detach(path) {
        root.attachments = attachments.filter(a => a !== path);
    }

    // a picture on the clipboard becomes an attachment
    function pasteImage() {
        if (!pasteProc.running)
            pasteProc.running = true;
    }

    function send(text) {
        const files = attachments;
        const message = text.trim() !== "" ? text.trim() : (files.length > 0 ? "Describe what is attached." : "");
        if (message === "" || busy || available.indexOf(backend) < 0)
            return;
        if (!current) {
            const id = Date.now() + "-" + Math.floor(Math.random() * 1000);
            root.conversations = [{
                    "id": id,
                    "backend": draftBackend,
                    "session": "",
                    "title": message.replace(/\s+/g, " ").slice(0, 70),
                    "updated": Date.now(),
                    "messages": []
                }].concat(conversations);
            root.currentId = id;
        }
        const conv = current;
        push(conv.id, "user", message, files);
        // the conversation talked in last comes first
        root.conversations = [current].concat(conversations.filter(c => c.id !== conv.id));
        root.attachments = [];
        streamText = "";
        errorText = "";
        runningId = conv.id;
        // Claude reads the files itself; Codex takes pictures as arguments and reads the rest
        const listed = conv.backend === "claude" ? files : files.filter(f => !isImage(f));
        const prompt = listed.length > 0 ? message + "\n\nAttached files (read them before answering):\n" + listed.map(f => "- " + f).join("\n") : message;
        const pictures = files.filter(isImage).map(f => "--image=" + f);
        const picked = chosen[conv.backend] || "";
        if (conv.backend === "claude")
            proc.command = ["claude", "-p", "--output-format", "stream-json", "--verbose", "--include-partial-messages"].concat(picked !== "" ? ["--model", picked] : [], conv.session !== "" ? ["--resume", conv.session] : []);
        else if (conv.session !== "")
            proc.command = ["codex", "exec", "resume", "--json", "--skip-git-repo-check", "-c", "sandbox_mode=\"read-only\""].concat(picked !== "" ? ["-m", picked] : [], pictures, [conv.session, "-"]);
        else
            proc.command = ["codex", "exec", "--json", "--skip-git-repo-check", "-s", "read-only"].concat(picked !== "" ? ["-m", picked] : [], pictures, ["-"]);
        proc.backend = conv.backend;
        proc.message = prompt;
        proc.running = true;
    }

    function stop() {
        if (busy)
            proc.signal(15);
    }

    function newChat() {
        root.currentId = "";
        root.attachments = [];
    }

    function open(id) {
        root.currentId = id;
        root.attachments = [];
    }

    function remove(id) {
        if (busy && runningId === id)
            return;
        if (currentId === id)
            root.currentId = "";
        root.conversations = conversations.filter(c => c.id !== id);
        save();
    }

    // the tool of a chat is fixed once it has a message, so picking another one starts a new chat
    function pick(name) {
        if (name === backend)
            return;
        draftBackend = name;
        if (current)
            newChat();
        save();
    }

    // one line of the tool's output (a JSON event)
    function take(line) {
        let e;
        try {
            e = JSON.parse(line);
        } catch (err) {
            return;
        }
        if (proc.backend === "claude") {
            if (e.type === "system" && e.subtype === "init" && Array.isArray(e.slash_commands)) {
                toolCommands = Object.assign({}, toolCommands, {
                    "claude": e.slash_commands
                });
            } else if (e.type === "stream_event" && e.event && e.event.type === "content_block_start" && e.event.content_block && e.event.content_block.type === "tool_use") {
                activity = "Using " + e.event.content_block.name;
            } else if (e.type === "stream_event" && e.event && e.event.type === "content_block_delta" && e.event.delta && e.event.delta.type === "text_delta") {
                activity = "";
                streamText += e.event.delta.text;
            } else if (e.type === "stream_event" && e.event && e.event.type === "message_start" && streamText !== "") {
                // a second message of the same turn (after it used a tool)
                streamText += "\n\n";
            } else if (e.type === "result") {
                if (e.session_id)
                    update(runningId, {
                        "session": e.session_id
                    });
                if (e.is_error)
                    errorText = String(e.result || "The request failed");
                else if (streamText.trim() === "" && e.result)
                    streamText = String(e.result);
            }
        } else {
            if (e.type === "thread.started" && e.thread_id)
                update(runningId, {
                    "session": e.thread_id
                });
            else if (e.type === "item.started" && e.item && e.item.type !== "agent_message")
                activity = e.item.type === "command_execution" ? "Running a command" : "Working";
            else if (e.type === "item.completed" && e.item && e.item.type === "agent_message") {
                activity = "";
                streamText += (streamText !== "" ? "\n\n" : "") + e.item.text;
            }
            else if (e.type === "error" || e.type === "turn.failed")
                errorText = String(e.message || (e.error && e.error.message) || "The request failed");
        }
    }

    function finish(code) {
        const reply = streamText.trim();
        if (reply !== "")
            push(runningId, "assistant", reply);
        if (errorText !== "" || (reply === "" && code !== 0))
            push(runningId, "error", errorText !== "" ? errorText : (stderr.text.trim().split("\n").pop() || names[proc.backend] + " stopped without an answer"));
        streamText = "";
        activity = "";
        runningId = "";
        save();
    }

    function save() {
        file.setText(JSON.stringify({
            "draftBackend": draftBackend,
            "currentId": currentId,
            "chosen": chosen,
            "toolCommands": toolCommands,
            "conversations": conversations
        }));
    }

    function load(text) {
        try {
            const d = JSON.parse(text);
            if (Array.isArray(d.conversations)) {
                root.conversations = d.conversations;
                root.currentId = d.conversations.some(c => c.id === d.currentId) ? d.currentId : "";
            } else if (d.chats) {
                // the first format: one chat per tool
                const list = [];
                for (const name of ["claude", "codex"]) {
                    const c = d.chats[name];
                    if (c && c.messages && c.messages.length > 0)
                        list.push({
                            "id": name + "-first",
                            "backend": name,
                            "session": c.session || "",
                            "title": String(c.messages[0].text).replace(/\s+/g, " ").slice(0, 70),
                            "updated": Date.now(),
                            "messages": c.messages
                        });
                }
                root.conversations = list;
            }
            if (d.chosen && typeof d.chosen.claude === "string" && typeof d.chosen.codex === "string")
                root.chosen = d.chosen;
            if (d.toolCommands && Array.isArray(d.toolCommands.claude))
                root.toolCommands = d.toolCommands;
            if (d.draftBackend === "claude" || d.draftBackend === "codex")
                root.draftBackend = d.draftBackend;
        } catch (e) {}
    }

    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", root.dataDir])

    // which of the two tools are installed
    Process {
        command: ["sh", "-c", "for t in claude codex; do command -v $t >/dev/null 2>&1 && echo $t; done; "
            + "for f in /usr/share/icons/Papirus/24x24/panel/indicator-chatgpt.svg /usr/share/icons/Papirus/22x22/panel/indicator-chatgpt.svg; do [ -f $f ] && { echo icon:$f; break; }; done"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n").filter(t => t !== "");
                const knot = lines.find(l => l.startsWith("icon:"));
                if (knot && !root.icons.codex) {
                    root.icons = Object.assign({}, root.icons, {
                        "codex": "file://" + knot.substring(5)
                    });
                    root.outlined = ["codex"];
                }
                root.available = lines.filter(l => !l.startsWith("icon:"));
                if (root.available.length > 0 && root.available.indexOf(root.draftBackend) < 0)
                    root.draftBackend = root.available[0];
            }
        }
    }

    Process {
        id: pasteProc

        command: ["sh", "-c", "wl-paste -l 2>/dev/null | grep -qx image/png || exit 1; mkdir -p \"$1\" && f=\"$1/paste-$(date +%s%N).png\" && wl-paste -t image/png > \"$f\" && printf %s \"$f\"", "sh", root.cacheDir]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "")
                    root.attach(text.trim());
            }
        }
    }

    Process {
        id: proc

        property string message: ""
        property string backend: ""

        workingDirectory: Quickshell.env("HOME")
        // the message goes in by stdin: it can be long, and it is never part of a command line
        stdinEnabled: true
        onStarted: {
            write(message);
            stdinEnabled = false;
        }
        stdout: SplitParser {
            onRead: line => root.take(line)
        }
        stderr: StdioCollector {
            id: stderr
        }
        onExited: code => {
            root.finish(code);
            stdinEnabled = true;
        }
    }

    // Claude Code's own model list, with the names and versions its picker shows (newest cache file)
    Process {
        command: ["sh", "-c", "f=$(ls -t \"$HOME\"/.claude/cache/model-catalog/*-cc.json 2>/dev/null | head -1); [ -n \"$f\" ] && cat \"$f\""]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const catalog = JSON.parse(text).catalog;
                    const list = catalog.config.models;
                    const now = list.find(m => m.id === catalog.state.model);
                    const rows = [{
                            "id": "",
                            "label": "Default",
                            "about": now ? "Claude Code is set to " + now.name : "What Claude Code is set to"
                        }].concat(list.map(m => ({
                                "id": m.id,
                                "label": m.name,
                                "about": m.description || (m.section === "overflow" ? "Older model" : "")
                            })));
                    // a choice saved as an alias (fable, opus…) becomes the model it stands for
                    const targets = catalog.config.provider_alias_targets || {};
                    const picked = root.chosen.claude;
                    if (targets[picked] && targets[picked].default)
                        root.chosen = Object.assign({}, root.chosen, {
                            "claude": targets[picked].default
                        });
                    root.models = Object.assign({}, root.models, {
                        "claude": rows
                    });
                } catch (e) {}
            }
        }
    }

    // the models Codex knows, from its own cache (the ones it lists in its picker)
    FileView {
        path: Quickshell.env("HOME") + "/.codex/models_cache.json"
        onLoaded: {
            try {
                const listed = JSON.parse(text()).models.filter(m => m.visibility === "list").map(m => ({
                            "id": m.slug,
                            "label": m.display_name || m.slug,
                            "about": m.description || ""
                        }));
                root.models = Object.assign({}, root.models, {
                    "codex": [root.models.codex[0]].concat(listed)
                });
            } catch (e) {}
        }
    }

    FileView {
        id: file

        path: root.dataDir + "/chat.json"
        atomicWrites: true
        onLoaded: root.load(text())
    }
}
