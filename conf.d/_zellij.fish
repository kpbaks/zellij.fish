# NOTE: <kpbaks 2023-08-26 00:24:13> `__zellij.fish::` is used as a namespace prefix for all functions in this file
# to avoid name collisions and to be "hidden" from the user. That is, it seems very improbable that a user would
# have any other function or program on their system with the same prefix, leading to some annoyance
# when tab completing function names in interactive mode.
function __zellij.fish::check_dependencies
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

function __zellij.fish::on::install --on-event zellij_install
    # Set universal variables, create bindings, and other initialization logic.
    __zellij.fish::check_dependencies
end

function __zellij.fish::on::update --on-event zellij_update
    # Migrate resources, print warnings, and other update logic.
    # echo
end

function __zellij.fish::on::uninstall --on-event zellij_uninstall
    # Erase "private" functions, variables, bindings, and other uninstall logic.
    for f in (functions --all)
        if string match --regex --quiet -- "^__zellij.fish::" $f
            functions --erase $f
        end
    end

    # set | while read var val
    #     if string match --regex -- "^ZELLIJ_FISH_" $var
    #         set --erase $var
    #     end
    # end
end

# abbreviations
function abbr_zellij
    set -l expansion zellij
    set -l zellij_layout_files_in_cwd
    for f in *
        test -f $f; or continue
        set -l ext (path extension $f)
        test $ext = ".kdl"; or continue
        string match --quiet --regex "^layout\s+\{" <$f; or continue
        set --append zellij_layout_files_in_cwd $f
    end

    if set --query ZELLIJ
        if test (count $zellij_layout_files_in_cwd) -gt 0
            set --append expansion "%# action new-tab --layout $zellij_layout_files_in_cwd[1]"
        end
    else
        if test (count $zellij_layout_files_in_cwd) -gt 0
            set --append expansion "%# --layout $zellij_layout_files_in_cwd[1]"
        end
    end

    if test (count $zellij_layout_files_in_cwd) -gt 1
        set --append expansion "# also found: $(string join ', ' $zellij_layout_files_in_cwd[2..])"
    end

    echo $expansion
end

function __zellij.fish::abbr::list -d "list all abbreviations in zellij.fish"
    string match --regex "^abbr -a.*" <(status filename) | fish_indent --ansi
end

abbr -a zj --set-cursor --function abbr_zellij
abbr -a za zellij action
abbr -a ze zellij edit
abbr -a zef zellij edit --floating
abbr -a zr zellij run --
abbr -a zrf zellij run --floating --

status is-interactive; or return 0
set --query ZELLIJ; or return 0 # don't do anything if not inside zellij
__zellij.fish::check_dependencies; or return 0

# NOTE: <kpbaks 2023-08-26 00:14:41> Use ZELLIJ_FISH as a namespace prefix for all variables to avoid name collisions.
set --query ZELLIJ_FISH_KEYMAP_OPEN_URL; or set --global ZELLIJ_FISH_KEYMAP_OPEN_URL \eo # \eo is alt+o
set --query ZELLIJ_FISH_KEYMAP_ADD_URL_AT_CURSOR; or set --global ZELLIJ_FISH_KEYMAP_ADD_URL_AT_CURSOR \ea # \ea is alt+a
set --query ZELLIJ_FISH_KEYMAP_COPY_URL_TO_CLIPBOARD; or set --global ZELLIJ_FISH_KEYMAP_COPY_URL_TO_CLIPBOARD \ec # \ec is alt+c
set --query ZELLIJ_FISH_USE_FULL_SCREEN; or set --global ZELLIJ_FISH_USE_FULL_SCREEN 0
set --query ZELLIJ_FISH_RENAME_TAB_TITLE; or set --global ZELLIJ_FISH_RENAME_TAB_TITLE 1
# set --query ZELLIJ_FISH_ADD_AT_CURSOR_DEFAULT_COMMAND_IF_COMMANDLINE_EMPTY
set --query ZELLIJ_FISH_DEFAULT_CMD_IF_COMMANDLINE_EMPTY_FOR_ADD_AT_CURSOR
or set --global ZELLIJ_FISH_DEFAULT_CMD_IF_COMMANDLINE_EMPTY_FOR_ADD_AT_CURSOR default
set --global ZELLIJ_FISH_TITLE "zellij.fish" # Used for notifications and the border label in fzf



function __zellij.fish::is_inside_zellij
    if not set --query ZELLIJ
        printf "%serror%s: %s\n" (set_color red) (set_color normal) "fish shell not inside zellij." >&2
        return 1
    end
    return 0
end

function __zellij.fish::get_default_download_cmd
    set -l candidates curl wget # aria2c
    for candidate in $candidates
        if command --query $candidate
            echo $candidate
            return 0
        end
    end

    printf "%s: None of the default download commands [ %s ] are installed!\n" (status function) (string join ", " $candidates) >&2
    return 1
end

