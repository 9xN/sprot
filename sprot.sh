
download_speed() {
start=$(date +%s)
wget -q -O /dev/null http://speedtest.wdc01.softlayer.com/downloads/test500.zip
end=$(date +%s)
speed=$((500 / (end - start)))
echo "Download speed: $speed Mb/s"
}

esc() {
    case $1 in
        CUU) e="${esc_c}[${2}A" ;; # cursor up
        CUD) e="${esc_c}[${2}B" ;; # cursor down
        CUF) e="${esc_c}[${2}C" ;; # cursor right
        CUB) e="${esc_c}[${2}D" ;; # cursor left

        # text formatting
        SGR)
            case ${PF_COLOR:=1} in
                (1)
                    e="${esc_c}[${2}m"
                ;;

                (0)
                    # colors disabled
                    e=
                ;;
            esac
        ;;

        # line wrap
        DECAWM)
            case $TERM in
                (dumb | minix | cons25)
                    # not supported
                    e=
                ;;

                (*)
                    e="${esc_c}[?7${2}"
                ;;
            esac
        ;;
    esac
}

# Print a sequence to the terminal.
esc_p() {
    esc "$@"
    printf '%s' "$e"
}

has() {
    _cmd=$(command -v "$1") 2>/dev/null || return 1
    [ -x "$_cmd" ] || return 1
}

log() {

    # End here if no data was found.
    [ "$2" ] || return

    name=$1
    use_seperator=$3

    {
        set -f
        set +f -- $2
        info=$*
    }

    esc_p CUF "$ascii_width"
    esc_p SGR "3${PF_COL1-4}";
    esc_p SGR 1
    printf '%s' "$name"
    esc_p SGR 0

    # Print the info name and info data separator, if applicable.
    [ "$use_seperator" ] || printf %s "$PF_SEP"

    esc_p CUB "${#name}"
    esc_p CUF "${PF_ALIGN:-$info_length}"

    # Print the info data, color it and strip all leading whitespace
    # from the string.
    esc_p SGR "3${PF_COL2-9}"
    printf '%s' "$info"
    esc_p SGR 0
    printf '\n'

    # Keep track of the number of times 'log()' has been run.
    info_height=$((${info_height:-0} + 1))
}

get_title() {
    user=${USER:-$(id -un)}
    hostname=${HOSTNAME:-${hostname:-$(hostname)}}

    [ "$hostname" ] || read -r hostname < /etc/hostname

    esc SGR 1
    user=$e$user
    esc SGR "3${PF_COL3:-1}"
    user=$e$user
    esc SGR 1
    user=$user$e
    esc SGR 1
    hostname=$e$hostname
    esc SGR "3${PF_COL3:-1}"
    hostname=$e$hostname

    log "${user}@${hostname}" " " " " >&6
}

