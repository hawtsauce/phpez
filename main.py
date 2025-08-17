import tkinter as tk
from tkinter import scrolledtext, messagebox, Toplevel
import subprocess
import webbrowser

class Theme:
    """Encapsulates all styling for the application."""
    PRIMARY = "#212529"
    SUCCESS = "#343a40"
    BG = "#f8f9fa"
    CARD = "#ffffff"
    TEXT = "#212529"
    MUTED = "#6c757d"
    CONSOLE_BG = "#1a1a1a"
    CONSOLE_FG = "#e9ecef"
    
    FONT_FAMILY = "Arial"  # Changed from Arial to DejaVu Sans
    FONT_MONO = ("Consolas", 14, "bold")
    FONT_NORMAL = (FONT_FAMILY, 12)
    FONT_BOLD = (FONT_FAMILY, 12, "bold")
    FONT_H1 = (FONT_FAMILY, 38, "bold")
    FONT_H2 = (FONT_FAMILY, 15, "bold")
    
    SUCCESS_GREEN = "#00ff00"
    STOPPED_YELLOW = "#ffd700"
    ERROR_RED = "#ff4444"
    CONSOLE_CYAN = "#00ffff"

class SudoPasswordDialog(Toplevel):
    """A custom, modern dialog for asking for the sudo password."""
    def __init__(self, parent, command):
        super().__init__(parent)
        self.password = None
        self.title("Sudo Authentication")
        self.configure(bg=Theme.CARD)
        self.transient(parent)
        self.grab_set()

        # Center the dialog
        parent_x = parent.winfo_x()
        parent_y = parent.winfo_y()
        parent_w = parent.winfo_width()
        parent_h = parent.winfo_height()
        w, h = 400, 260  # Slightly increased height
        x = parent_x + (parent_w // 2) - (w // 2)
        y = parent_y + (parent_h // 2) - (h // 2)
        self.geometry(f"{w}x{h}+{x}+{y}")
        self.resizable(False, False)

        main_frame = tk.Frame(self, bg=Theme.CARD, padx=20, pady=20)
        main_frame.pack(fill="both", expand=True)

        tk.Label(main_frame, text="Authentication is required", font=Theme.FONT_BOLD, bg=Theme.CARD, fg=Theme.PRIMARY).pack(pady=(0, 5))
        tk.Label(main_frame, text="An application is attempting to perform an action that requires privileges:", 
                 wraplength=360, justify="center", bg=Theme.CARD, fg=Theme.MUTED).pack(pady=(0, 10))

        # Highlighted frame for the command
        command_frame = tk.Frame(main_frame, bg="#eee", padx=10, pady=5)
        command_frame.pack(fill="x", padx=10)
        tk.Label(command_frame, text=f"$ {command}", font=Theme.FONT_BOLD, bg="#eee", fg=Theme.PRIMARY, wraplength=340, justify="left").pack(fill="x")

        self.password_entry = tk.Entry(main_frame, show='*', font=Theme.FONT_NORMAL, bg="#eee", bd=0, relief="flat", insertbackground=Theme.PRIMARY)
        self.password_entry.pack(fill="x", ipady=5, padx=10, pady=(15, 0))
        self.password_entry.focus_set()
        self.password_entry.bind("<Return>", self._on_submit)

        # Button frame with grid layout for equal width
        btn_frame = tk.Frame(main_frame, bg=Theme.CARD)
        btn_frame.pack(fill="x", pady=(15, 0), padx=10)

        btn_cancel = ModernButton(btn_frame, "Cancel", self._on_cancel)
        btn_cancel.config(padx=0, pady=8, width=12)
        btn_cancel.grid(row=0, column=0, sticky="ew", padx=(0, 8))

        btn_submit = ModernButton(btn_frame, "Submit", self._on_submit)
        btn_submit.config(padx=0, pady=8, width=12)
        btn_submit.grid(row=0, column=1, sticky="ew", padx=(8, 0))

        btn_frame.grid_columnconfigure(0, weight=1)
        btn_frame.grid_columnconfigure(1, weight=1)

        self.protocol("WM_DELETE_WINDOW", self._on_cancel)

    def _on_submit(self, event=None):
        self.password = self.password_entry.get()
        self.destroy()

    def _on_cancel(self):
        self.password = None
        self.destroy()

    def get_password(self):
        self.wait_window()
        return self.password

class ModernFrame(tk.Frame):
    """A custom frame with consistent styling."""
    def __init__(self, parent, title="", **kwargs):
        super().__init__(parent, bg=Theme.CARD, padx=16, pady=16,
                         highlightbackground="#dee2e6", highlightthickness=1, **kwargs)
        if title:
            tk.Label(self, text=title, font=Theme.FONT_H2, fg=Theme.PRIMARY, bg=Theme.CARD).pack(anchor="w", pady=(0, 12))
        self.content = tk.Frame(self, bg=Theme.CARD)
        self.content.pack(fill="both", expand=True)

class ModernButton(tk.Button):
    """A custom button with consistent styling."""
    def __init__(self, parent, text, command, **kwargs):
        # New style: Light background with dark text and a border for visibility
        self.bg_color = "#f8f9fa"  # Light grey
        self.hover_color = "#e2e6ea" # Darker grey for hover/active
        self.text_color = Theme.PRIMARY # Black text

        super().__init__(parent, text=text, command=command, bg=self.bg_color, fg=self.text_color,
                         activebackground=self.hover_color, activeforeground=self.text_color,
                         bd=1, relief="solid", font=Theme.FONT_BOLD, cursor="hand2",
                         padx=20, pady=12, **kwargs)
        self.bind("<Enter>", lambda e: self.config(bg=self.hover_color))
        self.bind("<Leave>", lambda e: self.config(bg=self.bg_color))

class App(tk.Tk):
    """The main application class."""
    def __init__(self):
        super().__init__()
        self.sudo_password = None
        self._configure_window()
        self._create_widgets()
        self.update_status()

    def _configure_window(self):
        self.title("phpez")
        self.geometry("950x820")
        self.configure(bg=Theme.BG)
        self.grid_rowconfigure(1, weight=1)
        self.grid_columnconfigure(0, weight=1)
        self.protocol("WM_DELETE_WINDOW", self.on_close)

    def _create_widgets(self):
        # Top Bar
        top_bar = ModernFrame(self)
        top_bar.grid(row=0, column=0, sticky="ew", padx=24, pady=(16, 8))
        tk.Label(top_bar.content, text="phpez", font=Theme.FONT_H1, fg=Theme.PRIMARY, bg=Theme.CARD).pack(side="left")
        ModernButton(top_bar.content, "Website", lambda: self.open_url("https://phpez.wevory.com")).pack(side="right")

        # Main Content Frame
        main_content = tk.Frame(self, bg=Theme.BG)
        main_content.grid(row=1, column=0, sticky="nsew", padx=24, pady=8)
        main_content.grid_columnconfigure(1, weight=1) # Make console expand
        main_content.grid_rowconfigure(0, weight=1)

        # Left Panel for Controls
        controls_panel = tk.Frame(main_content, bg=Theme.BG)
        controls_panel.grid(row=0, column=0, sticky="ns", padx=(0, 8))

        # Control Frames
        self._create_control_frame(controls_panel, "Apache2", [
            ("Start", lambda: self.run_command("systemctl start apache2", "Apache2", "started")),
            ("Stop", lambda: self.run_command("systemctl stop apache2", "Apache2", "stopped")),
            ("Restart", lambda: self.run_command("systemctl restart apache2", "Apache2", "restarted")),
        ], buttons_per_row=3)
        self._create_control_frame(controls_panel, "MySQL", [
            ("Start", lambda: self.run_command("systemctl start mysql", "MySQL", "started")),
            ("Stop", lambda: self.run_command("systemctl stop mysql", "MySQL", "stopped")),
            ("Restart", lambda: self.run_command("systemctl restart mysql", "MySQL", "restarted")),
        ], buttons_per_row=3)
        self._create_control_frame(controls_panel, "Tools", [
            ("phpMyAdmin", self.open_phpmyadmin),
            ("Apache Config", lambda: self.open_directory("/etc/apache2/")),
            ("Public Folder", lambda: self.open_directory("/var/www/html/")),
            ("Open php.ini", self.open_php_ini),
            ("Clear Console", self.clear_console),
            ("Copy Console", self.copy_console),
            ("Localhost", lambda: self.open_url("http://localhost")),
        ], buttons_per_row=2)

        # Right Panel for Console
        console_frame = ModernFrame(main_content, "Console Output")
        console_frame.grid(row=0, column=1, sticky="nsew")
        console_frame.content.grid_rowconfigure(0, weight=1)
        console_frame.content.grid_columnconfigure(0, weight=1)
        self.console = scrolledtext.ScrolledText(console_frame.content, font=Theme.FONT_MONO, bg=Theme.CONSOLE_BG, fg=Theme.CONSOLE_FG,
                                                insertbackground=Theme.CONSOLE_FG, borderwidth=0, relief="flat", state="disabled", padx=12, pady=12)
        self.console.grid(row=0, column=0, sticky="nsew")
        self.console.tag_config("success", foreground=Theme.SUCCESS_GREEN)
        self.console.tag_config("stopped", foreground=Theme.STOPPED_YELLOW)
        self.console.tag_config("error", foreground=Theme.ERROR_RED)
        self.console.tag_config("info", foreground=Theme.CONSOLE_CYAN)
        self.log("Welcome to phpez!", "success")

        # Status Bar
        status_bar = ModernFrame(self)
        status_bar.grid(row=2, column=0, sticky="ew", padx=24, pady=(8, 16))
        self.status_label = tk.Label(status_bar.content, text="", font=Theme.FONT_BOLD, fg=Theme.PRIMARY, bg=Theme.CARD)
        self.status_label.pack(fill="x")

    def _create_control_frame(self, parent, title, buttons, buttons_per_row=1):
        frame = ModernFrame(parent, title)
        frame.pack(fill="x", pady=(0, 8))
        for i, (text, command) in enumerate(buttons):
            row, col = divmod(i, buttons_per_row)
            frame.content.grid_columnconfigure(col, weight=1)
            btn_container = tk.Frame(frame.content, bg=Theme.CARD)
            btn_container.grid(row=row, column=col, sticky="ew", padx=2, pady=2)
            ModernButton(btn_container, text, command).pack(fill="x")

    def run_command(self, cmd, service_name=None, action=None, sudo=True):
        self.log(f"$ {cmd}", "info")
        if sudo and self.sudo_password is None:
            self.ask_sudo_password(cmd)
            if self.sudo_password is None: 
                self.log("Sudo password entry cancelled. Command not executed.", "error")
                return
        
        try:
            command = (['sudo', '-S'] + cmd.split()) if sudo else cmd
            proc = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, 
                                    text=True, shell=(not sudo))
            stdout, stderr = proc.communicate(self.sudo_password + '\n' if sudo else None)

            if "incorrect password" in stderr.lower():
                self.log("❌ Incorrect sudo password.", "error")
                self.sudo_password = None
                return

            if proc.returncode == 0:
                if service_name and action:
                    tag = "success" if action in ["started", "restarted"] else "stopped"
                    self.log(f"✔ {service_name} {action}", tag)
                if stdout: self.log(stdout, "success")
            else:
                if stderr: self.log(stderr, "error")
        except Exception as e:
            self.log(f"Error: {e}", "error")

    def ask_sudo_password(self, command):
        dialog = SudoPasswordDialog(self, command)
        self.sudo_password = dialog.get_password()

    def update_status(self):
        apache = self.get_service_status("apache2")
        mysql = self.get_service_status("mysql")
        self.status_label.config(text=f"● Apache2: {apache}    ● MySQL: {mysql}")
        self.after(2000, self.update_status)

    def get_service_status(self, service):
        res = subprocess.run(f"systemctl is-active {service}", shell=True, capture_output=True, text=True)
        return "Running" if res.stdout.strip() == "active" else "Stopped"

    def log(self, message, tag=None):
        self.console.config(state="normal")
        self.console.insert(tk.END, message.strip() + "\n", tag)
        self.console.config(state="disabled")
        self.console.see(tk.END)

    def open_phpmyadmin(self):
        if subprocess.run("dpkg -l | grep phpmyadmin", shell=True, capture_output=True).returncode == 0:
            self.open_url("http://localhost/phpmyadmin")
        else:
            self.log("phpMyAdmin not found.", "error")

    def open_php_ini(self):
        self.log("Searching for php.ini...", "info")
        try:
            # Find the php.ini file for the Apache2 SAPI, which is most relevant
            cmd = "find /etc/php -name php.ini -path '*/apache2/*' -print -quit"
            proc = subprocess.run(cmd, shell=True, capture_output=True, text=True, check=True)
            path = proc.stdout.strip()
            if not path: # Fallback for CLI if apache2 one not found
                cmd = "find /etc/php -name php.ini -print -quit"
                proc = subprocess.run(cmd, shell=True, capture_output=True, text=True, check=True)
                path = proc.stdout.strip()

            if path:
                self.log(f"Found php.ini at: {path}", "success")
                subprocess.Popen(["xdg-open", path])
            else:
                self.log("Could not find php.ini file.", "error")
        except Exception as e:
            self.log(f"Error finding php.ini: {e}", "error")

    def open_directory(self, path):
        self.log(f"Opening: {path}", "info")
        subprocess.Popen(["xdg-open", path])

    def open_url(self, url):
        self.log(f"Opening: {url}", "info")
        webbrowser.open(url)

    def clear_console(self):
        self.console.config(state="normal")
        self.console.delete("1.0", tk.END)
        self.console.config(state="disabled")

    def copy_console(self):
        self.clipboard_clear()
        self.clipboard_append(self.console.get("1.0", tk.END))
        messagebox.showinfo("Copied", "Console output copied!")

    def on_close(self):
        if messagebox.askokcancel("Quit", "Do you want to quit?"):
            self.quit()

if __name__ == "__main__":
    App().mainloop()
