/* Compositor picker page (packagechooserq@compositors). */
import io.calamares.core 1.0
import io.calamares.ui 1.0
import QtQuick

ZexosPicker {
    width: parent.width
    height: parent.height
    heading: "Compositors"
    subheading: "The compositor draws and arranges your windows. Tick one or more: you choose between them on the login screen."
    footnote: "Tick all three to try them all. The wallpaper changer and your colours work on each one."
    options: [
        { id: "niri",     name: "niri",     tag: "Scrolling tiling",
          text: "Windows sit side by side on an endless strip that you scroll through." },
        { id: "hyprland", name: "Hyprland", tag: "Dynamic tiling",
          text: "Smooth animations, rounded corners and lots of eye candy." },
        { id: "mango",    name: "Mango",    tag: "Tags, light and fast",
          text: "dwl-style tags instead of workspaces, with very low overhead." }
    ]
}
