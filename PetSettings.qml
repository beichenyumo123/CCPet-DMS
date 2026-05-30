import QtQuick
import Quickshell
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "dmsPet"

    StringSetting {
        settingKey: "petName"
        label: "Pet Name"
        description: "Give your desktop pet a name"
        defaultValue: "Clawdy"
    }

    SliderSetting {
        settingKey: "petScale"
        label: "Pet Size"
        description: "How large the pet appears in the DankBar"
        defaultValue: 100
        minimum: 50
        maximum: 150
        unit: "%"
    }

    SliderSetting {
        settingKey: "animSpeed"
        label: "Animation Speed"
        description: "How fast the pet's animations play"
        defaultValue: 100
        minimum: 50
        maximum: 200
        unit: "%"
    }

    ToggleSetting {
        settingKey: "useThemeColor"
        label: "Use Theme Color"
        description: "Pet adapts to your Material You theme"
        defaultValue: true
    }

    ColorSetting {
        settingKey: "petColor"
        label: "Custom Pet Color"
        description: "Only applies when 'Use Theme Color' is off"
        defaultValue: "#7C9CBF"
    }

    ToggleSetting {
        settingKey: "showStateIndicator"
        label: "Show State Emoji"
        description: "Display emoji above pet showing current state"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "showPetName"
        label: "Show Pet Name"
        description: "Display the pet's name next to it in the bar"
        defaultValue: false
    }
}
