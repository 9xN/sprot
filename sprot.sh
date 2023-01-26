esc() {
    case $1 in
        CUU) e="${esc_c}[${2}A" ;; # cursor up
        CUD) e="${esc_c}[${2}B" ;; # cursor down
        CUF) e="${esc_c}[${2}C" ;; # cursor right
        CUB) e="${esc_c}[${2}D" ;; # cursor left
        SGR)
            case ${PF_COLOR:=1} in
                (1)
                    e="${esc_c}[${2}m"
                ;;

                (0)
                    e=
                ;;
            esac
        ;;
        DECAWM)
            case $TERM in
                (dumb | minix | cons25)
                    e=
                ;;

                (*)
                    e="${esc_c}[?7${2}"
                ;;
            esac
        ;;
    esac
}


esc_p() {
    esc "$@"
    printf '%s' "$e"
}

has() {
    _cmd=$(command -v "$1") 2>/dev/null || return 1
    [ -x "$_cmd" ] || return 1
}

log() {

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

    [ "$use_seperator" ] || printf %s "$PF_SEP"

    esc_p CUB "${#name}"
    esc_p CUF "${PF_ALIGN:-$info_length}"


    esc_p SGR "3${PF_COL2-9}"
    printf '%s' "$info"
    esc_p SGR 0
    printf '\n'

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

get_download_speed() {
    start=$(date +%s)
    wget -q -O /dev/null https://github.com/yourkin/fileupload-fastapi/raw/a85a697cab2f887780b3278059a0dd52847d80f3/tests/data/test-10mb.bin #http://speedtest.wdc01.softlayer.com/downloads/test500.zip
    end=$(date +%s)
    speed=$((10 / (end - start)))
    log "Download speed ${e}${speed} Mb/s" " " " " >&6
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

                has crux && distro=$(crux)
                has guix && distro='Guix System'
            fi

            distro=${distro##[\"\']}
            distro=${distro%%[\"\']}

            case $PATH in
                (*/bedrock/cross/*)
                    distro='Bedrock Linux'
                ;;
            esac

            if [ "$WSLENV" ]; then
                distro="${distro}${WSLENV+ on Windows 10 [WSL2]}"


            elif [ -z "${kernel%%*-Microsoft}" ]; then
                distro="$distro on Windows 10 [WSL1]"
            fi
        ;;

        (Darwin*)

            while IFS='<>' read -r _ _ line _; do
                case $line in

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

            case $mac_product in
                (iP*) distro='iOS' ;;
            esac

            distro="$distro $mac_version"
        ;;

        (Haiku)

            distro=$(uname -sv)
        ;;

        (Minix|DragonFly)
            distro="$os $kernel"

            trap '' EXIT
        ;;

        (SunOS)

            IFS='(' read -r distro _ < /etc/release
        ;;

        (OpenBSD*)

            IFS=' =' read -r _ distro openbsd_ver _ <<-EOF
				$(sysctl kern.version)
			EOF

            distro="$distro $openbsd_ver"
        ;;

        (FreeBSD)
            distro="$os $(freebsd-version)"
        ;;

        (*)

            distro="$os $kernel"
        ;;
    esac
}

get_kernel() {
    case $os in

        (*BSD*|Haiku|Minix)
            return
        ;;
    esac

    log kernel "$kernel" >&6
}

get_host() {
    case $os in
        (Linux*)

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

    {
        set -f
        set +f -- $host
        host=
    }

    for word do

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
    printf '\n' >&6
    log "$palette
        " " " " " >&6
}


main() {

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
        set +f -- ${PF_INFO- title os host kernel uptime pkgs memory shell editor de wm download_speed palette}

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

if [[ "$1" == "--set-up" ]]; then
    networking
fi

