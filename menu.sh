#!/usr/bin/env bash

function alternate_buffer {
    local state=$1
    case $state in
    off)
        echo -ne "\033[?1049l" ;;
    on)
        echo -ne "\033[?1049h" ;;
    esac
}

function build {
    configure
    gum spin --title Building -- \
    apktool build --force-all --use-aapt2 RetroRazr
    gum spin --title Signing -- \
    java -jar bin/uber-apk-signer.jar --apks RetroRazr/dist/*.apk --allowResign --overwrite
    mv RetroRazr/dist/*.apk .
    rm -rf RetroRazr/{build,dist}
}

function configure {
    [ -d RetroRazr ] && rm -rf RetroRazr
    7z x src/RetroRazr.zip &>/dev/null
    cp src/wallpaper/"$wallpaper".png RetroRazr/res/drawable/homescreen_wallpaper.png
    cp -r src/main/* src/skin/"$skin"/* RetroRazr
    if [ "$device_height" -ne 2640 ] ; then
        scale_factor=$(bc -l <<< "($device_height / 2640)")
        xmlstarlet ed -L -u "//dimen[contains(text(), 'px')]" \
        -x "concat(substring-before(., 'px') * $scale_factor, 'px')" \
        RetroRazr/res/values/dimens.xml
        xmlstarlet ed -L -u "//dimen[contains(@name, 'idle_main_border')]" \
        -x ". * $scale_factor" \
        RetroRazr/res/values/dimens.xml
    fi
    version=$(grep 'versionCode' RetroRazr/apktool.yml | awk -F"'" '{print $2}')
    case $option_mode in
    Default)
        sed -i "s/RetroRazr/RetroRazr\-$version\-${device_height}px/" \
        RetroRazr/apktool.yml ;;
    Custom)
        rm RetroRazr/res/drawable/center_soft_key_icon.xml
        cp -r src/res RetroRazr
        if [ "$shortcuts" = Invisible ] ; then
            sed -i 's/visible/invisible/' RetroRazr/res/layout/idle_main_fragment.xml
            sed -i 's/ff103184/00103184/' RetroRazr/res/values/colors.xml
        fi
        sed -i \
        "s/RetroRazr/RetroRazr\-$version\-$wallpaper\-$skin\-$shortcuts\-${device_height}px/" \
        RetroRazr/apktool.yml ;;
    esac
    sed -i "s#minSdkVersion: '33'#minSdkVersion: '30'#" RetroRazr/apktool.yml
    find RetroRazr -type f -exec sed -i \
    "s#com\.motorola\.retrorazr#com\.motorola\.retrorazr$version#g" {} +
    find RetroRazr -type f -exec sed -i \
    "s#com\/motorola\/retrorazr#com\/motorola\/retrorazr$version#g" {} +
    mv RetroRazr/smali/com/motorola/retrorazr RetroRazr/smali/com/motorola/retrorazr"$version"
}

function cursor {
    local state=$1
    case $state in
    off)
        echo -ne "\033[?25l" ;;
    on)
        echo -ne "\033[?25h" ;;
    zero)
        echo -ne "\033[0;0H" ;;
    esac
}

function customize_ui {
    case $option_menu in
    Wallpaper)
        wallpaper=$(gum choose --header Wallpaper --selected "$wallpaper" \
        Caribbean Food HigherPlane Moto Pacific Scarlet Silver) ;;
    Skin)
        skin=$(gum choose --header Skin --selected "$skin" \
        Moto Scarlet Silver) ;;
    esac
    refresh
    gum confirm "$(gum style "Save" --align center --width $COLUMNS --bold)" && menu
    customize_ui
}

function menu {
    case $option_mode in
    Default)
        option_menu=$(gum choose --header "Default menu" --selected "$option_menu" \
        Mode "Device height" Build Exit) ;;
    Custom)
        option_menu=$(gum choose --header "Custom menu" --selected "$option_menu" \
        Mode Wallpaper Skin Shortcuts "Device height" Build Exit) ;;
    esac
    case $option_menu in
    Mode)
        option_mode=$(gum choose --header Mode --selected "$option_mode" Default Custom)
        set_vars
        refresh
        menu ;;
    Wallpaper|Skin)
        customize_ui ;;
    Shortcuts)
        shortcuts=$(gum choose --header Shortcuts --selected "$shortcuts" Visible Invisible)
        menu ;;
    "Device height")
        device_height=$(gum input \
        --placeholder "$device_height" --char-limit 4 --header "Device height (px)")
        set_vars
        menu ;;
    Build)
        gum confirm "$(summary)" && build
        menu ;;
    Exit)
        alternate_buffer off
        clear
        exit ;;
    esac
}

function refresh {
    cursor off
    cursor zero
    ui
    cursor on
}

function set_vars {
    [ -z "$option_mode" ] && option_mode=Default
    case $option_mode in
    Default)
        wallpaper=Default
        skin=Default ;;
    Custom)
        [ "$wallpaper" = Default ] && wallpaper=Moto
        [ "$skin" = Default ] && skin=Moto ;;
    esac
    [ -z "$shortcuts" ] && shortcuts=Visible
    [[ $device_height =~ ^[0-9]{4}$ ]] || device_height=2640
}

function summary {
    gum style "$(gum join \
    "$(summary_keys)" "$(summary_values)" \
    --horizontal)" --align center --width $COLUMNS --bold
}

function summary_keys {
    case $option_mode in
    Default)
        gum style "$(printf "Device height: ")" --align left ;;
    Custom)
        gum style "$(printf \
        "Wallpaper: \nSkin: \nShortcuts: \nDevice height: ")" \
        --align left ;;
    esac
}

function summary_values {
    case $option_mode in
    Default)
        gum style "$(printf "%s" "${device_height}px")" --align right ;;
    Custom)
        gum style "$(printf "%s\n %s\n %s\n %s" \
        "$wallpaper" "$skin" "$shortcuts" "${device_height}px")" \
        --align right ;;
    esac
}

function title {
    gum style "RetroRazr launcher2" --align center --width $COLUMNS --bold
}

function ui {
    gum join "$(title)" "$(view)" --vertical
}

function view {
    gum style "$(gum style "$(timg -g${LINES}x$LINES \
    "src/wallpaper/$wallpaper.png" \
    "src/skin/$skin/res/drawable/softkey_normal_notext.png")" \
    --border rounded)" --align center --width $COLUMNS
}

color=#005eb8 # moto blue
export GUM_CHOOSE_CURSOR_FOREGROUND=$color
export GUM_CHOOSE_HEADER_FOREGROUND=$color
export GUM_CHOOSE_HEIGHT=7
export GUM_CHOOSE_SELECTED_FOREGROUND=$color
export GUM_CONFIRM_SELECTED_BACKGROUND=$color
export GUM_INPUT_CURSOR_FOREGROUND=$color
export GUM_INPUT_HEADER_FOREGROUND=$color
export GUM_SPIN_ALIGN=right
export GUM_SPIN_SPINNER=points
export GUM_SPIN_SPINNER_FOREGROUND=$color
alternate_buffer on
clear
set_vars
ui
menu
