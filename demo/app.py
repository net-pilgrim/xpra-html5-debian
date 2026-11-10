#!/usr/bin/env python3
"""
Simple interactive demo GUI using Tkinter for Xpra HTML5 demonstration.
Includes quick launchers and diagnostics for VoltDB Management CLI and MinIO Client.
"""
import getpass
import os
import platform
import shutil
import subprocess
import sys
import time
import tkinter as tk
from tkinter import ttk, messagebox


class XpraDemoApp:
    def __init__(self, root: tk.Tk):
        self.root = root
        self.root.title("Xpra HTML5 Debian - VoltDB & MinIO Studio")
        self.root.geometry("580x560")
        self.root.minsize(500, 480)

        # State
        self.counter = 0

        # Style configuration
        self.style = ttk.Style()
        if "clam" in self.style.theme_names():
            self.style.theme_use("clam")

        self._build_ui()

    def _build_ui(self):
        container = ttk.Frame(self.root, padding=16)
        container.pack(fill=tk.BOTH, expand=True)

        # Header
        header = ttk.Label(
            container,
            text="🚀 Xpra HTML5 Desktop Environment",
            font=("Helvetica", 15, "bold"),
        )
        header.pack(pady=(0, 2))

        subtitle = ttk.Label(
            container,
            text="Debian 12 XFCE Desktop with VoltDB CLI & MinIO mc pre-installed",
            font=("Helvetica", 9),
        )
        subtitle.pack(pady=(0, 10))

        # CLI Launchers Section
        cli_frame = ttk.LabelFrame(container, text=" CLI Tools & Consoles ", padding=10)
        cli_frame.pack(fill=tk.X, pady=4)

        btn_voltadmin = ttk.Button(
            cli_frame,
            text="⚡ VoltDB Management (voltadmin)",
            command=self._launch_voltadmin,
        )
        btn_voltadmin.pack(side=tk.LEFT, expand=True, fill=tk.X, padx=3)

        btn_sqlcmd = ttk.Button(
            cli_frame,
            text="📊 VoltDB SQL (sqlcmd)",
            command=self._launch_sqlcmd,
        )
        btn_sqlcmd.pack(side=tk.LEFT, expand=True, fill=tk.X, padx=3)

        btn_mc = ttk.Button(
            cli_frame,
            text="🪣 MinIO Client (mc)",
            command=self._launch_mc,
        )
        btn_mc.pack(side=tk.LEFT, expand=True, fill=tk.X, padx=3)

        # Card 1: Interactive Counter
        counter_frame = ttk.LabelFrame(container, text=" Interactive Counter ", padding=8)
        counter_frame.pack(fill=tk.X, pady=4)

        self.counter_label = ttk.Label(
            counter_frame,
            text=f"Current Value: {self.counter}",
            font=("Helvetica", 11, "bold"),
        )
        self.counter_label.pack(side=tk.LEFT, padx=10)

        btn_dec = ttk.Button(counter_frame, text=" - ", width=4, command=self._decrement)
        btn_dec.pack(side=tk.RIGHT, padx=2)

        btn_inc = ttk.Button(counter_frame, text=" + ", width=4, command=self._increment)
        btn_inc.pack(side=tk.RIGHT, padx=2)

        btn_rst = ttk.Button(counter_frame, text="Reset", width=6, command=self._reset)
        btn_rst.pack(side=tk.RIGHT, padx=2)

        # Card 2: Text Echo
        text_frame = ttk.LabelFrame(container, text=" Keyboard & Text Input ", padding=8)
        text_frame.pack(fill=tk.X, pady=4)

        self.entry_var = tk.StringVar()
        self.entry_var.trace_add("write", self._on_text_change)
        entry = ttk.Entry(text_frame, textvariable=self.entry_var)
        entry.pack(fill=tk.X, pady=(2, 4))

        self.echo_label = ttk.Label(
            text_frame,
            text="Echo: (start typing above to test input latency...)",
            foreground="#555555",
            font=("Helvetica", 9, "italic"),
        )
        self.echo_label.pack(anchor=tk.W)

        # Card 3: Window & Actions
        actions_frame = ttk.LabelFrame(container, text=" Window & Terminal Actions ", padding=8)
        actions_frame.pack(fill=tk.X, pady=4)

        btn_term = ttk.Button(
            actions_frame,
            text="🖥️ Launch XFCE Terminal",
            command=self._launch_terminal,
        )
        btn_term.pack(side=tk.LEFT, expand=True, fill=tk.X, padx=3)

        btn_info = ttk.Button(
            actions_frame,
            text="ℹ️ Xpra Dialog Info",
            command=self._show_info,
        )
        btn_info.pack(side=tk.LEFT, expand=True, fill=tk.X, padx=3)

        # Diagnostics Panel
        diag_frame = ttk.LabelFrame(container, text=" Environment & CLI Status ", padding=8)
        diag_frame.pack(fill=tk.BOTH, expand=True, pady=4)

        volt_status = self._get_command_version(["voltadmin", "--version"])
        sqlcmd_status = "Available (/opt/voltdb/bin/sqlcmd)" if shutil.which("sqlcmd") else "Not found"
        mc_status = self._get_command_version(["mc", "--version"])
        oauth2_status = "Active (embedded proxy on port 14500)" if os.environ.get("OAUTH2_PROXY_UPSTREAMS") else ("Available (/usr/local/bin/oauth2-proxy)" if shutil.which("oauth2-proxy") else "Not found")

        info_text = (
            f"OS: Debian GNU/Linux ({platform.system()} {platform.machine()})\n"
            f"User: {getpass.getuser()} (UID: {os.getuid()}) | Display: {os.environ.get('DISPLAY', 'unknown')}\n"
            f"VoltDB CLI: {volt_status}\n"
            f"VoltDB SQL: {sqlcmd_status}\n"
            f"MinIO Client: {mc_status}\n"
            f"OAuth2-Proxy: {oauth2_status}\n"
            f"Server Time: {time.strftime('%Y-%m-%d %H:%M:%S')}"
        )
        diag_label = ttk.Label(diag_frame, text=info_text, font=("Monospace", 9), justify=tk.LEFT)
        diag_label.pack(anchor=tk.W)

    def _get_command_version(self, cmd_list):
        try:
            res = subprocess.run(cmd_list, capture_output=True, text=True, timeout=3)
            out = res.stdout.strip().split("\n")[0]
            return out if out else res.stderr.strip().split("\n")[0]
        except Exception:
            return "Not found / check PATH"

    def _launch_voltadmin(self):
        try:
            subprocess.Popen([
                "xfce4-terminal",
                "--title=VoltDB Management (voltadmin)",
                "-e", "bash -c 'echo \"=== VoltDB Management CLI (voltadmin) ===\"; voltadmin --help | head -n 30; echo \"\"; echo \"Tip: Run \\\"voltadmin <verb> --help\\\" for verb details.\"; exec bash'"
            ])
        except Exception as e:
            messagebox.showerror("Error", f"Failed to launch voltadmin terminal: {e}")

    def _launch_sqlcmd(self):
        try:
            subprocess.Popen([
                "xfce4-terminal",
                "--title=VoltDB SQL Console (sqlcmd)",
                "-e", "bash -c 'echo \"=== VoltDB Interactive SQL Console (sqlcmd) ===\"; sqlcmd --help | head -n 25; echo \"\"; echo \"Tip: Connect with: sqlcmd --servers=<host> --port=21212\"; exec bash'"
            ])
        except Exception as e:
            messagebox.showerror("Error", f"Failed to launch sqlcmd terminal: {e}")

    def _launch_mc(self):
        try:
            subprocess.Popen([
                "xfce4-terminal",
                "--title=MinIO Client (mc)",
                "-e", "bash -c 'echo \"=== MinIO Client CLI (mc) ===\"; mc --help | head -n 25; echo \"\"; echo \"Tip: Configure host with: mc alias set myminio https://minio.example.com ACCESS_KEY SECRET_KEY\"; exec bash'"
            ])
        except Exception as e:
            messagebox.showerror("Error", f"Failed to launch MinIO client terminal: {e}")

    def _increment(self):
        self.counter += 1
        self.counter_label.config(text=f"Current Value: {self.counter}")

    def _decrement(self):
        self.counter -= 1
        self.counter_label.config(text=f"Current Value: {self.counter}")

    def _reset(self):
        self.counter = 0
        self.counter_label.config(text=f"Current Value: {self.counter}")

    def _on_text_change(self, *args):
        val = self.entry_var.get()
        if val:
            self.echo_label.config(text=f"Echo: {val}", foreground="#000000")
        else:
            self.echo_label.config(text="Echo: (start typing above to test input latency...)", foreground="#555555")

    def _launch_terminal(self):
        try:
            cmd = "xfce4-terminal" if shutil.which("xfce4-terminal") else "xterm"
            subprocess.Popen([cmd])
        except Exception as e:
            messagebox.showerror("Error", f"Failed to launch terminal: {e}")

    def _show_info(self):
        messagebox.showinfo(
            "Xpra HTML5 Desktop",
            "This Debian XFCE desktop environment is streaming via WebSockets directly to HTML5.\n\n"
            "Pre-installed tools:\n"
            "• VoltDB Management CLI (voltadmin, sqlcmd, voltdb)\n"
            "• MinIO Client (mc / mcli)\n"
            "• XFCE4 Desktop Suite & Terminal",
        )


def main():
    root = tk.Tk()
    app = XpraDemoApp(root)
    root.mainloop()


if __name__ == "__main__":
    main()
