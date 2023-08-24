function _zellij_install --on-event _zellij_install
    # Set universal variables, create bindings, and other initialization logic.
    if not command --query zellij
        printf "%serror:%s %s\n" (set_color red) (set_color normal) "zellij (https://github.com/zellij-org/zellij) not installed." >&2
        return
    end
    if not command --query fzf
        printf "%serror:%s %s\n" (set_color red) (set_color normal) "fzf (https://github.com/junegunn/fzf) not installed." >&2
        return
    end
end

function _zellij_update --on-event _zellij_update
    # Migrate resources, print warnings, and other update logic.
end

function _zellij_uninstall --on-event _zellij_uninstall
    # Erase "private" functions, variables, bindings, and other uninstall logic.
end

status is-interactive; or return


if not command --query zellij
    printf "%serror:%s %s\n" (set_color red) (set_color normal) "zellij (https://github.com/zellij-org/zellij) not installed." >&2
    return
end

if not command --query fzf
    printf "%serror:%s %s\n" (set_color red) (set_color normal) "fzf (https://github.com/junegunn/fzf) not installed." >&2
    return
end

set --query ZELLIJ; or return

function __zellij_update_tab_name
    command --query zellij; or return 1
    set --query ZELLIJ; or return 0
    set -l cwd (string replace --regex "^$HOME" "~" $PWD)
    set -l num_jobs (jobs | count)
    set -l title "fish: $cwd"
    if test $num_jobs -gt 1
        set title "$title ($num_jobs jobs)"
    else if test $num_jobs -eq 1
        jobs | read jobid group cpu state command
        set title "$title (job: $command)"
    end

    command zellij action rename-tab $title
end

__zellij_update_tab_name # want to update the tab name when the shell starts

function __zellij_update_tab_name_on_postexec --on-event fish_postexec
    __zellij_update_tab_name
end

# function __zellij_update_tab_name_when_cwd_changes --on-variable PWD
# 	__update_zellij_tab_name
# end

function __zellij_get_visible_http_urls
    if not set --query ZELLIJ
        printf "%serror:%s %s\n" (set_color red) (set_color normal) "fish shell not inside zellij."
        return 1
    end
    set --local tmpf (mktemp)
    command zellij action dump-screen $tmpf
    # NOTE: <kpbaks 2023-08-24 11:48:27> not perfect regex, but good enough
    string match --regex --all --groups-only "(https?://[^\s\"]+)" <$tmpf
    rm $tmpf
end

function __zellij_fuzzy_select_among_visible_http_urls --argument-names prompt
    if not set --query ZELLIJ
        printf "%serror:%s %s\n" (set_color red) (set_color normal) "fish shell not inside zellij."
        return 1
    end

    set --local title "zellij.fish"
end

function __zellij_select_among_visible_http_urls_and_open
    if not set --query ZELLIJ
        printf "%serror:%s %s\n" (set_color red) (set_color normal) "fish shell not inside zellij."
        return 1
    end

    set --local title "zellij.fish"


    set --local fzf_opts \
        --reverse \
        --border \
        --border-label=" $(string upper $title) " \
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
        --no-mouse \
        --prompt=" select url(s) with <tab>. press <enter> to open them in the browser. " \
        --exit-0 \
        --header-first \
        --bind=ctrl-a:select-all


    set --local urls (__zellij_get_visible_http_urls | sort --unique)
    if test (count $urls) -eq 0
        printf "%swarn:%s %s\n" (set_color yellow) (set_color normal) "no urls found on screen."
        if command --query notify-send
            command notify-send $title "no urls found on screen."
        end
        return 1
    end
    # NOTE: <kpbaks 2023-08-24 19:37:06> use `printf "%s\n" $urls` instead of `echo $urls` to ensure that each url is on a separate line
    set --local selected_urls (printf "%s\n" $urls | fzf $fzf_opts)
    # echo "$(count $selected_urls) urls selected."
    # printf "%s\n" $selected_urls
    if test (count $selected_urls) -eq 0
        return 0
    end

    set --local open_cmd
    if command --query xdg-open
        set open_cmd xdg-open
    else if command --query flatpak-xdg-open
        set open_cmd flatpak-xdg-open
    else
        set --local msg "xdg-open or flatpak-xdg-open not installed."
        printf "%serror:%s %s\n" (set_color red) (set_color normal) $msg
        if command --query notify-send
            command notify-send $title $msg
        end
        printf "%s\n" $selected_urls
        return 1
    end

    for url in $selected_urls
        command $open_cmd $url
    end
end

set --query ZELLIJ_FISH_KEYMAP_OPEN_URL; or set --export ZELLIJ_FISH_KEYMAP_OPEN_URL \eo

# bind \eo '__zellij_select_among_visible_http_urls_and_open; commandline -f repaint'
bind $ZELLIJ_FISH_KEYMAP_OPEN_URL '__zellij_select_among_visible_http_urls_and_open; commandline --function repaint'
