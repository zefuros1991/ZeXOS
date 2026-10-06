/* Shown while ZeXOS installs: backdrops with a little about the system. */
import QtQuick
import calamares.slideshow 1.0

Presentation {
    id: presentation

    Timer {
        interval: 12000
        running: presentation.activatedInCalamares
        repeat: true
        onTriggered: presentation.goToNextSlide()
    }

    ZexosSlide {
        backdrop: "slides/1.jpg"
        title: "Welcome to ZeXOS"
        body: "A ready-made Wayland desktop on top of Arch Linux. Sit back: the base system, your compositors and your shell are being installed."
    }
    ZexosSlide {
        backdrop: "slides/2.jpg"
        title: "Three ways to tile"
        body: "niri scrolls your windows along an endless strip, Hyprland brings smooth animations and eye candy, and Mango keeps things light with dwl-style tags. Switch between them from the login screen."
    }
    ZexosSlide {
        backdrop: "slides/3.jpg"
        title: "Pick your shell"
        body: "Noctalia and DankMaterialShell give you the bar, launcher, control centre and notifications. With both installed, one click swaps them, live."
    }
    ZexosSlide {
        backdrop: "slides/4.jpg"
        title: "Colours that follow your wallpaper"
        body: "Change the wallpaper and the whole desktop follows: bar, borders, terminal, login screen. The wallpaper changer works the same on every compositor."
    }
    ZexosSlide {
        backdrop: "slides/5.jpg"
        title: "Plain Arch underneath"
        body: "The base system comes straight from Arch's own mirrors, so pacman and the Arch Wiki apply as usual. ZeXOS adds one small repo for its own apps. No AUR helper is preinstalled; add yay or paru if you want the AUR."
    }
    ZexosSlide {
        backdrop: "slides/6.jpg"
        title: "Almost there"
        body: "When the install finishes, restart, log in, and press Super+C for a terminal. Docs and help: github.com/zefuros1991/ZeXOS"
    }
}
