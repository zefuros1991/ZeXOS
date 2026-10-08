#!/usr/bin/env python3
"""ZeXOS - Welcome: the window, and the same jobs as terminal commands.

  zexos-welcome                    open the window
  zexos-welcome --autostart        open it at login (skipped if "Show at startup" is off)
  zexos-welcome <job> [--check]    run one job here, or only say what it would do
  zexos-welcome --help             this list

Jobs:
  update         update the system, then your Flathub apps
  rate-mirrors   find the fastest download servers
  leftovers      remove leftover packages
  clean          clean old package files (keeps the 3 newest of each)
  unlock         fix "pacman is locked"
  gaming         set up for gaming
  get-apps       open the app store
  whats-new      show what's new in this ZeXOS version
  about          show the ZeXOS version
  startup on|off show or don't show this window at login
"""
import os
import sys
import tempfile

HERE = os.path.dirname(os.path.realpath(__file__))
sys.path.insert(0, HERE)
from welcome import core  # noqa: E402

JOB_SCRIPT = os.path.join(HERE, "zexos-welcome-job")


def usage(code=0):
    print(__doc__.strip())
    return code


def run_job_here(job):
    """A job from a terminal: nothing to do -> say so; otherwise the same steps as the window's terminal."""
    kind, msg, _ = core.plan(job)
    if kind == "nothing":
        print(msg)
        return 0
    if kind == "stop":
        print(msg)
        return 3
    os.execv("/usr/bin/env", ["env", "bash", JOB_SCRIPT, job])


def main(argv):
    args = argv[1:]
    if not args:
        from welcome import ui
        return ui.run()
    a = args[0]
    if a in ("-h", "--help", "help"):
        return usage(0)
    if a == "--autostart":
        if not core.autostart_allowed():
            return 0
        from welcome import ui
        return ui.run()
    if a == "protected-file":  # internal: the leftover job hands this list to its admin part
        fd, path = tempfile.mkstemp(prefix="zexos-protected-", dir=core.RUNTIME if os.path.isdir(core.RUNTIME) else None)
        with os.fdopen(fd, "w") as fh:
            fh.write("\n".join(sorted(core.protected())) + "\n")
        os.chmod(path, 0o644)
        print(path)
        return 0
    if a not in core.JOBS:
        print(f"zexos-welcome: unknown job '{a}' (see zexos-welcome --help)", file=sys.stderr)
        return 2
    if a in core.ADMIN_JOBS:
        if "--check" in args[1:]:
            print(core.format_check(core.plan(a)))
            return 0
        return run_job_here(a)
    if a == "startup":
        if len(args) < 2 or args[1] not in ("on", "off"):
            print("usage: zexos-welcome startup on|off", file=sys.stderr)
            return 2
        core.set_startup(args[1] == "on")
        print("Show at startup: " + args[1])
        return 0
    if a == "about":
        v = core.version()
        print(f"ZeXOS {v}" if v else "ZeXOS (version unknown: the change notes are missing)")
        return 0
    if a == "whats-new":
        r = core.newest_release()
        if not r:
            print("What's new isn't available on this computer. Read it online: " + core.CHANGELOG_URL)
            return 0
        v, date, notes = r
        print(f"What's new in ZeXOS {v}" + (f" ({date})" if date else "") + "\n\n" + notes)
        return 0
    if a == "get-apps":
        cmd = core.app_store_cmd()
        if not cmd:
            print("No app store is installed.", file=sys.stderr)
            return 1
        os.execv(cmd[0] if os.path.isabs(cmd[0]) else "/usr/bin/env", cmd if os.path.isabs(cmd[0]) else ["env", *cmd])
    return usage(2)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
