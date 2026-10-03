/* Shell picker page (packagechooserq@shells). */
import io.calamares.core 1.0
import io.calamares.ui 1.0
import QtQuick

ZexosPicker {
    width: parent.width
    height: parent.height
    heading: "Desktop shell"
    subheading: "The shell is the bar, app launcher, control centre and notifications. Tick one or both."
    footnote: "With both, a button on the bar swaps them live. With one, that switch is left out."
    options: [
        { id: "noctalia", name: "Noctalia", tag: "Calm and minimal",
          text: "Floating islands on the bar, a quick launcher and a tidy control centre." },
        { id: "dms",      name: "DankMaterialShell", tag: "Material, feature-rich",
          text: "A full Material You desktop with widgets, a spotlight launcher and deep settings." }
    ]
}