function __zellij.fish::notify --argument-names msg urgency
    if not command --query notify-send
        printf "%s%s%s:%s%s%s %error:%s %s\n" \
            (set_color yellow) (status current-filename) (set_color normal) \
            (set_color blue) (status current-line-number) (set_color normal) \
            (set_color red) (set_color normal) \
            "notify-send not installed." >&2
        status stack-trace
        return 1
    end
    set -l argc (count $argv)
    if test $argc -ne 2
        set urgency low
    end

    set -l urgency_levels low normal critical
    if not contains -- $urgency $urgency_levels
        set urgency low
    end
    set -l opts \
        --icon fish \
        --urgency $urgency \
        --expire-time=5000 \
        --app-name fish

    set -l errors (command notify-send $opts $ZELLIJ_FISH_TITLE $msg)

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
function __zellij.fish::update_tab_name --argument-names last_status
    set -l cwd (string replace --regex "^$HOME" "~" $PWD)
    set -l status_component (test $last_status -eq 0; and echo ""; or echo "($last_status)")

    set -l job_component ""
    set -l num_jobs (jobs | count)
    if test $num_jobs -gt 1
        set job_component "($num_jobs jobs)"
    else if test $num_jobs -eq 1
        jobs | read jobid group cpu state command
        set job_component "(job: $command)"
    end

    set -l title (printf "fish%s: %s %s" $status_component $cwd $job_component)
    if test $title = $__zellij_fish_previous_tab_title
        # Skip updating the tab name if it hasn't changed
        return 0
    end

    set --global __zellij_fish_previous_tab_title $title
    command zellij action rename-tab $title
end

if test $ZELLIJ_FISH_RENAME_TAB_TITLE -eq 1
    __zellij.fish::update_tab_name 0 # want to update the tab name when the shell starts

    function __zellij.fish::update_tab_name_on_postexec --on-event fish_postexec
        __zellij.fish::update_tab_name $status
    end

    # TODO: <kpbaks 2023-09-06 11:23:58> update the title with the command about to be executed $argv
    # function __zellij.fish::update_tab_title_on_preexec --on-event fish_preexec
    # 	set --global __zellij.fish_previous_tab_title ""
    # end
end

function __zellij.fish::get_visible_paths
    # __zellij.fish::is_inside_zellij; or return
    set -l tmpf (mktemp)

    set -l options
    # test $ZELLIJ_FISH_USE_FULL_SCREEN -eq 1; and set --append options --full
    command zellij action dump-screen $options $tmpf

    # A path is any string starting with
    # - "\b~/"
    # - "\b/"
    # - "\b./"
    set -l regexp "(\b[~.]?/\S+)"
    string match --regex --all --groups-only $regexp <$tmpf

    command rm $tmpf
end


function __zellij.fish::get_visible_http_urls
    __zellij.fish::is_inside_zellij; or return
    set -l tmpf (mktemp)

    set -l options
    test $ZELLIJ_FISH_USE_FULL_SCREEN -eq 1; and set --append options --full

    command zellij action dump-screen $options $tmpf
    # TODO: <kpbaks 2023-08-24 20:40:45> maybe strip out query params
    # NOTE: <kpbaks 2023-08-24 11:48:27> not perfect regex, but good enough
    set -l regexp "(https?://[^\s\"^]+)"
    string match --regex --all --groups-only $regexp <$tmpf
    command rm $tmpf
end

function __zellij.fish::fuzzy_select_visible_http_urls --argument-names prompt
    __zellij.fish::is_inside_zellij; or return

    set -l argc (count $argv)
    if test (count $argv) -eq 0
        set prompt " select with <tab>. "
    end

    # NOTE: "--color='gutter:-1'" is to get a transparent background
    set -l fzf_opts \
        --reverse \
        --border \
        --border-label=" $(string upper $ZELLIJ_FISH_TITLE) " \
        --height=~50% \
        --multi \
        --cycle \
        --ansi \
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

    set -l urls (__zellij.fish::get_visible_http_urls | sort --unique)
    if test (count $urls) -eq 0
        set -l msg "no urls found on screen."
        printf "%swarn:%s %s\n" (set_color yellow) (set_color normal) $msg
        __zellij.fish::notify $msg
        return 1
    end
    # TODO: colorize each url e.g. color the "https://" part
    printf "%s\n" $urls | fzf $fzf_opts
    return 0
end

function __zellij.fish::fuzzy_select_visible_http_urls_and_open_in_browser
    set -l prompt "select url(s) with <tab>. press <enter> to open them in the browser. "
    set -l selected_urls (__zellij.fish::fuzzy_select_visible_http_urls $prompt)
    test $status -eq 0; or return 1 # Happens if the there are no urls on the screen
    test (count $selected_urls) -gt 0; or return 10 # Happens if the user presses <esc> in fzf

    set -l open_cmd
    if command --query xdg-open
        set open_cmd xdg-open
    else if command --query open
        set open_cmd open
    else if command --query flatpak-xdg-open
        set open_cmd flatpak-xdg-open
    else
        set -l msg "open and xdg-open and flatpak-xdg-open not installed."
        printf "%serror:%s %s\n" (set_color red) (set_color normal) $msg >&2
        __zellij.fish::notify $msg
        printf "%s\n" $selected_urls
        return 1
    end

    for url in $selected_urls
        command $open_cmd $url
    end
