# Loaded into fish by ~/.local/bin/zexos-kitty-shell (fish -C), after your
# fish config and before the greeting, never from your fish config: the
# ZeXOS logo, the prompt, and the logo redraw on window resizes.

set -l kitty (path dirname (status filename))
source $kitty/zexos-prompt.fish

if test "$ZEXOS_TERM_FETCH" = 1
    # A distro greeting that runs fastfetch (CachyOS's does) now runs ours,
    # so you get it once. Otherwise draw it now, before your greeting.
    set -l from (functions --details fish_greeting)
    if not string match -q -- "$__fish_config_dir/*" $from
        and functions fish_greeting | string match -qr '\bfastfetch\b'
        function fish_greeting
            zexos-fetch
        end
    else
        zexos-fetch
        # fish's own "Welcome to fish" line would sit under the logo; a
        # greeting you or your distro set up is kept.
        string match -q -r -- "^(embedded:|$__fish_data_dir/functions/)" $from; and function fish_greeting; end
    end
end
set -e ZEXOS_TERM_FETCH

test "$ZEXOS_TERM_REDRAW" = 1; and source $kitty/fastfetch-redraw.fish
