# NOTE: <kpbaks 2023-08-26 00:24:13> `__zellij_fish::` is used as a namespace prefix for all functions in this file
# to avoid name collisions and to be "hidden" from the user. That is, it seems very improbable that a user would
# have any other function or program on their system with the same prefix, leading to some annoyance
# when tab completing function names in interactive mode.
function __zellij_fish::check_dependencies
    if not command --query zellij
        printf "%serror:%s %s\n" (set_color red) (set_color normal) "zellij (https://github.com/zellij-org/zellij) not installed." >&2
        return 1
    end
    if not command --query fzf
        printf "%serror:%s %s\n" (set_color red) (set_color normal) "fzf (https://github.com/junegunn/fzf) not installed." >&2
        return 1
    end

    return 0
end

function _zellij_install --on-event _zellij_install
    # Set universal variables, create bindings, and other initialization logic.
    __zellij_fish::check_dependencies; or return
end

function _zellij_update --on-event _zellij_update
    # Migrate resources, print warnings, and other update logic.
end

function _zellij_uninstall --on-event _zellij_uninstall
    # Erase "private" functions, variables, bindings, and other uninstall logic.
    for f in (functions --all)
        if string match --regex -- "^__zellij_fish::" $f
            functions --erase $f
        end
    end

    set | while read var val
        if string match --regex -- "^ZELLIJ_FISH_" $var
            set --erase $var
        end
    end
end

status is-interactive; or return
__zellij_fish::check_dependencies; or return
set --query ZELLIJ; or return # don't do anything if not inside zellij

# NOTE: <kpbaks 2023-08-26 00:14:41> Use ZELLIJ_FISH as a namespace prefix for all variables to avoid name collisions.
set --query ZELLIJ_FISH_KEYMAP_OPEN_URL; or set --global ZELLIJ_FISH_KEYMAP_OPEN_URL \eo # \eo is alt+o
set --query ZELLIJ_FISH_KEYMAP_ADD_URL_AT_CURSOR; or set --global ZELLIJ_FISH_KEYMAP_ADD_URL_AT_CURSOR \ea # \ea is alt+a
set --query ZELLIJ_FISH_KEYMAP_COPY_URL_TO_CLIPBOARD; or set --global ZELLIJ_FISH_KEYMAP_COPY_URL_TO_CLIPBOARD \ec # \ec is alt+c
set --query ZELLIJ_FISH_USE_FULL_SCREEN; or set --global ZELLIJ_FISH_USE_FULL_SCREEN 0
# set --query ZELLIJ_FISH_ADD_AT_CURSOR_DEFAULT_COMMAND_IF_COMMANDLINE_EMPTY
set --query ZELLIJ_FISH_DEFAULT_CMD_IF_COMMANDLINE_EMPTY_FOR_ADD_AT_CURSOR
or set --global ZELLIJ_FISH_DEFAULT_CMD_IF_COMMANDLINE_EMPTY_FOR_ADD_AT_CURSOR default
set --global ZELLIJ_FISH_TITLE "zellij.fish" # Used for notifications and the border label in fzf



function __zellij_fish::check_is_inside_zellij
    if not set --query ZELLIJ
        printf "%serror:%s %s\n" (set_color red) (set_color normal) "fish shell not inside zellij." >&2
        return 1
    end
    return 0
end

function __zellij_fish::get_default_download_cmd
    set --local candidates curl wget # aria2c
    for candidate in $candidates
        if command --query $candidate
            echo $candidate
            return 0
        end
    end

    printf "%s: None of the default download commands { %s } are installed!\n" (status current-function) (string join ", " $candidates) >&2
    return 1
end