end

function __zellij.fish::fuzzy_select_visible_http_urls_and_add_at_cursor
    set -l prompt "select url(s) with <tab>. press <enter> to add them at the cursor. "
    set -l selected_urls (__zellij.fish::fuzzy_select_visible_http_urls $prompt)
    test $status -eq 0; or return 1 # Happens if the there are no urls on the screen
    test (count $selected_urls) -gt 0; or return 10 # Happens if the user presses <esc> in fzf

    # Check if the commandline is not empty
    if test (commandline | string trim) != ""
        # If it, insert all urls separated by a space at the cursor
        # NOTE: A " " is appended to the end of the inserted text
        # to have the cursor not be directly after the last url.
        commandline --insert "$(string join " " $selected_urls) "
        return 0
    end

    # TODO: <kpbaks 2023-08-26 00:53:24> maybe do something special if only 1 url is selected
    set -l text_to_insert

    set -l default_cmd $ZELLIJ_FISH_DEFAULT_CMD_IF_COMMANDLINE_EMPTY_FOR_ADD_AT_CURSOR
    if test $ZELLIJ_FISH_DEFAULT_CMD_IF_COMMANDLINE_EMPTY_FOR_ADD_AT_CURSOR = default
        set default_cmd (__zellij.fish::get_default_download_cmd)
    end

    set -l command
    set -l options
    switch $default_cmd
        case curl
            # set -l options "-sSL -O"
            set -l options -sSL
            # set text_to_insert (string join " " command curl $options $selected_urls)
            set text_to_insert "command curl $options $selected_urls"
        case wget
            set -l options -qO-
            set text_to_insert "command wget $options $selected_urls"
        case '*'
            set -l msg "Unknown default command: $default_cmd"
            printf "%serror:%s %s\n" (set_color red) (set_color normal) $msg >&2
            __zellij.fish::notify $msg
            return 1
    end

    commandline --insert $text_to_insert
end

function __zellij.fish::fuzzy_select_visible_http_urls_and_copy_to_clipboard
    set -l prompt "select url(s) with <tab>. press <enter> to copy them to the clipboard. "
    set -l selected_urls (__zellij.fish::fuzzy_select_visible_http_urls $prompt)
    test $status -eq 0; or return 1 # Happens if the there are no urls on the screen
    test (count $selected_urls) -gt 0; or return 10 # Happens if the user presses <esc> in fzf

    printf "%s\n" $selected_urls | fish_clipboard_copy
    set -l msg (printf "Copied <b>%d</b> url%s to clipboard." (count $selected_urls) (test (count $selected_urls) -gt 1; and echo "s"; or echo ""))
    __zellij.fish::notify $msg
end

# TODO: <kpbaks 2023-08-26 00:16:39> Check if the keymap is already bound to something else. If it is print a warning.
# set -l mode zellij

bind --user $ZELLIJ_FISH_KEYMAP_OPEN_URL '__zellij.fish::fuzzy_select_visible_http_urls_and_open'_in_browser
bind --user $ZELLIJ_FISH_KEYMAP_ADD_URL_AT_CURSOR '__zellij.fish::fuzzy_select_visible_http_urls_and_add_at_cursor'
bind --user $ZELLIJ_FISH_KEYMAP_COPY_URL_TO_CLIPBOARD '__zellij.fish::fuzzy_select_visible_http_urls_and_copy_to_clipboard'

function __zellij.fish::fuzzy_select_visible_http_urls_and
    set -l actions open_url_in_browser append_at_cursor copy_to_clipboard
    set -l fzf_opts \
        --reverse \
        --border \
        --border-label=" $(string upper $ZELLIJ_FISH_TITLE) " \
        --height=~20% \
        --exit-0 \
        --header-first \
        --no-scrollbar \
        --pointer='|>' \
        --color='marker:#00ff00' \
        --color='border:#FFC143' \
        --color="gutter:-1" \
        --prompt="select which action to perform: "

    # TODO: somehow check if are any urls visible. If not print a warning
    set -l selected_action (printf "%s\n" $actions | fzf $fzf_opts)
    commandline --function repaint
    # TODO: if user presses <esc> then "go one menu back" instead of quitting totally
    # TODO: make return code 10 less brittle
    switch $selected_action
        case open_url_in_browser
            __zellij.fish::fuzzy_select_visible_http_urls_and_open_in_browser
            test $status -eq 10; and eval (status function)

        case append_at_cursor
            __zellij.fish::fuzzy_select_visible_http_urls_and_add_at_cursor
            test $status -eq 10; and eval (status function)

        case copy_to_clipboard
            __zellij.fish::fuzzy_select_visible_http_urls_and_copy_to_clipboard
            test $status -eq 10; and eval (status function)

        case '*'
            # User selected nothing
    end
end

bind --user \ez '__zellij.fish::fuzzy_select_visible_http_urls_and'