get_os() {

    [ "$distro" ] && {
        log os "$distro" >&6
        return
    }

    case $os in
        (Linux*)

            if has lsb_release; then
                distro=$(lsb_release -sd)

            elif [ -d /system/app ] && [ -d /system/priv-app ]; then
                distro="Android $(getprop ro.build.version.release)"

            elif [ -f /etc/os-release ]; then

                while IFS='=' read -r key val; do
                    case $key in
                        (PRETTY_NAME)
                            distro=$val
                        ;;
                    esac
                done < /etc/os-release

            else
                # Special cases for (independent) distributions which
                # don't follow any os-release/lsb standards whatsoever.
                has crux && distro=$(crux)
                has guix && distro='Guix System'
            fi

            # 'os-release' and 'lsb_release' sometimes add quotes
            # around the distribution name, strip them.
            distro=${distro##[\"\']}
            distro=${distro%%[\"\']}

            # Check to see if we're running Bedrock Linux which is
            # very unique. This simply checks to see if the user's
            # PATH contains a Bedrock specific value.
            case $PATH in
                (*/bedrock/cross/*)
                    distro='Bedrock Linux'
                ;;
            esac

            # Check to see if Linux is running in Windows 10 under
            # WSL1 (Windows subsystem for Linux [version 1]) and
            # append a string accordingly.
            #
            # If the kernel version string ends in "-Microsoft",
            # we're very likely running under Windows 10 in WSL1.
            if [ "$WSLENV" ]; then
                distro="${distro}${WSLENV+ on Windows 10 [WSL2]}"

            # Check to see if Linux is running in Windows 10 under
            # WSL2 (Windows subsystem for Linux [version 2]) and
            # append a string accordingly.
            #
            # This checks to see if '$WSLENV' is defined. This
            # appends the Windows 10 string even if '$WSLENV' is
            # empty. We only need to check that is has been _exported_.
            elif [ -z "${kernel%%*-Microsoft}" ]; then
                distro="$distro on Windows 10 [WSL1]"
            fi
        ;;

        (Darwin*)
            # Parse the SystemVersion.plist file to grab the macOS
            # version. The file is in the following format:
            #
            # <key>ProductVersion</key>
            # <string>10.14.6</string>
            #
            # 'IFS' is set to '<>' to enable splitting between the
            # keys and a second 'read' is used to operate on the
            # next line directly after a match.
            #
            # '_' is used to nullify a field. '_ _ line _' basically
            # says "populate $line with the third field's contents".
            while IFS='<>' read -r _ _ line _; do
                case $line in
                    # Match 'ProductVersion' and read the next line
                    # directly as it contains the key's value.
                    ProductVersion)
                        IFS='<>' read -r _ _ mac_version _
                        continue
                    ;;

                    ProductName)
                        IFS='<>' read -r _ _ mac_product _
                        continue
                    ;;
                esac
            done < /System/Library/CoreServices/SystemVersion.plist

            # Use the ProductVersion to determine which macOS/OS X codename
            # the system has. As far as I'm aware there's no "dynamic" way
            # of grabbing this information.
            case $mac_version in
                (10.4*)  distro='Mac OS X Tiger' ;;
                (10.5*)  distro='Mac OS X Leopard' ;;
                (10.6*)  distro='Mac OS X Snow Leopard' ;;
                (10.7*)  distro='Mac OS X Lion' ;;
                (10.8*)  distro='OS X Mountain Lion' ;;
                (10.9*)  distro='OS X Mavericks' ;;
                (10.10*) distro='OS X Yosemite' ;;
                (10.11*) distro='OS X El Capitan' ;;
                (10.12*) distro='macOS Sierra' ;;
                (10.13*) distro='macOS High Sierra' ;;
                (10.14*) distro='macOS Mojave' ;;
                (10.15*) distro='macOS Catalina' ;;
                (11*)    distro='macOS Big Sur' ;;
                (12*)    distro='macOS Monterey' ;;
                (*)      distro='macOS' ;;
            esac

            # Use the ProductName to determine if we're running in iOS.
            case $mac_product in
                (iP*) distro='iOS' ;;
            esac

            distro="$distro $mac_version"
        ;;

        (Haiku)
            # Haiku uses 'uname -v' for version information
            # instead of 'uname -r' which only prints '1'.
            distro=$(uname -sv)
        ;;

        (Minix|DragonFly)
            distro="$os $kernel"

            # Minix and DragonFly don't support the escape
            # sequences used, clear the exit trap.
            trap '' EXIT
        ;;

        (SunOS)
            # Grab the first line of the '/etc/release' file
            # discarding everything after '('.
            IFS='(' read -r distro _ < /etc/release
        ;;

        (OpenBSD*)
            # Show the OpenBSD version type (current if present).
            # kern.version=OpenBSD 6.6-current (GENERIC.MP) ...
            IFS=' =' read -r _ distro openbsd_ver _ <<-EOF
				$(sysctl kern.version)
			EOF

            distro="$distro $openbsd_ver"
        ;;

        (FreeBSD)
            distro="$os $(freebsd-version)"
        ;;

        (*)
            # Catch all to ensure '$distro' is never blank.
            # This also handles the BSDs.
            distro="$os $kernel"
        ;;
    esac
}

get_kernel() {
    case $os in
        # Don't print kernel output on some systems as the
        # OS name includes it.
        (*BSD*|Haiku|Minix)
            return
        ;;
    esac

    # '$kernel' is the cached output of 'uname -r'.
    log kernel "$kernel" >&6
}

get_host() {
    case $os in
        (Linux*)
            # Despite what these files are called, version doesn't
            # always contain the version nor does name always contain
            # the name.
            read -r name    < /sys/devices/virtual/dmi/id/product_name
            read -r version < /sys/devices/virtual/dmi/id/product_version
            read -r model   < /sys/firmware/devicetree/base/model

            host="$name $version $model"
        ;;

        (Darwin* | FreeBSD* | DragonFly*)
            host=$(sysctl -n hw.model)
        ;;

        (NetBSD*)
            host=$(sysctl -n machdep.dmi.system-vendor \
                             machdep.dmi.system-product)
        ;;

        (OpenBSD*)
            host=$(sysctl -n hw.version)
        ;;

        (*BSD* | Minix)
            host=$(sysctl -n hw.vendor hw.product)
        ;;
    esac

    # Turn the host string into an argument list so we can iterate
    # over it and remove OEM strings and other information which
    # shouldn't be displayed.
    #
    # Disable the shellcheck warning for word-splitting
    # as it's safe and intended ('set -f' disables globbing).
    # shellcheck disable=2046,2086
    {
        set -f
        set +f -- $host
        host=
    }

    # Iterate over the host string word by word as a means of stripping
    # unwanted and OEM information from the string as a whole.
    #
    # This could have been implemented using a long 'sed' command with
    # a list of word replacements, however I want to show that something
    # like this is possible in pure sh.
    #
    # This string reconstruction is needed as some OEMs either leave the
    # identification information as "To be filled by OEM", "Default",
    # "undefined" etc and we shouldn't print this to the screen.
    for word do
        # This works by reconstructing the string by excluding words
        # found in the "blacklist" below. Only non-matches are appended
        # to the final host string.
        case $word in
           (To      | [Bb]e      | [Ff]illed | [Bb]y  | O.E.M.  | OEM  |\
            Not     | Applicable | Specified | System | Product | Name |\
            Version | Undefined  | Default   | string | INVALID | �    | os |\
            Type1ProductConfigId )
                continue
            ;;
        esac

        host="$host$word "
    done

    log host "${host:-$arch}" >&6
}

get_uptime() {

    case $os in
        (Linux* | Minix* | SerenityOS*)
            IFS=. read -r s _ < /proc/uptime
        ;;

        (Darwin* | *BSD* | DragonFly*)
            s=$(sysctl -n kern.boottime)

            s=${s#*=}
            s=${s%,*}
            s=$(($(date +%s) - s))
        ;;

        (Haiku)

            s=$(($(system_time) / 1000000))
        ;;

        (SunOS)

            IFS='	.' read -r _ s _ <<-EOF
				$(kstat -p unix:0:system_misc:snaptime)
			EOF
        ;;

        (IRIX)

            t=$(LC_ALL=POSIX ps -o etime= -p 1)

            case $t in
                (*-*)   d=${t%%-*} t=${t#*-} ;;
                (*:*:*) h=${t%%:*} t=${t#*:} ;;
            esac

            h=${h#0} t=${t#0}

            s=$((${d:-0}*86400 + ${h:-0}*3600 + ${t%%:*}*60 + ${t#*:}))
        ;;
    esac

    d=$((s / 60 / 60 / 24))
    h=$((s / 60 / 60 % 24))
    m=$((s / 60 % 60))

    case "$d" in ([!0]*) uptime="${uptime}${d}d "; esac
    case "$h" in ([!0]*) uptime="${uptime}${h}h "; esac
    case "$m" in ([!0]*) uptime="${uptime}${m}m "; esac

    log uptime "${uptime:-0m}" >&6
}

get_pkgs() {

    packages=$(
        case $os in
            (Linux*)
                # Commands which print packages one per line.
                has bonsai     && bonsai list
                has crux       && pkginfo -i
                has pacman-key && pacman -Qq
                has dpkg       && dpkg-query -f '.\n' -W
                has rpm        && rpm -qa
                has xbps-query && xbps-query -l
                has apk        && apk info
                has guix       && guix package --list-installed
                has opkg       && opkg list-installed

                # Directories containing packages.
                has kiss       && printf '%s\n' /var/db/kiss/installed/*/
                has cpt-list   && printf '%s\n' /var/db/cpt/installed/*/
                has brew       && printf '%s\n' "$(brew --cellar)/"*
                has emerge     && printf '%s\n' /var/db/pkg/*/*/
                has pkgtool    && printf '%s\n' /var/log/packages/*
                has eopkg      && printf '%s\n' /var/lib/eopkg/package/*

                # 'nix' requires two commands.
                has nix-store  && {
                    nix-store -q --requisites /run/current-system/sw
                    nix-store -q --requisites ~/.nix-profile
                }
            ;;

            (Darwin*)
                # Commands which print packages one per line.
                has pkgin      && pkgin list
                has dpkg       && dpkg-query -f '.\n' -W

                # Directories containing packages.
                has brew       && printf '%s\n' /usr/local/Cellar/*


                has port       && {
                    pkg_list=$(port installed)

                    case "$pkg_list" in
                        ("No ports are installed.")
                            # do nothing
                        ;;

                        (*)
                            printf '%s\n' "$pkg_list"
                        ;;
                    esac
                }
            ;;

            (FreeBSD*|DragonFly*)
                pkg info
            ;;

            (OpenBSD*)
                printf '%s\n' /var/db/pkg/*/
            ;;

            (NetBSD*)
                pkg_info
            ;;

            (Haiku)
                printf '%s\n' /boot/system/package-links/*
            ;;

            (Minix)
                printf '%s\n' /usr/pkg/var/db/pkg/*/
            ;;

            (SunOS)
                has pkginfo && pkginfo -i
                has pkg     && pkg list
            ;;

            (IRIX)
                versions -b
            ;;

            (SerenityOS)
                while IFS=" " read -r type _; do
                    [ "$type" != dependency ] &&
                        printf "\n"
                done < /usr/Ports/packages.db
            ;;
        esac | wc -l
    )

    packages=${packages#"${packages%%[![:space:]]*}"}
    packages=${packages%"${packages##*[![:space:]]}"}

    case $os in

        (IRIX)
            packages=$((packages - 3))
        ;;

        (OpenBSD)
            packages=$((packages))
        ;;
    esac

    case $packages in
        (1?*|[2-9]*)
            log pkgs "$packages" >&6
        ;;
    esac
}

get_memory() {
    case $os in

        (Linux*)

            while IFS=':k '  read -r key val _; do
                case $key in
                    (MemTotal)
                        mem_used=$((mem_used + val))
                        mem_full=$val
                    ;;

                    (Shmem)
                        mem_used=$((mem_used + val))
                    ;;

                    (MemFree | Buffers | Cached | SReclaimable)
                        mem_used=$((mem_used - val))
                    ;;

                    (MemAvailable)
                        mem_avail=$val
                    ;;
                esac
            done < /proc/meminfo

            case $mem_avail in
                (*[0-9]*)
                    mem_used=$(((mem_full - mem_avail) / 1024))
                ;;

                *)
                    mem_used=$((mem_used / 1024))
                ;;
            esac

            mem_full=$((mem_full / 1024))
        ;;

        (Darwin*)
            mem_full=$(($(sysctl -n hw.memsize) / 1024 / 1024))

            while IFS=:. read -r key val; do
                case $key in
                    (*' wired'*|*' active'*|*' occupied'*)
                        mem_used=$((mem_used + ${val:-0}))
                    ;;
                esac
            done <<-EOF
                $(vm_stat)
			EOF

            mem_used=$((mem_used * 4 / 1024))
        ;;

        (OpenBSD*)
            mem_full=$(($(sysctl -n hw.physmem) / 1024 / 1024))

            while read -r _ _ line _; do
                mem_used=${line%%M}

            done <<-EOF
                $(vmstat)
			EOF
        ;;

        (FreeBSD*|DragonFly*)
            mem_full=$(($(sysctl -n hw.physmem) / 1024 / 1024))

            {
                set -f
                set +f -- $(sysctl -n hw.pagesize \
                                      vm.stats.vm.v_inactive_count \
                                      vm.stats.vm.v_free_count \
                                      vm.stats.vm.v_cache_count)
            }

            mem_used=$((mem_full - (($2 + $3 + $4) * $1 / 1024 / 1024)))
        ;;

        (NetBSD*)
            mem_full=$(($(sysctl -n hw.physmem64) / 1024 / 1024))

            while IFS=':k ' read -r key val _; do
                case $key in
                    (MemFree)
                        mem_free=$((val / 1024))
                        break
                    ;;
                esac
            done < /proc/meminfo

            mem_used=$((mem_full - mem_free))
        ;;

        (Haiku)

            IFS='( )' read -r _ _ _ _ mem_used _ mem_full <<-EOF
                $(sysinfo -mem)
			EOF

            mem_used=$((mem_used / 1024 / 1024))
            mem_full=$((mem_full / 1024 / 1024))
        ;;

        (Minix)

            read -r _ mem_full mem_free _ < /proc/meminfo

            mem_used=$(((mem_full - mem_free) / 1024))
            mem_full=$(( mem_full / 1024))
        ;;

        (SunOS)
            hw_pagesize=$(pagesize)

            # 'kstat' outputs memory in the following format:
            # unix:0:system_pages:pagestotal	1046397
            # unix:0:system_pages:pagesfree		885018
            #
            # This simply uses the first "element" (white-space
            # separated) as the key and the second element as the
            # value.
            #
            # A variable is then assigned based on the key.
            while read -r key val; do
                case $key in
                    (*total)
                        pages_full=$val
                    ;;

                    (*free)
                        pages_free=$val
                    ;;
                esac
            done <<-EOF
				$(kstat -p unix:0:system_pages:pagestotal \
                           unix:0:system_pages:pagesfree)
			EOF

            mem_full=$((pages_full * hw_pagesize / 1024 / 1024))
            mem_free=$((pages_free * hw_pagesize / 1024 / 1024))
            mem_used=$((mem_full - mem_free))
        ;;

        (IRIX)
            # Read the memory information from the 'top' command. Parse
            # and split each line until we reach the line starting with
            # "Memory".
            #
            # Example output: Memory: 160M max, 147M avail, .....
            while IFS=' :' read -r label mem_full _ mem_free _; do
                case $label in
                    (Memory)
                        mem_full=${mem_full%M}
                        mem_free=${mem_free%M}
                        break
                    ;;
                esac
            done <<-EOF
                $(top -n)
			EOF

            mem_used=$((mem_full - mem_free))
        ;;

        (SerenityOS)
            IFS='{}' read -r _ memstat _ < /proc/memstat

            set -f -- "$IFS"
            IFS=,

            for pair in $memstat; do
                case $pair in
                    (*user_physical_allocated*)
                        mem_used=${pair##*:}
                    ;;

                    (*user_physical_available*)
                        mem_free=${pair##*:}
                    ;;
                esac
            done

            IFS=$1
            set +f --

            mem_used=$((mem_used * 4096 / 1024 / 1024))
            mem_free=$((mem_free * 4096 / 1024 / 1024))

            mem_full=$((mem_used + mem_free))
        ;;
    esac

    log memory "${mem_used:-?}M / ${mem_full:-?}M" >&6
}

get_wm() {
    case $os in
        (Darwin*)
        ;;

        (*)
           
            [ "$DISPLAY" ] || return
            has xprop && {

                id=$(xprop -root -notype _NET_SUPPORTING_WM_CHECK)
                id=${id##* }


                wm=$(xprop -id "$id" -notype -len 25 -f _NET_WM_NAME 8t)
            }

            case $wm in
                (*'_NET_WM_NAME = '*)
                    wm=${wm##*_NET_WM_NAME = \"}
                    wm=${wm%%\"*}
                ;;

                (*)

                    while read -r ps_line; do
                        case $ps_line in
                            (*catwm*)     wm=catwm ;;
                            (*fvwm*)      wm=fvwm ;;
                            (*dwm*)       wm=dwm ;;
                            (*2bwm*)      wm=2bwm ;;
                            (*monsterwm*) wm=monsterwm ;;
                            (*wmaker*)    wm='Window Maker' ;;
                            (*sowm*)      wm=sowm ;;
							(*penrose*)   wm=penrose ;;
                        esac
                    done <<-EOF
                        $(ps x)
					EOF
                ;;
            esac
        ;;
    esac

    log wm "$wm" >&6
}


get_de() {

    log de "${XDG_CURRENT_DESKTOP:-$DESKTOP_SESSION}" >&6
}

get_shell() {
    # Display the basename of the '$SHELL' environment variable.
    log shell "${SHELL##*/}" >&6
}

get_editor() {
    # Display the value of '$VISUAL', if it's empty, display the
    # value of '$EDITOR'.
    editor=${VISUAL:-"$EDITOR"}

    log editor "${editor##*/}" >&6
}

get_palette() {

    {
        esc SGR 7
        palette="$e$c1 $c1 $c2 $c2 $c3 $c3 $c4 $c4 $c5 $c5 $c6 $c6 "
        esc SGR 0
        palette="$palette$e"
    }

    # Print the palette with a new-line before and afterwards but no seperator.
    printf '\n' >&6
    log "$palette
        " " " " " >&6
}

get_ascii() {

    read_ascii() {

        PF_COL1=${PF_COL1:-${1:-7}}
        PF_COL3=${PF_COL3:-$((${1:-7}%8+1))}

        while IFS= read -r line; do
            ascii="$ascii$line
"
        done
    }


    case ${1:-${PF_ASCII:-${distro:-$os}}} in
        ([Aa]lpine*)
            read_ascii 4 <<-EOF
				${c4}   /\\ /\\
				  /${c7}/ ${c4}\\  \\
				 /${c7}/   ${c4}\\  \\
				/${c7}//    ${c4}\\  \\
				${c7}//      ${c4}\\  \\
				         ${c4}\\
			EOF
        ;;

        ([Aa]ndroid*)
            read_ascii 2 <<-EOF
				${c2}  ;,           ,;
				${c2}   ';,.-----.,;'
				${c2}  ,'           ',
				${c2} /    O     O    \\
				${c2}|                 |
				${c2}'-----------------'
			EOF
        ;;

        ([Aa]rch*)
            read_ascii 4 <<-EOF
				${c6}       /\\
				${c6}      /  \\
				${c6}     /\\   \\
				${c4}    /      \\
				${c4}   /   ,,   \\
				${c4}  /   |  |  -\\
				${c4} /_-''    ''-_\\
			EOF
        ;;

        ([Aa]rco*)
            read_ascii 4 <<-EOF
				${c4}      /\\
				${c4}     /  \\
				${c4}    / /\\ \\
				${c4}   / /  \\ \\
				${c4}  / /    \\ \\
				${c4} / / _____\\ \\
				${c4}/_/  \`----.\\_\\
			EOF
        ;;

        ([Aa]rtix*)
            read_ascii 6 <<-EOF
				${c4}      /\\
				${c4}     /  \\
				${c4}    /\`'.,\\
				${c4}   /     ',
				${c4}  /      ,\`\\
				${c4} /   ,.'\`.  \\
				${c4}/.,'\`     \`'.\\
			EOF
        ;;

        ([Bb]edrock*)
            read_ascii 4 <<-EOF
				${c7}__
				${c7}\\ \\___
				${c7} \\  _ \\
				${c7}  \\___/
			EOF
        ;;

        ([Bb]uildroot*)
            read_ascii 3 <<-EOF
				${c3}   ___
				${c3} / \`   \\
				${c3}|   :  :|
				${c3}-. _:__.-
				${c3}  \` ---- \`
			EOF
        ;;

        ([Cc]el[Oo][Ss]*)
            read_ascii 5 0 <<-EOF
				${c5}      .////\\\\\//\\.
				${c5}     //_         \\\\
				${c5}    /_  ${c7}##############
				${c5}   //              *\\
				${c7}###############    ${c5}|#
				${c5}   \/              */
				${c5}    \*   ${c7}##############
				${c5}     */,        .//
				${c5}      '_///\\\\\//_'
			EOF
        ;;

        ([Cc]ent[Oo][Ss]*)
            read_ascii 5 <<-EOF
				${c2} ____${c3}^${c5}____
				${c2} |\\  ${c3}|${c5}  /|
				${c2} | \\ ${c3}|${c5} / |
				${c5}<---- ${c4}---->
				${c4} | / ${c2}|${c3} \\ |
				${c4} |/__${c2}|${c3}__\\|
				${c2}     v
			EOF
        ;;

        ([Cc]rystal*[Ll]inux)
            read_ascii 5 5 <<-EOF
				${c5}        -//.     
				${c5}      -//.       
				${c5}    -//. .       
				${c5}  -//.  '//-     
				${c5} /+:      :+/    
				${c5}  .//'  .//.     
				${c5}    . .//.       
				${c5}    .//.         
				${c5}  .//.           
			EOF
        ;;

        ([Dd]ahlia*)
            read_ascii 1 <<-EOF
				${c1}      _
				${c1}  ___/ \\___
				${c1} |   _-_   |
				${c1} | /     \ |
				${c1}/ |       | \\
				${c1}\\ |       | /
				${c1} | \ _ _ / |
				${c1} |___ - ___|
				${c1}     \\_/
			EOF
        ;;

        ([Dd]ebian*)
            read_ascii 1 <<-EOF
				${c1}  _____
				${c1} /  __ \\
				${c1}|  /    |
				${c1}|  \\___-
				${c1}-_
				${c1}  --_
			EOF
        ;;

		([Dd]evuan*)
			read_ascii 6 <<-EOF
				${c4} ..:::.      
				${c4}    ..-==-   
				${c4}        .+#: 
				${c4}         =@@ 
				${c4}      :+%@#: 
				${c4}.:=+#@@%*:   
				${c4}#@@@#=:      
			EOF
		;;

        ([Dd]ragon[Ff]ly*)
            read_ascii 1 <<-EOF
				    ,${c1}_${c7},
				 ('-_${c1}|${c7}_-')
				  >--${c1}|${c7}--<
				 (_-'${c1}|${c7}'-_)
				     ${c1}|
				     ${c1}|
				     ${c1}|
			EOF
        ;;

        ([Ee]lementary*)
            read_ascii <<-EOF
				${c7}  _______
				${c7} / ____  \\
				${c7}/  |  /  /\\
				${c7}|__\\ /  / |
				${c7}\\   /__/  /
				 ${c7}\\_______/
			EOF
        ;;

        ([Ee]ndeavour*)
            read_ascii 4 <<-EOF
				      ${c1}/${c4}\\
				    ${c1}/${c4}/  \\${c6}\\
				   ${c1}/${c4}/    \\ ${c6}\\
				 ${c1}/ ${c4}/     _) ${c6})
				${c1}/_${c4}/___-- ${c6}__-
				 ${c6}/____--
			EOF
        ;;

        ([Ff]edora*)
            read_ascii 4 <<-EOF
				        ${c4},'''''.
				       ${c4}|   ,.  |
				       ${c4}|  |  '_'
				${c4}  ,....|  |..
				${c4}.'  ,_;|   ..'
				${c4}|  |   |  |
				${c4}|  ',_,'  |
				${c4} '.     ,'
				   ${c4}'''''
			EOF
        ;;

        ([Ff]ree[Bb][Ss][Dd]*)
            read_ascii 1 <<-EOF
				${c1}/\\,-'''''-,/\\
				${c1}\\_)       (_/
				${c1}|           |
				${c1}|           |
				 ${c1};         ;
				  ${c1}'-_____-'
			EOF
        ;;

        ([Gg]aruda*)
            read_ascii 4 <<-EOF
				${c3}         _______
				${c3}      __/       \\_
				${c3}    _/     /      \\_
				${c7}  _/      /_________\\
				${c7}_/                  |
				${c2}\\     ____________
				${c2} \\_            __/
				${c2}   \\__________/
			EOF
        ;;

        ([Gg]entoo*)
            read_ascii 5 <<-EOF
				${c5} _-----_
				${c5}(       \\
				${c5}\\    0   \\
				${c7} \\        )
				${c7} /      _/
				${c7}(     _-
				${c7}\\____-
			EOF
        ;;

        ([Gg][Nn][Uu]*)
            read_ascii 3 <<-EOF
				${c2}    _-\`\`-,   ,-\`\`-_
				${c2}  .'  _-_|   |_-_  '.
				${c2}./    /_._   _._\\    \\.
				${c2}:    _/_._\`:'_._\\_    :
				${c2}\\:._/  ,\`   \\   \\ \\_.:/
				${c2}   ,-';'.@)  \\ @) \\
				${c2}   ,'/'  ..- .\\,-.|
				${c2}   /'/' \\(( \\\` ./ )
				${c2}    '/''  \\_,----'
				${c2}      '/''   ,;/''
				${c2}         \`\`;'
			EOF
        ;;

        ([Gg]uix[Ss][Dd]*|[Gg]uix*)
            read_ascii 3 <<-EOF
				${c3}|.__          __.|
				${c3}|__ \\        / __|
				   ${c3}\\ \\      / /
				    ${c3}\\ \\    / /
				     ${c3}\\ \\  / /
				      ${c3}\\ \\/ /
				       ${c3}\\__/
			EOF
        ;;

        ([Hh]aiku*)
            read_ascii 3 <<-EOF
				${c3}       ,^,
				 ${c3}     /   \\
				${c3}*--_ ;     ; _--*
				${c3}\\   '"     "'   /
				 ${c3}'.           .'
				${c3}.-'"         "'-.
				 ${c3}'-.__.   .__.-'
				       ${c3}|_|
			EOF
        ;;

        ([Hh]ydroOS*)
			read_ascii 4 <<-EOF
				${c1}╔╗╔╗──╔╗───╔═╦══╗
				${c1}║╚╝╠╦╦╝╠╦╦═╣║║══╣
				${c1}║╔╗║║║╬║╔╣╬║║╠══║
				${c1}╚╝╚╬╗╠═╩╝╚═╩═╩══╝
				${c1}───╚═╝
			EOF
        ;;

        ([Hh]yperbola*)
            read_ascii <<-EOF
				${c7}    |\`__.\`/
				   ${c7} \____/
				   ${c7} .--.
				  ${c7} /    \\
				 ${c7} /  ___ \\
				 ${c7}/ .\`   \`.\\
				${c7}/.\`      \`.\\
			EOF
        ;;

        ([Ii]glunix*)
            read_ascii <<-EOF
				${c0}       |
				${c0}       |          |
				${c0}                  |
				${c0}  |    ________
				${c0}  |  /\\   |    \\
				${c0}    /  \\  |     \\  |
				${c0}   /    \\        \\ |
				${c0}  /      \\________\\
				${c0}  \\      /        /
				${c0}   \\    /        /
				${c0}    \\  /        /
				${c0}     \\/________/
			EOF
        ;;

        ([Ii]nstant[Oo][Ss]*)
            read_ascii <<-EOF
				${c0} ,-''-,
				${c0}: .''. :
				${c0}: ',,' :
				${c0} '-____:__
				${c0}       :  \`.
				${c0}       \`._.'
			EOF
        ;;

        ([Ii][Rr][Ii][Xx]*)
            read_ascii 1 <<-EOF
				${c1} __
				${c1} \\ \\   __
				${c1}  \\ \\ / /
				${c1}   \\ v /
				${c1}   / . \\
				${c1}  /_/ \\ \\
				${c1}       \\_\\
			EOF
        ;;

        ([Kk][Dd][Ee]*[Nn]eon*)
            read_ascii 6 <<-EOF
				${c7}   .${c6}__${c7}.${c6}__${c7}.
				${c6}  /  _${c7}.${c6}_  \\
				${c6} /  /   \\  \\
				${c7} . ${c6}|  ${c7}O${c6}  | ${c7}.
				${c6} \\  \\_${c7}.${c6}_/  /
				${c6}  \\${c7}.${c6}__${c7}.${c6}__${c7}.${c6}/
			EOF
        ;;

        ([Ll]inux*[Ll]ite*|[Ll]ite*)
            read_ascii 3 <<-EOF
				${c3}   /\\
				${c3}  /  \\
				${c3} / ${c7}/ ${c3}/
			${c3}> ${c7}/ ${c3}/
				${c3}\\ ${c7}\\ ${c3}\\
				 ${c3}\\_${c7}\\${c3}_\\
				${c7}    \\
			EOF
        ;;

        ([Ll]inux*[Mm]int*|[Mm]int)
            read_ascii 2 <<-EOF
				${c2} ___________
				${c2}|_          \\
				  ${c2}| ${c7}| _____ ${c2}|
				  ${c2}| ${c7}| | | | ${c2}|
				  ${c2}| ${c7}| | | | ${c2}|
				  ${c2}| ${c7}\\__${c7}___/ ${c2}|
				  ${c2}\\_________/
			EOF
        ;;


        ([Ll]inux*)
            read_ascii 4 <<-EOF
				${c4}    ___
				   ${c4}(${c7}.. ${c4}|
				   ${c4}(${c5}<> ${c4}|
				  ${c4}/ ${c7}__  ${c4}\\
				 ${c4}( ${c7}/  \\ ${c4}/|
				${c5}_${c4}/\\ ${c7}__)${c4}/${c5}_${c4})
				${c5}\/${c4}-____${c5}\/
			EOF
        ;;

        ([Mm]ac[Oo][Ss]*|[Dd]arwin*)
            read_ascii 1 <<-EOF
				${c2}       .:'
				${c2}    _ :'_
				${c3} .'\`_\`-'_\`\`.
				${c1}:________.-'
				${c1}:_______:
				${c4} :_______\`-;
				${c5}  \`._.-._.'
			EOF
        ;;

        ([Mm]ageia*)
            read_ascii 2 <<-EOF
				${c6}   *
				${c6}    *
				${c6}   **
				${c7} /\\__/\\
				${c7}/      \\
				${c7}\\      /
				${c7} \\____/
			EOF
        ;;

        ([Mm]anjaro*)
            read_ascii 2 <<-EOF
				${c2}||||||||| ||||
				${c2}||||||||| ||||
				${c2}||||      ||||
				${c2}|||| |||| ||||
				${c2}|||| |||| ||||
				${c2}|||| |||| ||||
				${c2}|||| |||| ||||
			EOF
        ;;

        ([Mm]inix*)
            read_ascii 4 <<-EOF
				${c4} ,,        ,,
				${c4};${c7},${c4} ',    ,' ${c7},${c4};
				${c4}; ${c7}',${c4} ',,' ${c7},'${c4} ;
				${c4};   ${c7}',${c4}  ${c7},'${c4}   ;
				${c4};  ${c7};, '' ,;${c4}  ;
				${c4};  ${c7};${c4};${c7}',,'${c4};${c7};${c4}  ;
				${c4}', ${c7};${c4};;  ;;${c7};${c4} ,'
				 ${c4} '${c7};${c4}'    '${c7};${c4}'
			EOF
        ;;

        ([Mm][Xx]*)
            read_ascii <<-EOF
				${c7}    \\\\  /
				 ${c7}    \\\\/
				 ${c7}     \\\\
				 ${c7}  /\\/ \\\\
				${c7}  /  \\  /\\
				${c7} /    \\/  \\
			${c7}/__________\\
			EOF
        ;;

        ([Nn]et[Bb][Ss][Dd]*)
            read_ascii 3 <<-EOF
				${c7}\\\\${c3}\`-______,----__
				${c7} \\\\        ${c3}__,---\`_
				${c7}  \\\\       ${c3}\`.____
				${c7}   \\\\${c3}-______,----\`-
				${c7}    \\\\
				${c7}     \\\\
				${c7}      \\\\
			EOF
        ;;

        ([Nn]ix[Oo][Ss]*)
            read_ascii 4 <<-EOF
				${c4}  \\\\  \\\\ //
				${c4} ==\\\\__\\\\/ //
				${c4}   //   \\\\//
				${c4}==//     //==
				${c4} //\\\\___//
				${c4}// /\\\\  \\\\==
				${c4}  // \\\\  \\\\
			EOF
        ;;

        ([Oo]pen[Bb][Ss][Dd]*)
            read_ascii 3 <<-EOF
				${c3}      _____
				${c3}    \\-     -/
				${c3} \\_/         \\
				${c3} |        ${c7}O O${c3} |
				${c3} |_  <   )  3 )
				${c3} / \\         /
				 ${c3}   /-_____-\\
			EOF
        ;;

        ([Oo]pen[Ss][Uu][Ss][Ee]*[Tt]umbleweed*)
            read_ascii 2 <<-EOF
				${c2}  _____   ______
				${c2} / ____\\ / ____ \\
				${c2}/ /    \`/ /    \\ \\
				${c2}\\ \\____/ /,____/ /
				${c2} \\______/ \\_____/
			EOF
        ;;

        ([Oo]pen[Ss][Uu][Ss][Ee]*|[Oo]pen*SUSE*|SUSE*|suse*)
            read_ascii 2 <<-EOF
				${c2}  _______
				${c2}__|   __ \\
				${c2}     / .\\ \\
				${c2}     \\__/ |
				${c2}   _______|
				${c2}   \\_______
				${c2}__________/
			EOF
        ;;

        ([Oo]pen[Ww]rt*)
            read_ascii 1 <<-EOF
				${c1} _______
				${c1}|       |.-----.-----.-----.
				${c1}|   -   ||  _  |  -__|     |
				${c1}|_______||   __|_____|__|__|
				${c1} ________|__|    __
				${c1}|  |  |  |.----.|  |_
				${c1}|  |  |  ||   _||   _|
				${c1}|________||__|  |____|
			EOF
        ;;

        ([Pp]arabola*)
            read_ascii 5 <<-EOF
				${c5}  __ __ __  _
				${c5}.\`_//_//_/ / \`.
				${c5}          /  .\`
				${c5}         / .\`
				${c5}        /.\`
				${c5}       /\`
			EOF
        ;;

        ([Pp]op!_[Oo][Ss]*)
            read_ascii 6 <<-EOF
				${c6}______
				${c6}\\   _ \\        __
				 ${c6}\\ \\ \\ \\      / /
				  ${c6}\\ \\_\\ \\    / /
				   ${c6}\\  ___\\  /_/
				   ${c6} \\ \\    _
				  ${c6} __\\_\\__(_)_
				  ${c6}(___________)
			EOF
        ;;

        ([Pp]ure[Oo][Ss]*)
            read_ascii <<-EOF
				${c7} _____________
				${c7}|  _________  |
				${c7}| |         | |
				${c7}| |         | |
				${c7}| |_________| |
				${c7}|_____________|
			EOF
        ;;

        ([Rr]aspbian*)
            read_ascii 1 <<-EOF
				${c2}  __  __
				${c2} (_\\)(/_)
				${c1} (_(__)_)
				${c1}(_(_)(_)_)
				${c1} (_(__)_)
				${c1}   (__)
			EOF
        ;;

        ([Ss]erenity[Oo][Ss]*)
            read_ascii 4 <<-EOF
				${c7}    _____
				${c1}  ,-${c7}     -,
				${c1} ;${c7} (       ;
				${c1}| ${c7}. \_${c1}.,${c7}    |
				${c1}|  ${c7}o  _${c1} ',${c7}  |
				${c1} ;   ${c7}(_)${c1} )${c7} ;
				${c1}  '-_____-${c7}'
			EOF
        ;;

        ([Ss]lackware*)
            read_ascii 4 <<-EOF
				${c4}   ________
				${c4}  /  ______|
				${c4}  | |______
				${c4}  \\______  \\
				${c4}   ______| |
				${c4}| |________/
				${c4}|____________
			EOF
        ;;

        ([Ss]olus*)
            read_ascii 4 <<-EOF
				${c6} 
				${c6}     /|
				${c6}    / |\\
				${c6}   /  | \\ _
				${c6}  /___|__\\_\\
				${c6} \\         /
				${c6}  \`-------´
			EOF
        ;;

        ([Ss]un[Oo][Ss]|[Ss]olaris*)
            read_ascii 3 <<-EOF
				${c3}       .   .;   .
				${c3}   .   :;  ::  ;:   .
				${c3}   .;. ..      .. .;.
				${c3}..  ..             ..  ..
				${c3} .;,                 ,;.
			EOF
        ;;

        ([Uu]buntu*)
            read_ascii 3 <<-EOF
				${c3}         _
				${c3}     ---(_)
				${c3} _/  ---  \\
				${c3}(_) |   |
				 ${c3} \\  --- _/
				    ${c3} ---(_)
			EOF
        ;;

        ([Vv]oid*)
            read_ascii 2 <<-EOF
				${c2}    _______
				${c2} _ \\______ -
				${c2}| \\  ___  \\ |
				${c2}| | /   \ | |
				${c2}| | \___/ | |
				${c2}| \\______ \\_|
				${c2} -_______\\
			EOF
        ;;

        ([Xx]eonix*)
            read_ascii 2 <<-EOF
				${c2}    ___  ___
				${c2}___ \  \/  / ___
				${c2}\  \ \    / /  /
				${c2} \  \/    \/  /
				${c2}  \    /\    /
				${c2}   \__/  \__/
			EOF
        ;;

        (*)

            [ "$1" ] || {
                get_ascii "$os"
                return
            }

            printf 'error: %s is not currently supported.\n' "$os" >&6
            printf 'error: Open an issue for support to be added.\n' >&6
            exit 1
        ;;
    esac

    while read -r line; do
        ascii_height=$((${ascii_height:-0} + 1))

        [ "${#line}" -gt "${ascii_width:-0}" ] &&
            ascii_width=${#line}


    done <<-EOF
 		$(printf %s "$ascii" | sed 's/\[3.m//g')
	EOF

    # Add a gap between the ascii art and the information.
    ascii_width=$((ascii_width + 4))

    {
        esc_p SGR 1
        printf '%s' "$ascii"
        esc_p SGR 0
        esc_p CUU "$ascii_height"
    } >&6
}

main() {
    case $* in
        -v)
            printf '%s 0.7.0\n' "${0##*/}"
            return 0
        ;;

        -d)
            # Below exec is not run, stderr is shown.
        ;;

        '')
            exec 2>/dev/null
        ;;

        *)
            cat <<EOF
${0##*/}     show system information
${0##*/} -d  show stderr (debug mode)
${0##*/} -v  show version information
EOF
            return 0
        ;;
    esac

    exec 6>&1 >/dev/null

    esc_c=$(printf '\033')

    ! [ -f "$PF_SOURCE" ] || . "$PF_SOURCE"

    [ -w "${TMPDIR:-/tmp}" ] || export TMPDIR=~

    for _c in c1 c2 c3 c4 c5 c6 c7 c8; do
        esc SGR "3${_c#?}" 0
        export "$_c=$e"
    done

    esc_p DECAWM l >&6
    trap 'esc_p DECAWM h >&6' EXIT

    read -r os kernel arch <<-EOF
		$(uname -srm)
	EOF

    get_os

    {
 
        set -f
        set +f -- ${PF_INFO-ascii title os host kernel uptime pkgs memory}

        for info do
            command -v "get_$info" >/dev/null || continue

            [ "${#info}" -gt "${info_length:-0}" ] &&
                info_length=${#info}
        done

        info_length=$((info_length + 1))

        for info do
            "get_$info"
        done
    }

    [ "${info_height:-0}" -lt "${ascii_height:-0}" ] &&
        cursor_pos=$((ascii_height - info_height))

    while [ "${i:=0}" -le "${cursor_pos:-0}" ]; do
        printf '\n'
        i=$((i + 1))
    done >&6
}

networking() {
IPTABLES="/sbin/iptables"
IP6TABLES="/sbin/ip6tables"
MODPROBE="/sbin/modprobe"
SSHPORT="22"
LOG="LOG --log-level debug --log-tcp-sequence --log-tcp-options"
LOG="$LOG --log-ip-options"
RLIMIT="-m limit --limit 3/s --limit-burst 8"
"$MODPROBE" ip_conntrack_ftp
"$MODPROBE" ip_conntrack_irc
echo 1 > /proc/sys/net/ipv4/tcp_syncookies
echo 1 > /proc/sys/net/ipv4/ip_forward
echo 1 > /proc/sys/net/ipv4/icmp_echo_ignore_broadcasts
echo 1 > /proc/sys/net/ipv4/icmp_ignore_bogus_error_responses
echo 0 > /proc/sys/net/ipv4/ip_forward
echo 0 > /proc/sys/net/ipv4/icmp_echo_ignore_all
for i in /proc/sys/net/ipv4/conf/*/rp_filter; do echo 1 > "$i"; done
for i in /proc/sys/net/ipv4/conf/*/log_martians; do echo 1 > "$i"; done
for i in /proc/sys/net/ipv4/conf/*/secure_redirects; do echo 1 > "$i"; done
for i in /proc/sys/net/ipv4/conf/*/bootp_relay; do echo 0 > "$i"; done
for i in /proc/sys/net/ipv4/conf/*/accept_redirects; do echo 0 > "$i"; done
for i in /proc/sys/net/ipv4/conf/*/send_redirects; do echo 0 > "$i"; done
for i in /proc/sys/net/ipv4/conf/*/accept_source_route; do echo 0 > "$i"; done
for i in /proc/sys/net/ipv4/conf/*/mc_forwarding; do echo 0 > "$i"; done
for i in /proc/sys/net/ipv4/conf/*/proxy_arp; do echo 0 > "$i"; done
"$IPTABLES" -P INPUT DROP
"$IPTABLES" -P FORWARD DROP
"$IPTABLES" -P OUTPUT DROP
"$IPTABLES" -t nat -P PREROUTING ACCEPT
"$IPTABLES" -t nat -P OUTPUT ACCEPT
"$IPTABLES" -t nat -P POSTROUTING ACCEPT
"$IPTABLES" -t mangle -P PREROUTING ACCEPT
"$IPTABLES" -t mangle -P INPUT ACCEPT
"$IPTABLES" -t mangle -P FORWARD ACCEPT
"$IPTABLES" -t mangle -P OUTPUT ACCEPT
"$IPTABLES" -t mangle -P POSTROUTING ACCEPT
"$IPTABLES" -F
"$IPTABLES" -t nat -F
"$IPTABLES" -t mangle -F
"$IPTABLES" -X
"$IPTABLES" -t nat -X
"$IPTABLES" -t mangle -X
"$IPTABLES" -Z
"$IPTABLES" -t nat -Z
"$IPTABLES" -t mangle -Z
if test -x "$IP6TABLES"; then
"$IP6TABLES" -P INPUT DROP 2>/dev/null
"$IP6TABLES" -P FORWARD DROP 2>/dev/null
"$IP6TABLES" -P OUTPUT DROP 2>/dev/null
"$IP6TABLES" -t mangle -P PREROUTING ACCEPT 2>/dev/null
"$IP6TABLES" -t mangle -P INPUT ACCEPT 2>/dev/null
"$IP6TABLES" -t mangle -P FORWARD ACCEPT 2>/dev/null
"$IP6TABLES" -t mangle -P OUTPUT ACCEPT 2>/dev/null
"$IP6TABLES" -t mangle -P POSTROUTING ACCEPT 2>/dev/null
"$IP6TABLES" -F 2>/dev/null
"$IP6TABLES" -t mangle -F 2>/dev/null
"$IP6TABLES" -X 2>/dev/null
"$IP6TABLES" -t mangle -X 2>/dev/null
"$IP6TABLES" -Z 2>/dev/null
"$IP6TABLES" -t mangle -Z 2>/dev/null
fi
"$IPTABLES" -N ACCEPTLOG
"$IPTABLES" -A ACCEPTLOG -j "$LOG" "$RLIMIT" --log-prefix "ACCEPT "
"$IPTABLES" -A ACCEPTLOG -j ACCEPT
"$IPTABLES" -N DROPLOG
"$IPTABLES" -A DROPLOG -j "$LOG" "$RLIMIT" --log-prefix "DROP "
"$IPTABLES" -A DROPLOG -j DROP
"$IPTABLES" -N REJECTLOG
"$IPTABLES" -A REJECTLOG -j "$LOG" "$RLIMIT" --log-prefix "REJECT "
"$IPTABLES" -A REJECTLOG -p tcp -j REJECT --reject-with tcp-reset
"$IPTABLES" -A REJECTLOG -j REJECT
"$IPTABLES" -N RELATED_ICMP
"$IPTABLES" -A RELATED_ICMP -p icmp --icmp-type destination-unreachable -j ACCEPT
"$IPTABLES" -A RELATED_ICMP -p icmp --icmp-type time-exceeded -j ACCEPT
"$IPTABLES" -A RELATED_ICMP -p icmp --icmp-type parameter-problem -j ACCEPT
"$IPTABLES" -A RELATED_ICMP -j DROPLOG
"$IPTABLES" -A INPUT -p icmp -m limit --limit 1/s --limit-burst 2 -j ACCEPT
"$IPTABLES" -A INPUT -p icmp -m limit --limit 1/s --limit-burst 2 -j LOG --log-prefix PING-DROP:
"$IPTABLES" -A INPUT -p icmp -j DROP
"$IPTABLES" -A OUTPUT -p icmp -j ACCEPT
"$IPTABLES" -A INPUT -p icmp --fragment -j DROPLOG
"$IPTABLES" -A OUTPUT -p icmp --fragment -j DROPLOG
"$IPTABLES" -A FORWARD -p icmp --fragment -j DROPLOG
"$IPTABLES" -A INPUT -p icmp -m state --state ESTABLISHED -j ACCEPT "$RLIMIT"
"$IPTABLES" -A OUTPUT -p icmp -m state --state ESTABLISHED -j ACCEPT "$RLIMIT"
"$IPTABLES" -A INPUT -p icmp -m state --state RELATED -j RELATED_ICMP "$RLIMIT"
"$IPTABLES" -A OUTPUT -p icmp -m state --state RELATED -j RELATED_ICMP "$RLIMIT"
"$IPTABLES" -A INPUT -p icmp --icmp-type echo-request -j ACCEPT "$RLIMIT"
"$IPTABLES" -A OUTPUT -p icmp --icmp-type echo-request -j ACCEPT "$RLIMIT"
"$IPTABLES" -A INPUT -p icmp -j DROPLOG
"$IPTABLES" -A OUTPUT -p icmp -j DROPLOG
"$IPTABLES" -A FORWARD -p icmp -j DROPLOG
"$IPTABLES" -A INPUT -i lo -j ACCEPT
"$IPTABLES" -A OUTPUT -o lo -j ACCEPT
"$IPTABLES" -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
"$IPTABLES" -A OUTPUT -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
"$IPTABLES" -A INPUT -p tcp -m multiport --dports 135,137,138,139,445,1433,1434 -j DROP
"$IPTABLES" -A INPUT -p udp -m multiport --dports 135,137,138,139,445,1433,1434 -j DROP
"$IPTABLES" -A INPUT -m state --state INVALID -j DROP
"$IPTABLES" -A OUTPUT -m state --state INVALID -j DROP
"$IPTABLES" -A FORWARD -m state --state INVALID -j DROP
"$IPTABLES" -A INPUT -m state --state NEW -p tcp --tcp-flags ALL ALL -j DROP
"$IPTABLES" -A INPUT -m state --state NEW -p tcp --tcp-flags ALL NONE -j DROP
"$IPTABLES" -N SYN_FLOOD
"$IPTABLES" -A INPUT -p tcp --syn -j SYN_FLOOD
"$IPTABLES" -A SYN_FLOOD -m limit --limit 2/s --limit-burst 6 -j RETURN
"$IPTABLES" -A SYN_FLOOD -j DROP
"$IPTABLES" -A INPUT -s 0.0.0.0/7 -j DROP
"$IPTABLES" -A INPUT -s 2.0.0.0/8 -j DROP
"$IPTABLES" -A INPUT -s 5.0.0.0/8 -j DROP
"$IPTABLES" -A INPUT -s 7.0.0.0/8 -j DROP
"$IPTABLES" -A INPUT -s 10.0.0.0/8 -j DROP
"$IPTABLES" -A INPUT -s 23.0.0.0/8 -j DROP
"$IPTABLES" -A INPUT -s 27.0.0.0/8 -j DROP
"$IPTABLES" -A INPUT -s 31.0.0.0/8 -j DROP
"$IPTABLES" -A INPUT -s 36.0.0.0/7 -j DROP
"$IPTABLES" -A INPUT -s 39.0.0.0/8 -j DROP
"$IPTABLES" -A INPUT -s 42.0.0.0/8 -j DROP
"$IPTABLES" -A INPUT -s 49.0.0.0/8 -j DROP
"$IPTABLES" -A INPUT -s 50.0.0.0/8 -j DROP
"$IPTABLES" -A INPUT -s 77.0.0.0/8 -j DROP
"$IPTABLES" -A INPUT -s 78.0.0.0/7 -j DROP
"$IPTABLES" -A INPUT -s 92.0.0.0/6 -j DROP
"$IPTABLES" -A INPUT -s 96.0.0.0/4 -j DROP
"$IPTABLES" -A INPUT -s 112.0.0.0/5 -j DROP
"$IPTABLES" -A INPUT -s 120.0.0.0/8 -j DROP
"$IPTABLES" -A INPUT -s 169.254.0.0/16 -j DROP
"$IPTABLES" -A INPUT -s 172.16.0.0/12 -j DROP
"$IPTABLES" -A INPUT -s 173.0.0.0/8 -j DROP
"$IPTABLES" -A INPUT -s 174.0.0.0/7 -j DROP
"$IPTABLES" -A INPUT -s 176.0.0.0/5 -j DROP
"$IPTABLES" -A INPUT -s 184.0.0.0/6 -j DROP
"$IPTABLES" -A INPUT -s 192.0.2.0/24 -j DROP
"$IPTABLES" -A INPUT -s 197.0.0.0/8 -j DROP
"$IPTABLES" -A INPUT -s 198.18.0.0/15 -j DROP
"$IPTABLES" -A INPUT -s 223.0.0.0/8 -j DROP
"$IPTABLES" -A INPUT -s 224.0.0.0/3 -j DROP
"$IPTABLES" -A OUTPUT -m state --state NEW -p udp --dport 53 -j ACCEPT
"$IPTABLES" -A OUTPUT -m state --state NEW -p tcp --dport 53 -j ACCEPT
"$IPTABLES" -A OUTPUT -m state --state NEW -p tcp --dport 80 -j ACCEPT
"$IPTABLES" -A OUTPUT -m state --state NEW -p tcp --dport 443 -j ACCEPT
"$IPTABLES" -A OUTPUT -m state --state NEW -p tcp --dport 587 -j ACCEPT
"$IPTABLES" -A OUTPUT -m state --state NEW -p tcp --dport 995 -j ACCEPT
"$IPTABLES" -A OUTPUT -m state --state NEW -p tcp --dport "$SSHPORT" -j ACCEPT
"$IPTABLES" -A OUTPUT -m state --state NEW -p tcp --dport 21 -j ACCEPT
"$IPTABLES" -A OUTPUT -m state --state NEW -p udp --sport 67:68 --dport 67:68 -j ACCEPT
"$IPTABLES" -A OUTPUT -m state --state NEW -p udp --dport 1194 -j ACCEPT
"$IPTABLES" -A INPUT -m state --state NEW -p udp --dport 53 -j ACCEPT
"$IPTABLES" -A INPUT -m state --state NEW -p tcp --dport 53 -j ACCEPT
"$IPTABLES" -A INPUT -m state --state NEW -p tcp --dport 80 -j ACCEPT
"$IPTABLES" -A INPUT -m state --state NEW -p tcp --dport 443 -j ACCEPT
"$IPTABLES" -A INPUT -m state --state NEW -p tcp --dport 110 -j ACCEPT
"$IPTABLES" -A INPUT -m state --state NEW -p tcp --dport 143 -j ACCEPT
"$IPTABLES" -A INPUT -m state --state NEW -p tcp --dport 995 -j ACCEPT
"$IPTABLES" -A INPUT -m state --state NEW -p tcp --dport 25 -j ACCEPT
"$IPTABLES" -A INPUT -m state --state NEW -p tcp --dport "$SSHPORT" -j ACCEPT
"$IPTABLES" -A INPUT -m state --state NEW -p tcp --dport 21 -j ACCEPT
"$IPTABLES" -A INPUT -j REJECTLOG
"$IPTABLES" -A OUTPUT -j REJECTLOG
"$IPTABLES" -A FORWARD -j REJECTLOG
sudo ip6tables -A INPUT -p tcp --dport "$SSHPORT" -s HOST_IPV6_IP -j ACCEPT
sudo ip6tables -A INPUT -p tcp --dport 80 -j ACCEPT
sudo ip6tables -A INPUT -p tcp --dport 21 -j ACCEPT
sudo ip6tables -A INPUT -p tcp --dport 25 -j ACCEPT
sudo ip6tables -L -n --line-numbers
sudo ip6tables -D INPUT -p tcp --dport 21 -j ACCEPT
}
echo -e """
    \033[34m███████\033[35m╗\033[34m██████\033[35m╗ \033[34m██████\033[35m╗  \033[34m██████\033[35m╗ \033[34m████████\033[35m╗
    \033[34m██\033[35m╔════╝\033[34m██\033[35m╔══\033[34m██\033[35m╗\033[34m██\033[35m╔══\033[34m██\033[35m╗\033[34m██\033[35m╔═══\033[34m██\033[35m╗╚══\033[34m██\033[35m╔══╝
    \033[34m███████\033[35m╗\033[34m██████\033[35m╔╝\033[34m██████\033[35m╔╝\033[34m██\033[35m║   \033[34m██\033[35m║   \033[34m██\033[35m║   
    \033[35m╚════\033[34m██\033[35m║\033[34m██\033[35m╔═══╝ \033[34m██\033[35m╔══\033[34m██\033[35m╗\033[34m██\033[35m║   \033[34m██\033[35m║   \033[34m██\033[35m║   
    \033[34m███████\033[35m║\033[34m██\033[35m║     \033[34m██\033[35m║  \033[34m██\033[35m║╚\033[34m██████\033[35m╔╝   \033[34m██\033[35m║   
    \033[35m╚══════╝╚═╝     ╚═╝  ╚═╝ ╚═════╝    ╚═╝    
"""
main "$@"
echo "Testing download speed..."
download_speed
if [[ "$1" == "--set-up" ]]; then
    networking
fi