function __zellij_fish::notify --argument-names msg urgency
    if not command --query notify-send
        printf "%s%s%s:%s%s%s %error:%s %s\n" \
            (set_color yellow) (status current-filename) (set_color normal) \
            (set_color blue) (status current-line-number) (set_color normal) \
            (set_color red) (set_color normal) \
            "notify-send not installed." >&2
        status stack-trace
        return 1
    end
    set --local argc (count $argv)
    if test $argc -ne 2
        set urgency low
    end

    set --local urgency_levels low normal critical
    if not contains -- $urgency $urgency_levels
        set urgency low
    end
    set --local opts \
        --icon fish \
        --urgency $urgency \
        --expire-time=5000 \
        --app-name fish

    set --local errors (command notify-send $opts $ZELLIJ_FISH_TITLE $msg)

    if test $status -ne 0
        printf "%s%s%s:%s%s%s %error:%s %s\n" \
            (set_color yellow) (status current-filename) (set_color normal) \
            (set_color blue) (status current-line-number) (set_color normal) \
            (set_color red) (set_color normal) \
            "notify-send failed with status $status." >&2
        status stack-trace
        return 1
    end
end

set --global __zellij_fish_previous_tab_title ""
function __zellij_fish::update_tab_name --argument-names last_status
    # command --query zellij; or return 1
    # set --query ZELLIJ; or return 0
    set --local cwd (string replace --regex "^$HOME" "~" $PWD)
    set --local status_component (test $last_status -eq 0; and echo ""; or echo "($last_status)")

    set --local job_component ""
    set --local num_jobs (jobs | count)
    if test $num_jobs -gt 1
        set job_component "($num_jobs jobs)"
    else if test $num_jobs -eq 1
        jobs | read jobid group cpu state command
        set job_component "(job: $command)"
    end

    set --local title (printf "fish%s: %s %s" $status_component $cwd $job_component)
    if test $title = $__zellij_fish_previous_tab_title
        # Skip updating the tab name if it hasn't changed
        return 0
    end

    set --global __zellij_fish_previous_tab_title $title
    command zellij action rename-tab $title
end

__zellij_fish::update_tab_name # want to update the tab name when the shell starts

function __zellij_fish::update_tab_name_on_postexec --on-event fish_postexec
    __zellij_fish::update_tab_name $status
end

# function __zellij_update_tab_name_when_cwd_changes --on-variable PWD
# 	__update_zellij_tab_name
# end

function __zellij_fish::get_visible_http_urls
    __zellij_fish::check_is_inside_zellij; or return
    set --local tmpf (mktemp)

    set --local options
    test $ZELLIJ_FISH_USE_FULL_SCREEN -eq 1; and set --append options --full

    command zellij action dump-screen $options $tmpf
    # TODO: <kpbaks 2023-08-24 20:40:45> maybe strip out query params
    # NOTE: <kpbaks 2023-08-24 11:48:27> not perfect regex, but good enough
    set --local regexp "(https?://[^\s\"^]+)"
    string match --regex --all --groups-only $regexp <$tmpf
    rm $tmpf
end

function __zellij_fish::fuzzy_select_among_visible_http_urls --argument-names prompt
    __zellij_fish::check_is_inside_zellij; or return

    set --local argc (count $argv)
    if test $argc -eq 0
        set prompt " select with <tab>. "
    end

    # NOTE: <kpbaks 2023-08-29 14:16:02> -1 is to get a transparent background
    set --local fzf_opts \
        --reverse \
        --border \
        --border-label=" $(string upper $ZELLIJ_FISH_TITLE) " \
        --height=~50% \
        --multi \
        --cycle \
        --scroll-off=5 \
        --select-1 \
        --no-scrollbar \
        --pointer='|>' \
        --marker='✓ ' \
        --color='marker:#00ff00' \
        --color='border:#FFC143' \
        --color="gutter:-1" \
        --no-mouse \
        --prompt=$prompt \
        --exit-0 \
        --header-first \
        --bind=ctrl-a:select-all

    set --local urls (__zellij_fish::get_visible_http_urls | sort --unique)
    if test (count $urls) -eq 0
        set --local msg "no urls found on screen."
        printf "%swarn:%s %s\n" (set_color yellow) (set_color normal) $msg
        __zellij_fish::notify $msg
        return 1
    end
    # NOTE: <kpbaks 2023-08-24 19:37:06> use `printf "%s\n" $urls` instead of `echo $urls` to ensure that each url is on a separate line
    printf "%s\n" $urls | fzf $fzf_opts
    return 0
end

function __zellij_fish::fuzzy_select_among_visible_http_urls_and_open
    set --local prompt " select url(s) with <tab>. press <enter> to open them in the browser. "
    set --local selected_urls (__zellij_fish::fuzzy_select_among_visible_http_urls $prompt)
    test $status -eq 0; or return 1 # Happens if the there are no urls on the screen
    test (count $selected_urls) -gt 0; or return 0 # Happens if the user presses <esc> in fzf

    set --local open_cmd
    if command --query xdg-open
        set open_cmd xdg-open
    else if command --query flatpak-xdg-open
        set open_cmd flatpak-xdg-open
    else
        set --local msg "xdg-open or flatpak-xdg-open not installed."
        printf "%serror:%s %s\n" (set_color red) (set_color normal) $msg >&2
        __zellij_fish::notify $msg
        printf "%s\n" $selected_urls
        return 1
    end

    for url in $selected_urls
        command $open_cmd $url
    end
end

function __zellij_fish::fuzzy_select_among_visible_http_urls_and_add_at_cursor
    set --local prompt " select url(s) with <tab>. press <enter> to add them at the cursor. "
    set --local selected_urls (__zellij_fish::fuzzy_select_among_visible_http_urls $prompt)
    test $status -eq 0; or return 1 # Happens if the there are no urls on the screen
    test (count $selected_urls) -gt 0; or return 0 # Happens if the user presses <esc> in fzf

    # Check if the commandline is not empty
    if test (commandline | string trim) != ""
        # If it, insert all urls separated by a space at the cursor
        # NOTE: A " " is appended to the end of the inserted text
        # to have the cursor not be directly after the last url.
        commandline --insert "$(string join " " $selected_urls) "
        return 0
    end

    # TODO: <kpbaks 2023-08-26 00:53:24> maybe do something special if only 1 url is selected
    set --local text_to_insert

    set --local default_cmd $ZELLIJ_FISH_DEFAULT_CMD_IF_COMMANDLINE_EMPTY_FOR_ADD_AT_CURSOR
    if test $ZELLIJ_FISH_DEFAULT_CMD_IF_COMMANDLINE_EMPTY_FOR_ADD_AT_CURSOR = default
        set default_cmd (__zellij_fish::get_default_download_cmd)
    end

    set --local command
    set --local options
    switch $default_cmd
        case curl
            # set --local options "-sSL -O"
            set --local options -sSL
            # set text_to_insert (string join " " command curl $options $selected_urls)
            set text_to_insert "command curl $options $selected_urls"
        case wget
            set --local options -qO-
            set text_to_insert "command wget $options $selected_urls"
        case '*'
            set --local msg "Unknown default command: $default_cmd"
            printf "%serror:%s %s\n" (set_color red) (set_color normal) $msg >&2
            __zellij_fish::notify $msg
            return 1
    end

    commandline --insert $text_to_insert
end

function __zellij_fish::fuzzy_select_among_visible_http_urls_and_copy_to_clipboard
    set --local prompt " select url(s) with <tab>. press <enter> to copy them to the clipboard. "
    set --local selected_urls (__zellij_fish::fuzzy_select_among_visible_http_urls $prompt)
    test $status -eq 0; or return 1 # Happens if the there are no urls on the screen
    test (count $selected_urls) -gt 0; or return 0 # Happens if the user presses <esc> in fzf

    printf "%s\n" $selected_urls | fish_clipboard_copy
    set --local msg (printf "Copied <b>%d</b> url%s to clipboard." (count $selected_urls) (test (count $selected_urls) -gt 1; and echo "s"; or echo ""))
    __zellij_fish::notify $msg
end

# TODO: <kpbaks 2023-08-26 00:16:39> Check if the keymap is already bound to something else. If it is print a warning.
# set --local mode zellij

bind --user $ZELLIJ_FISH_KEYMAP_OPEN_URL '__zellij_fish::fuzzy_select_among_visible_http_urls_and_open; commandline --function repaint'
bind --user $ZELLIJ_FISH_KEYMAP_ADD_URL_AT_CURSOR '__zellij_fish::fuzzy_select_among_visible_http_urls_and_add_at_cursor; commandline --function repaint'
bind --user $ZELLIJ_FISH_KEYMAP_COPY_URL_TO_CLIPBOARD '__zellij_fish::fuzzy_select_among_visible_http_urls_and_copy_to_clipboard; commandline --function repaint'
