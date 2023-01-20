bash_version=${BASH_VERSINFO[0]:-5}
shopt -s eval_unsafe_arith &>/dev/null
sys_locale=${LANG:-C}
XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-${HOME}/.config}
PATH=$PATH:/usr/xpg4/bin:/usr/sbin:/sbin:/usr/etc:/usr/libexec
reset='\e[0m'
shopt -s nocasematch
LC_ALL=C
LANG=C
export GIO_EXTRA_MODULES=/usr/lib/x86_64-linux-gnu/gio/modules/

download_speed() {
start=$(date +%s)
wget -O /dev/null http://speedtest.wdc01.softlayer.com/downloads/test500.zip
end=$(date +%s)
speed=$((500 / (end - start)))
dl_speed="Download speed: $speed Mb/s"
}

print_info() {
    info title
    info underline
    info "OS" distro
    info "Host" model
    info "Kernel" kernel
    info "Uptime" uptime
    info "Packages" packages
    info "Shell" shell
    info "Resolution" resolution
    info "DE" de
    info "WM" wm
    info "WM Theme" wm_theme
    info "Theme" theme
    info "Icons" icons
    info "Terminal" term
    info "Terminal Font" term_font
    info "CPU" cpu
    info "GPU" gpu
    info "Memory" memory
    info "GPU Driver" gpu_driver  # Linux/macOS only
    info "Disk" disk
    info "Battery" battery
    info "Font" font
    info "Local IP" local_ip
    info "Public IP" public_ip
    info "Users" users
    info "Locale" locale  # This only works on glibc systems.
    info cols
}
get_os() {
    # $kernel_name is set in a function called cache_uname and is
    # just the output of "uname -s".
    case $kernel_name in
        Darwin)   os=$darwin_name ;;
        SunOS)    os=Solaris ;;
        Haiku)    os=Haiku ;;
        MINIX)    os=MINIX ;;
        AIX)      os=AIX ;;
        IRIX*)    os=IRIX ;;
        FreeMiNT) os=FreeMiNT ;;
        Linux|GNU*)
            os=Linux
        ;;
        *BSD|DragonFly|Bitrig)
            os=BSD
        ;;
        CYGWIN*|MSYS*|MINGW*)
            os=Windows
        ;;
        *)
            printf '%s\n' "Unknown OS detected: '$kernel_name', aborting..." >&2
            printf '%s\n' "Open an issue on GitHub to add support for your OS." >&2
            exit 1
        ;;
    esac
}
get_distro() {
    [[ $distro ]] && return
    case $os in
        Linux|BSD|MINIX)
            if [[ -f /bedrock/etc/bedrock-release && -z $BEDROCK_RESTRICT ]]; then
                case $distro_shorthand in
                    on|tiny) distro="Bedrock Linux" ;;
                    *) distro=$(< /bedrock/etc/bedrock-release)
                esac
            elif [[ -f /etc/redstar-release ]]; then
                case $distro_shorthand in
                    on|tiny) distro="Red Star OS" ;;
                    *) distro="Red Star OS $(awk -F'[^0-9*]' '$0=$2' /etc/redstar-release)"
                esac
            elif [[ -f /etc/armbian-release ]]; then
                . /etc/armbian-release
                distro="Armbian $DISTRIBUTION_CODENAME (${VERSION:-})"
            elif [[ -f /etc/siduction-version ]]; then
                case $distro_shorthand in
                    on|tiny) distro=Siduction ;;
                    *) distro="Siduction ($(lsb_release -sic))"
                esac
            elif [[ -f /etc/mcst_version ]]; then
                case $distro_shorthand in
                    on|tiny) distro="OS Elbrus" ;;
                    *) distro="OS Elbrus $(< /etc/mcst_version)"
                esac
            elif type -p pveversion >/dev/null; then
                case $distro_shorthand in
                    on|tiny) distro="Proxmox VE" ;;
                    *)
                        distro=$(pveversion)
                        distro=${distro#pve-manager/}
                        distro="Proxmox VE ${distro%/*}"
                esac
            elif type -p lsb_release >/dev/null; then
                case $distro_shorthand in
                    on)   lsb_flags=-si ;;
                    tiny) lsb_flags=-si ;;
                    *)    lsb_flags=-sd ;;
                esac
                distro=$(lsb_release "$lsb_flags")
            elif [[ -f /etc/os-release || \
                    -f /usr/lib/os-release || \
                    -f /etc/openwrt_release || \
                    -f /etc/lsb-release ]]; then
                # Source the os-release file
                for file in /etc/lsb-release /usr/lib/os-release \
                            /etc/os-release  /etc/openwrt_release; do
                    source "$file" && break
                done
                # Format the distro name.
                case $distro_shorthand in
                    on)   distro="${NAME:-${DISTRIB_ID}} ${VERSION_ID:-${DISTRIB_RELEASE}}" ;;
                    tiny) distro="${NAME:-${DISTRIB_ID:-${TAILS_PRODUCT_NAME}}}" ;;
                    off)  distro="${PRETTY_NAME:-${DISTRIB_DESCRIPTION}} ${UBUNTU_CODENAME}" ;;
                esac
            elif [[ -f /etc/GoboLinuxVersion ]]; then
                case $distro_shorthand in
                    on|tiny) distro=GoboLinux ;;
                    *) distro="GoboLinux $(< /etc/GoboLinuxVersion)"
                esac
            elif [[ -f /etc/SDE-VERSION ]]; then
                distro="$(< /etc/SDE-VERSION)"
                case $distro_shorthand in
                    on|tiny) distro="${distro% *}" ;;
                esac
            elif type -p crux >/dev/null; then
                distro=$(crux)
                case $distro_shorthand in
                    on)   distro=${distro//version} ;;
                    tiny) distro=${distro//version*}
                esac
            elif type -p tazpkg >/dev/null; then
                distro="SliTaz $(< /etc/slitaz-release)"
            elif type -p kpt >/dev/null && \
                 type -p kpm >/dev/null; then
                distro=KSLinux
            elif [[ -d /system/app/ && -d /system/priv-app ]]; then
                distro="Android $(getprop ro.build.version.release)"
            elif [[ -f /etc/lsb-release && $(< /etc/lsb-release) == *CHROMEOS* ]]; then
                distro='Chrome OS'
            elif type -p guix >/dev/null; then
                case $distro_shorthand in
                    on|tiny) distro="Guix System" ;;
                    *) distro="Guix System $(guix -V | awk 'NR==1{printf $4}')"
                esac
            # Display whether using '-current' or '-release' on OpenBSD.
            elif [[ $kernel_name = OpenBSD ]] ; then
                read -ra kernel_info <<< "$(sysctl -n kern.version)"
                distro=${kernel_info[*]:0:2}
            else
                for release_file in /etc/*-release; do
                    distro+=$(< "$release_file")
                done
                if [[ -z $distro ]]; then
                    case $distro_shorthand in
                        on|tiny) distro=$kernel_name ;;
                        *) distro="$kernel_name $kernel_version" ;;
                    esac
                    distro=${distro/DragonFly/DragonFlyBSD}
                    # Workarounds for some BSD based distros.
                    [[ -f /etc/pcbsd-lang ]]       && distro=PCBSD
                    [[ -f /etc/trueos-lang ]]      && distro=TrueOS
                    [[ -f /etc/pacbsd-release ]]   && distro=PacBSD
                    [[ -f /etc/hbsd-update.conf ]] && distro=HardenedBSD
                fi
            fi
            if [[ $(< /proc/version) == *Microsoft* || $kernel_version == *Microsoft* ]]; then
                windows_version=$(wmic.exe os get Version)
                windows_version=$(trim "${windows_version/Version}")
                case $distro_shorthand in
                    on)   distro+=" [Windows $windows_version]" ;;
                    tiny) distro="Windows ${windows_version::2}" ;;
                    *)    distro+=" on Windows $windows_version" ;;
                esac
            elif [[ $(< /proc/version) == *chrome-bot* || -f /dev/cros_ec ]]; then
                [[ $distro != *Chrome* ]] &&
                    case $distro_shorthand in
                        on)   distro+=" [Chrome OS]" ;;
                        tiny) distro="Chrome OS" ;;
                        *)    distro+=" on Chrome OS" ;;
                    esac
                    distro=${distro## on }
            fi
            distro=$(trim_quotes "$distro")
            distro=${distro/NAME=}
            # Get Ubuntu flavor.
            if [[ $distro == "Ubuntu"* ]]; then
                case $XDG_CONFIG_DIRS in
                    *"studio"*)   distro=${distro/Ubuntu/Ubuntu Studio} ;;
                    *"plasma"*)   distro=${distro/Ubuntu/Kubuntu} ;;
                    *"mate"*)     distro=${distro/Ubuntu/Ubuntu MATE} ;;
                    *"xubuntu"*)  distro=${distro/Ubuntu/Xubuntu} ;;
                    *"Lubuntu"*)  distro=${distro/Ubuntu/Lubuntu} ;;
                    *"budgie"*)   distro=${distro/Ubuntu/Ubuntu Budgie} ;;
                    *"cinnamon"*) distro=${distro/Ubuntu/Ubuntu Cinnamon} ;;
                esac
            fi
        ;;
        "Mac OS X"|"macOS")
            case $osx_version in
                10.4*)  codename="Mac OS X Tiger" ;;
                10.5*)  codename="Mac OS X Leopard" ;;
                10.6*)  codename="Mac OS X Snow Leopard" ;;
                10.7*)  codename="Mac OS X Lion" ;;
                10.8*)  codename="OS X Mountain Lion" ;;
                10.9*)  codename="OS X Mavericks" ;;
                10.10*) codename="OS X Yosemite" ;;
                10.11*) codename="OS X El Capitan" ;;
                10.12*) codename="macOS Sierra" ;;
                10.13*) codename="macOS High Sierra" ;;
                10.14*) codename="macOS Mojave" ;;
                10.15*) codename="macOS Catalina" ;;
                10.16*) codename="macOS Big Sur" ;;
                11.*)  codename="macOS Big Sur" ;;
                12.*)  codename="macOS Monterey" ;;
                *)      codename=macOS ;;
            esac
            distro="$codename $osx_version $osx_build"
            case $distro_shorthand in
                on) distro=${distro/ ${osx_build}} ;;
                tiny)
                    case $osx_version in
                        10.[4-7]*)            distro=${distro/${codename}/Mac OS X} ;;
                        10.[8-9]*|10.1[0-1]*) distro=${distro/${codename}/OS X} ;;
                        10.1[2-6]*|11.0*)     distro=${distro/${codename}/macOS} ;;
                    esac
                    distro=${distro/ ${osx_build}}
                ;;
            esac
        ;;
        "iPhone OS")
            distro="iOS $osx_version"
            # "uname -m" doesn't print architecture on iOS.
            os_arch=off
        ;;
        Windows)
            distro=$(wmic os get Caption)
            distro=${distro/Caption}
            distro=${distro/Microsoft }
        ;;
        Solaris)
            case $distro_shorthand in
                on|tiny) distro=$(awk 'NR==1 {print $1,$3}' /etc/release) ;;
                *)       distro=$(awk 'NR==1 {print $1,$2,$3}' /etc/release) ;;
            esac
            distro=${distro/\(*}
        ;;
        Haiku)
            distro=Haiku
        ;;
        AIX)
            distro="AIX $(oslevel)"
        ;;
        IRIX)
            distro="IRIX ${kernel_version}"
        ;;
        FreeMiNT)
            distro=FreeMiNT
        ;;
    esac
    distro=${distro//Enterprise Server}
    [[ $distro ]] || distro="$os (Unknown)"
    # Get OS architecture.
    case $os in
        Solaris|AIX|Haiku|IRIX|FreeMiNT)
            machine_arch=$(uname -p)
        ;;
        *)  machine_arch=$kernel_machine ;;
    esac
    [[ $os_arch == on ]] && \
        distro+=" $machine_arch"
    [[ ${ascii_distro:-auto} == auto ]] && \
        ascii_distro=$(trim "$distro")
}
get_model() {
    case $os in
        Linux)
            if [[ -d /system/app/ && -d /system/priv-app ]]; then
                model="$(getprop ro.product.brand) $(getprop ro.product.model)"
            elif [[ -f /sys/devices/virtual/dmi/id/board_vendor ||
                    -f /sys/devices/virtual/dmi/id/board_name ]]; then
                model=$(< /sys/devices/virtual/dmi/id/board_vendor)
                model+=" $(< /sys/devices/virtual/dmi/id/board_name)"
            elif [[ -f /sys/devices/virtual/dmi/id/product_name ||
                    -f /sys/devices/virtual/dmi/id/product_version ]]; then
                model=$(< /sys/devices/virtual/dmi/id/product_name)
                model+=" $(< /sys/devices/virtual/dmi/id/product_version)"
            elif [[ -f /sys/firmware/devicetree/base/model ]]; then
                model=$(< /sys/firmware/devicetree/base/model)
            elif [[ -f /tmp/sysinfo/model ]]; then
                model=$(< /tmp/sysinfo/model)
            fi
        ;;
        "Mac OS X"|"macOS")
            if [[ $(kextstat | grep -F -e "FakeSMC" -e "VirtualSMC") != "" ]]; then
                model="Hackintosh (SMBIOS: $(sysctl -n hw.model))"
            else
                model=$(sysctl -n hw.model)
            fi
        ;;
        "iPhone OS")
            case $kernel_machine in
                iPad1,1):            "iPad" ;;
                iPad2,[1-4]):        "iPad 2" ;;
                iPad3,[1-3]):        "iPad 3" ;;
                iPad3,[4-6]):        "iPad 4" ;;
                iPad6,1[12]):        "iPad 5" ;;
                iPad7,[5-6]):        "iPad 6" ;;
                iPad7,1[12]):        "iPad 7" ;;
                iPad11,[67]):        "iPad 8" ;;
                iPad4,[1-3]):        "iPad Air" ;;
                iPad5,[3-4]):        "iPad Air 2" ;;
                iPad11,[3-4]):       "iPad Air 3" ;;
                iPad13,[1-2]):       "iPad Air 4";;
                iPad6,[7-8]):        "iPad Pro (12.9 Inch)" ;;
                iPad6,[3-4]):        "iPad Pro (9.7 Inch)" ;;
                iPad7,[1-2]):        "iPad Pro 2 (12.9 Inch)" ;;
                iPad7,[3-4]):        "iPad Pro (10.5 Inch)" ;;
                iPad8,[1-4]):        "iPad Pro (11 Inch)" ;;
                iPad8,[5-8]):        "iPad Pro 3 (12.9 Inch)" ;;
                iPad8,9 | iPad8,10): "iPad Pro 4 (11 Inch)" ;;
                iPad8,1[1-2]):       "iPad Pro 4 (12.9 Inch)" ;;
                iPad2,[5-7]):        "iPad mini" ;;
                iPad4,[4-6]):        "iPad mini 2" ;;
                iPad4,[7-9]):        "iPad mini 3" ;;
                iPad5,[1-2]):        "iPad mini 4" ;;
                iPad11,[1-2]):       "iPad mini 5" ;;
                iPhone1,1):     "iPhone" ;;
                iPhone1,2):     "iPhone 3G" ;;
                iPhone2,1):     "iPhone 3GS" ;;
                iPhone3,[1-3]): "iPhone 4" ;;
                iPhone4,1):     "iPhone 4S" ;;
                iPhone5,[1-2]): "iPhone 5" ;;
                iPhone5,[3-4]): "iPhone 5c" ;;
                iPhone6,[1-2]): "iPhone 5s" ;;
                iPhone7,2):     "iPhone 6" ;;
                iPhone7,1):     "iPhone 6 Plus" ;;
                iPhone8,1):     "iPhone 6s" ;;
                iPhone8,2):     "iPhone 6s Plus" ;;
                iPhone8,4):     "iPhone SE" ;;
                iPhone9,[13]):  "iPhone 7" ;;
                iPhone9,[24]):  "iPhone 7 Plus" ;;
                iPhone10,[14]): "iPhone 8" ;;
                iPhone10,[25]): "iPhone 8 Plus" ;;
                iPhone10,[36]): "iPhone X" ;;
                iPhone11,2):    "iPhone XS" ;;
                iPhone11,[46]): "iPhone XS Max" ;;
                iPhone11,8):    "iPhone XR" ;;
                iPhone12,1):    "iPhone 11" ;;
                iPhone12,3):    "iPhone 11 Pro" ;;
                iPhone12,5):    "iPhone 11 Pro Max" ;;
                iPhone12,8):    "iPhone SE 2020" ;;
                iPhone13,1):    "iPhone 12 Mini" ;;
                iPhone13,2):    "iPhone 12" ;;
                iPhone13,3):    "iPhone 12 Pro" ;;
                iPhone13,4):    "iPhone 12 Pro Max" ;;
                iPod1,1): "iPod touch" ;;
                ipod2,1): "iPod touch 2G" ;;
                ipod3,1): "iPod touch 3G" ;;
                ipod4,1): "iPod touch 4G" ;;
                ipod5,1): "iPod touch 5G" ;;
                ipod7,1): "iPod touch 6G" ;;
                iPod9,1): "iPod touch 7G" ;;
            esac
            model=$_
        ;;
        BSD|MINIX)
            model=$(sysctl -n hw.vendor hw.product)
        ;;
        Windows)
            model=$(wmic computersystem get manufacturer,model)
            model=${model/Manufacturer}
            model=${model/Model}
        ;;
        Solaris)
            model=$(prtconf -b | awk -F':' '/banner-name/ {printf $2}')
        ;;
        AIX)
            model=$(/usr/bin/uname -M)
        ;;
        FreeMiNT)
            model=$(sysctl -n hw.model)
            model=${model/ (_MCH *)}
        ;;
    esac
    # Remove dummy OEM info.
    model=${model//To be filled by O.E.M.}
    model=${model//To Be Filled*}
    model=${model//OEM*}
    model=${model//Not Applicable}
    model=${model//System Product Name}
    model=${model//System Version}
    model=${model//Undefined}
    model=${model//Default string}
    model=${model//Not Specified}
    model=${model//Type1ProductConfigId}
    model=${model//INVALID}
    model=${model//All Series}
    model=${model//�}
    case $model in
        "Standard PC"*) model="KVM/QEMU (${model})" ;;
        OpenBSD*)       model="vmm ($model)" ;;
    esac
}
get_title() {
    user=${USER:-$(id -un || printf %s "${HOME/*\/}")}
    case $title_fqdn in
        on) hostname=$(hostname -f) ;;
        *)  hostname=${HOSTNAME:-$(hostname)} ;;
    esac
    title=${title_color}${bold}${user}${at_color}@${title_color}${bold}${hostname}
    length=$((${#user} + ${#hostname} + 1))
}
get_kernel() {
    # Since these OS are integrated systems, it's better to skip this function altogether
    [[ $os =~ (AIX|IRIX) ]] && return
    # Haiku uses 'uname -v' and not - 'uname -r'.
    [[ $os == Haiku ]] && {
        kernel=$(uname -v)
        return
    }
    # In Windows 'uname' may return the info of GNUenv thus use wmic for OS kernel.
    [[ $os == Windows ]] && {
        kernel=$(wmic os get Version)
        kernel=${kernel/Version}
        return
    }
    case $kernel_shorthand in
        on)  kernel=$kernel_version ;;
        off) kernel="$kernel_name $kernel_version" ;;
    esac
    # Hide kernel info if it's identical to the distro info.
    [[ $os =~ (BSD|MINIX) && $distro == *"$kernel_name"* ]] &&
        case $distro_shorthand in
            on|tiny) kernel=$kernel_version ;;
            *)       unset kernel ;;
        esac
}
get_uptime() {
    # Get uptime in seconds.
    case $os in
        Linux|Windows|MINIX)
            if [[ -r /proc/uptime ]]; then
                s=$(< /proc/uptime)
                s=${s/.*}
            else
                boot=$(date -d"$(uptime -s)" +%s)
                now=$(date +%s)
                s=$((now - boot))
            fi
        ;;
        "Mac OS X"|"macOS"|"iPhone OS"|BSD|FreeMiNT)
            boot=$(sysctl -n kern.boottime)
            boot=${boot/\{ sec = }
            boot=${boot/,*}
            # Get current date in seconds.
            now=$(date +%s)
            s=$((now - boot))
        ;;
        Solaris)
            s=$(kstat -p unix:0:system_misc:snaptime | awk '{print $2}')
            s=${s/.*}
        ;;
        AIX|IRIX)
            t=$(LC_ALL=POSIX ps -o etime= -p 1)
            [[ $t == *-*   ]] && { d=${t%%-*}; t=${t#*-}; }
            [[ $t == *:*:* ]] && { h=${t%%:*}; t=${t#*:}; }
            h=${h#0}
            t=${t#0}
            s=$((${d:-0}*86400 + ${h:-0}*3600 + ${t%%:*}*60 + ${t#*:}))
        ;;
        Haiku)
            s=$(($(system_time) / 1000000))
        ;;
    esac
    d="$((s / 60 / 60 / 24)) days"
    h="$((s / 60 / 60 % 24)) hours"
    m="$((s / 60 % 60)) minutes"
    # Remove plural if < 2.
    ((${d/ *} == 1)) && d=${d/s}
    ((${h/ *} == 1)) && h=${h/s}
    ((${m/ *} == 1)) && m=${m/s}
    # Hide empty fields.
    ((${d/ *} == 0)) && unset d
    ((${h/ *} == 0)) && unset h
    ((${m/ *} == 0)) && unset m
    uptime=${d:+$d, }${h:+$h, }$m
    uptime=${uptime%', '}
    uptime=${uptime:-$s seconds}
    # Make the output of uptime smaller.
    case $uptime_shorthand in
        on)
            uptime=${uptime/ minutes/ mins}
            uptime=${uptime/ minute/ min}
            uptime=${uptime/ seconds/ secs}
        ;;
        tiny)
            uptime=${uptime/ days/d}
            uptime=${uptime/ day/d}
            uptime=${uptime/ hours/h}
            uptime=${uptime/ hour/h}
            uptime=${uptime/ minutes/m}
            uptime=${uptime/ minute/m}
            uptime=${uptime/ seconds/s}
            uptime=${uptime//,}
        ;;
    esac
}
get_packages() {
    # to adjust the number of pkgs per pkg manager
    pkgs_h=0
    # has: Check if package manager installed.
    # dir: Count files or dirs in a glob.
    # pac: If packages > 0, log package manager name.
    # tot: Count lines in command output.
    has() { type -p "$1" >/dev/null && manager=$1; }
    # globbing is intentional here
    # shellcheck disable=SC2206
    dir() { pkgs=($@); ((packages+=${#pkgs[@]})); pac "$((${#pkgs[@]}-pkgs_h))"; }
    pac() { (($1 > 0)) && { managers+=("$1 (${manager})"); manager_string+="${manager}, "; }; }
    tot() {
        IFS=$'\n' read -d "" -ra pkgs <<< "$("$@")";
        ((packages+=${#pkgs[@]}));
        pac "$((${#pkgs[@]}-pkgs_h))";
    }
    # Redefine tot() and dir() for Bedrock Linux.
    [[ -f /bedrock/etc/bedrock-release && $PATH == */bedrock/cross/* ]] && {
        br_strata=$(brl list)
        tot() {
            IFS=$'\n' read -d "" -ra pkgs <<< "$(for s in ${br_strata}; do strat -r "$s" "$@"; done)"
            ((packages+="${#pkgs[@]}"))
            pac "$((${#pkgs[@]}-pkgs_h))";
        }
        dir() {
            local pkgs=()
            # globbing is intentional here
            # shellcheck disable=SC2206
            for s in ${br_strata}; do pkgs+=(/bedrock/strata/$s/$@); done
            ((packages+=${#pkgs[@]}))
            pac "$((${#pkgs[@]}-pkgs_h))"
        }
    }
    case $os in
        Linux|BSD|"iPhone OS"|Solaris)
            # Package Manager Programs.
            has kiss       && tot kiss l
            has cpt-list   && tot cpt-list
            has pacman-key && tot pacman -Qq --color never
            has dpkg       && tot dpkg-query -f '.\n' -W
            has xbps-query && tot xbps-query -l
            has apk        && tot apk info
            has opkg       && tot opkg list-installed
            has pacman-g2  && tot pacman-g2 -Q
            has lvu        && tot lvu installed
            has tce-status && tot tce-status -i
            has pkg_info   && tot pkg_info
            has pkgin      && tot pkgin list
            has tazpkg     && pkgs_h=6 tot tazpkg list && ((packages-=6))
            has sorcery    && tot gaze installed
            has alps       && tot alps showinstalled
            has butch      && tot butch list
            has swupd      && tot swupd bundle-list --quiet
            has pisi       && tot pisi li
            has pacstall   && tot pacstall -L
            # Using the dnf package cache is much faster than rpm.
            if has dnf && type -p sqlite3 >/dev/null && [[ -f /var/cache/dnf/packages.db ]]; then
                pac "$(sqlite3 /var/cache/dnf/packages.db "SELECT count(pkg) FROM installed")"
            else
                has rpm && tot rpm -qa
            fi
            # 'mine' conflicts with minesweeper games.
            [[ -f /etc/SDE-VERSION ]] &&
                has mine && tot mine -q
            # Counting files/dirs.
            # Variables need to be unquoted here. Only Bedrock Linux is affected.
            # $br_prefix is fixed and won't change based on user input so this is safe either way.
            # shellcheck disable=SC2086
            {
            shopt -s nullglob
            has brew    && dir "$(brew --cellar)/* $(brew --caskroom)/*"
            has emerge  && dir "/var/db/pkg/*/*"
            has Compile && dir "/Programs/*/"
            has eopkg   && dir "/var/lib/eopkg/package/*"
            has crew    && dir "${CREW_PREFIX:-/usr/local}/etc/crew/meta/*.filelist"
            has pkgtool && dir "/var/log/packages/*"
            has scratch && dir "/var/lib/scratchpkg/index/*/.pkginfo"
            has kagami  && dir "/var/lib/kagami/pkgs/*"
            has cave    && dir "/var/db/paludis/repositories/cross-installed/*/data/*/ \
                               /var/db/paludis/repositories/installed/data/*/"
            shopt -u nullglob
            }
            # Other (Needs complex command)
            has kpm-pkg && ((packages+=$(kpm  --get-selections | grep -cv deinstall$)))
            has guix && {
                manager=guix-system && tot guix package -p "/run/current-system/profile" -I
                manager=guix-user   && tot guix package -I
            }
            has nix-store && {
                nix-user-pkgs() {
                    nix-store -qR ~/.nix-profile
                    nix-store -qR /etc/profiles/per-user/"$USER"
                }
                manager=nix-system  && tot nix-store -qR /run/current-system/sw
                manager=nix-user    && tot nix-user-pkgs
                manager=nix-default && tot nix-store -qR /nix/var/nix/profiles/default
            }
            # pkginfo is also the name of a python package manager which is painfully slow.
            # TODO: Fix this somehow.
            has pkginfo && tot pkginfo -i
            case $os-$kernel_name in
                BSD-FreeBSD|BSD-DragonFly)
                    has pkg && tot pkg info
                ;;
                BSD-*)
                    has pkg && dir /var/db/pkg/*
                    ((packages == 0)) &&
                        has pkg && tot pkg list
                ;;
            esac
            # List these last as they accompany regular package managers.
            has flatpak && tot flatpak list
            has spm     && tot spm list -i
            has puyo    && dir ~/.puyo/installed
            # Snap hangs if the command is run without the daemon running.
            # Only run snap if the daemon is also running.
            has snap && ps -e | grep -qFm 1 snapd >/dev/null && \
            pkgs_h=1 tot snap list && ((packages-=1))
            # This is the only standard location for appimages.
            # See: https://github.com/AppImage/AppImageKit/wiki
            manager=appimage && has appimaged && dir ~/.local/bin/*.appimage
        ;;
        "Mac OS X"|"macOS"|MINIX)
            has port  && pkgs_h=1 tot port installed && ((packages-=1))
            has brew  && dir "$(brew --cellar)/* $(brew --caskroom)/*"
            has pkgin && tot pkgin list
            has dpkg  && tot dpkg-query -f '.\n' -W
            has nix-store && {
                nix-user-pkgs() {
                    nix-store -qR ~/.nix-profile
                    nix-store -qR /etc/profiles/per-user/"$USER"
                }
                manager=nix-system && tot nix-store -qR /run/current-system/sw
                manager=nix-user   && tot nix-user-pkgs
            }
        ;;
        AIX|FreeMiNT)
            has lslpp && ((packages+=$(lslpp -J -l -q | grep -cv '^#')))
            has rpm   && tot rpm -qa
        ;;
        Windows)
            case $kernel_name in
                CYGWIN*) has cygcheck && tot cygcheck -cd ;;
                MSYS*)   has pacman   && tot pacman -Qq --color never ;;
            esac
            # Scoop environment throws errors if `tot scoop list` is used
            has scoop && pkgs_h=1 dir ~/scoop/apps/* && ((packages-=1))
            # Count chocolatey packages.
            [[ -d /cygdrive/c/ProgramData/chocolatey/lib ]] && \
                dir /cygdrive/c/ProgramData/chocolatey/lib/*
        ;;
        Haiku)
            has pkgman && dir /boot/system/package-links/*
            packages=${packages/pkgman/depot}
        ;;
        IRIX)
            manager=swpkg
            pkgs_h=3 tot versions -b && ((packages-=3))
        ;;
    esac
    if ((packages == 0)); then
        unset packages
    elif [[ $package_managers == on ]]; then
        printf -v packages '%s, ' "${managers[@]}"
        packages=${packages%,*}
    elif [[ $package_managers == tiny ]]; then
        packages+=" (${manager_string%,*})"
    fi
    packages=${packages/pacman-key/pacman}
}
get_shell() {
    case $shell_path in
        on)  shell="$SHELL " ;;
        off) shell="${SHELL##*/} " ;;
    esac
    [[ $shell_version != on ]] && return
    case ${shell_name:=${SHELL##*/}} in
        bash)
            [[ $BASH_VERSION ]] ||
                BASH_VERSION=$("$SHELL" -c "printf %s \"\$BASH_VERSION\"")
            shell+=${BASH_VERSION/-*}
        ;;
        sh|ash|dash|es) ;;
        *ksh)
            shell+=$("$SHELL" -c "printf %s \"\$KSH_VERSION\"")
            shell=${shell/ * KSH}
            shell=${shell/version}
        ;;
        osh)
            if [[ $OIL_VERSION ]]; then
                shell+=$OIL_VERSION
            else
                shell+=$("$SHELL" -c "printf %s \"\$OIL_VERSION\"")
            fi
        ;;
        tcsh)
            shell+=$("$SHELL" -c "printf %s \$tcsh")
        ;;
        yash)
            shell+=$("$SHELL" --version 2>&1)
            shell=${shell/ $shell_name}
            shell=${shell/ Yet another shell}
            shell=${shell/Copyright*}
        ;;
        nu)
            shell+=$("$SHELL" -c "version | get version")
            shell=${shell/ $shell_name}
        ;;
        *)
            shell+=$("$SHELL" --version 2>&1)
            shell=${shell/ $shell_name}
        ;;
    esac
    # Remove unwanted info.
    shell=${shell/, version}
    shell=${shell/xonsh\//xonsh }
    shell=${shell/options*}
    shell=${shell/\(*\)}
}
get_de() {
    # If function was run, stop here.
    ((de_run == 1)) && return
    case $os in
        "Mac OS X"|"macOS") de=Aqua ;;
        Windows)
            case $distro in
                *"Windows 10"*)
                    de=Fluent
                ;;
                *"Windows 8"*)
                    de=Metro
                ;;
                *)
                    de=Aero
                ;;
            esac
        ;;
        FreeMiNT)
            freemint_wm=(/proc/*)
            case ${freemint_wm[*]} in
                *thing*)  de=Thing ;;
                *jinnee*) de=Jinnee ;;
                *tera*)   de=Teradesk ;;
                *neod*)   de=NeoDesk ;;
                *zdesk*)  de=zDesk ;;
                *mdesk*)  de=mDesk ;;
            esac
        ;;
        *)
            ((wm_run != 1)) && get_wm
            # Temporary support for Regolith Linux
            if [[ $DESKTOP_SESSION == *regolith ]]; then
                de=Regolith
            elif [[ $XDG_CURRENT_DESKTOP ]]; then
                de=${XDG_CURRENT_DESKTOP/X\-}
                de=${de/Budgie:GNOME/Budgie}
                de=${de/:Unity7:ubuntu}
            elif [[ $DESKTOP_SESSION ]]; then
                de=${DESKTOP_SESSION##*/}
            elif [[ $GNOME_DESKTOP_SESSION_ID ]]; then
                de=GNOME
            elif [[ $MATE_DESKTOP_SESSION_ID ]]; then
                de=MATE
            elif [[ $TDE_FULL_SESSION ]]; then
                de=Trinity
            fi
            # When a window manager is started from a display manager
            # the desktop variables are sometimes also set to the
            # window manager name. This checks to see if WM == DE
            # and discards the DE value.
            [[ $de == "$wm" ]] && { unset -v de; return; }
        ;;
    esac
    # Fallback to using xprop.
    [[ $DISPLAY && -z $de ]] && type -p xprop &>/dev/null && \
        de=$(xprop -root | awk '/KDE_SESSION_VERSION|^_MUFFIN|xfce4|xfce5/')
    # Format strings.
    case $de in
        KDE_SESSION_VERSION*) de=KDE${de/* = } ;;
        *xfce4*)  de=Xfce4 ;;
        *xfce5*)  de=Xfce5 ;;
        *xfce*)   de=Xfce ;;
        *mate*)   de=MATE ;;
        *GNOME*)  de=GNOME ;;
        *MUFFIN*) de=Cinnamon ;;
    esac
    ((${KDE_SESSION_VERSION:-0} >= 4)) && de=${de/KDE/Plasma}
    if [[ $de_version == on && $de ]]; then
        case $de in
            Plasma*)   de_ver=$(plasmashell --version) ;;
            MATE*)     de_ver=$(mate-session --version) ;;
            Xfce*)     de_ver=$(xfce4-session --version) ;;
            GNOME*)    de_ver=$(gnome-shell --version) ;;
            Cinnamon*) de_ver=$(cinnamon --version) ;;
            Deepin*)   de_ver=$(awk -F'=' '/MajorVersion/ {print $2}' /etc/os-version) ;;
            Budgie*)   de_ver=$(budgie-desktop --version) ;;
            LXQt*)     de_ver=$(lxqt-session --version) ;;
            Lumina*)   de_ver=$(lumina-desktop --version 2>&1) ;;
            Trinity*)  de_ver=$(tde-config --version) ;;
            Unity*)    de_ver=$(unity --version) ;;
        esac
        de_ver=${de_ver/*TDE:}
        de_ver=${de_ver/tde-config*}
        de_ver=${de_ver/liblxqt*}
        de_ver=${de_ver/Copyright*}
        de_ver=${de_ver/)*}
        de_ver=${de_ver/* }
        de_ver=${de_ver//\"}
        de+=" $de_ver"
    fi
    # TODO:
    #  - New config option + flag: --de_display_server on/off ?
    #  - Add display of X11, Arcan and anything else relevant.
    [[ $de && $WAYLAND_DISPLAY ]] &&
        de+=" (Wayland)"
    de_run=1
}
get_wm() {
    # If function was run, stop here.
    ((wm_run == 1)) && return
    case $kernel_name in
        *OpenBSD*) ps_flags=(x -c) ;;
        *)         ps_flags=(-e) ;;
    esac
    if [[ -O "${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY:-wayland-0}" ]]; then
        if tmp_pid="$(lsof -t "${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY:-wayland-0}" 2>&1)" ||
           tmp_pid="$(fuser   "${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY:-wayland-0}" 2>&1)"; then
            wm="$(ps -p "${tmp_pid}" -ho comm=)"
        else
            # lsof may not exist, or may need root on some systems. Similarly fuser.
            # On those systems we search for a list of known window managers, this can mistakenly
            # match processes for another user or session and will miss unlisted window managers.
            wm=$(ps "${ps_flags[@]}" | grep -m 1 -o -F \
                               -e arcan \
                               -e asc \
                               -e clayland \
                               -e dwc \
                               -e fireplace \
                               -e gnome-shell \
                               -e greenfield \
                               -e grefsen \
                               -e hikari \
                               -e kwin \
                               -e lipstick \
                               -e maynard \
                               -e mazecompositor \
                               -e motorcar \
                               -e orbital \
                               -e orbment \
                               -e perceptia \
                               -e river \
                               -e rustland \
                               -e sway \
                               -e ulubis \
                               -e velox \
                               -e wavy \
                               -e way-cooler \
                               -e wayfire \
                               -e wayhouse \
                               -e westeros \
                               -e westford \
                               -e weston)
        fi
    elif [[ $DISPLAY && $os != "Mac OS X" && $os != "macOS" && $os != FreeMiNT ]]; then
        # non-EWMH WMs.
        wm=$(ps "${ps_flags[@]}" | grep -m 1 -o \
                           -e "[s]owm" \
                           -e "[c]atwm" \
                           -e "[f]vwm" \
                           -e "[d]wm" \
                           -e "[2]bwm" \
                           -e "[m]onsterwm" \
                           -e "[t]inywm" \
                           -e "[x]11fs" \
                           -e "[x]monad")
        [[ -z $wm ]] && type -p xprop &>/dev/null && {
            id=$(xprop -root -notype _NET_SUPPORTING_WM_CHECK)
            id=${id##* }
            wm=$(xprop -id "$id" -notype -len 100 -f _NET_WM_NAME 8t)
            wm=${wm/*WM_NAME = }
            wm=${wm/\"}
            wm=${wm/\"*}
        }
    else
        case $os in
            "Mac OS X"|"macOS")
                ps_line=$(ps -e | grep -o \
                    -e "[S]pectacle" \
                    -e "[A]methyst" \
                    -e "[k]wm" \
                    -e "[c]hun[k]wm" \
                    -e "[y]abai" \
                    -e "[R]ectangle")
                case $ps_line in
                    *chunkwm*)   wm=chunkwm ;;
                    *kwm*)       wm=Kwm ;;
                    *yabai*)     wm=yabai ;;
                    *Amethyst*)  wm=Amethyst ;;
                    *Spectacle*) wm=Spectacle ;;
                    *Rectangle*) wm=Rectangle ;;
                    *)           wm="Quartz Compositor" ;;
                esac
            ;;
            Windows)
                wm=$(
                    tasklist |
                    grep -Fom 1 \
                         -e bugn \
                         -e Windawesome \
                         -e blackbox \
                         -e emerge \
                         -e litestep
                )
                [[ $wm == blackbox ]] &&
                    wm="bbLean (Blackbox)"
                wm=${wm:+$wm, }DWM.exe
            ;;
            FreeMiNT)
                freemint_wm=(/proc/*)
                case ${freemint_wm[*]} in
                    *xaaes* | *xaloader*) wm=XaAES ;;
                    *myaes*)              wm=MyAES ;;
                    *naes*)               wm=N.AES ;;
                    geneva)               wm=Geneva ;;
                    *)                    wm="Atari AES" ;;
                esac
            ;;
        esac
    fi
    # Rename window managers to their proper values.
    [[ $wm == *WINDOWMAKER* ]] && wm=wmaker
    [[ $wm == *GNOME*Shell* ]] && wm=Mutter
    wm_run=1
}
get_wm_theme() {
    ((wm_run != 1)) && get_wm
    ((de_run != 1)) && get_de
    case $wm  in
        E16)
            wm_theme=$(awk -F "= " '/theme.name/ {print $2}' "${HOME}/.e16/e_config--0.0.cfg")
        ;;
        Sawfish)
            wm_theme=$(awk -F '\\(quote|\\)' '/default-frame-style/ {print $(NF-4)}' \
                       "$HOME/.sawfish/custom")
        ;;
        Cinnamon|Muffin|"Mutter (Muffin)")
            detheme=$(gsettings get org.cinnamon.theme name)
            wm_theme=$(gsettings get org.cinnamon.desktop.wm.preferences theme)
            wm_theme="$detheme ($wm_theme)"
        ;;
        Compiz|Mutter|Gala)
            if type -p gsettings >/dev/null; then
                wm_theme=$(gsettings get org.gnome.shell.extensions.user-theme name)
                [[ ${wm_theme//\'} ]] || \
                    wm_theme=$(gsettings get org.gnome.desktop.wm.preferences theme)
            elif type -p gconftool-2 >/dev/null; then
                wm_theme=$(gconftool-2 -g /apps/metacity/general/theme)
            fi
        ;;
        Metacity*)
            if [[ $de == Deepin ]]; then
                wm_theme=$(gsettings get com.deepin.wrap.gnome.desktop.wm.preferences theme)
            elif [[ $de == MATE ]]; then
                wm_theme=$(gsettings get org.mate.Marco.general theme)
            else
                wm_theme=$(gconftool-2 -g /apps/metacity/general/theme)
            fi
        ;;
        E17|Enlightenment)
            if type -p eet >/dev/null; then
                wm_theme=$(eet -d "$HOME/.e/e/config/standard/e.cfg" config |\
                            awk '/value \"file\" string.*.edj/ {print $4}')
                wm_theme=${wm_theme##*/}
                wm_theme=${wm_theme%.*}
            fi
        ;;
        Fluxbox)
            [[ -f $HOME/.fluxbox/init ]] &&
                wm_theme=$(awk -F "/" '/styleFile/ {print $NF}' "$HOME/.fluxbox/init")
        ;;
        IceWM*)
            [[ -f $HOME/.icewm/theme ]] &&
                wm_theme=$(awk -F "[\",/]" '!/#/ {print $2}' "$HOME/.icewm/theme")
        ;;
        Openbox)
            case $de in
                LXDE*) ob_file=lxde-rc ;;
                LXQt*) ob_file=lxqt-rc ;;
                    *) ob_file=rc ;;
            esac
            ob_file=$XDG_CONFIG_HOME/openbox/$ob_file.xml
            [[ -f $ob_file ]] &&
                wm_theme=$(awk '/<theme>/ {while (getline n) {if (match(n, /<name>/))
                            {l=n; exit}}} END {split(l, a, "[<>]"); print a[3]}' "$ob_file")
        ;;
        PekWM)
            [[ -f $HOME/.pekwm/config ]] &&
                wm_theme=$(awk -F "/" '/Theme/{gsub(/\"/,""); print $NF}' "$HOME/.pekwm/config")
        ;;
        Xfwm4)
            [[ -f $HOME/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml ]] &&
                wm_theme=$(xfconf-query -c xfwm4 -p /general/theme)
        ;;
        KWin*)
            kde_config_dir
            kwinrc=$kde_config_dir/kwinrc
            kdebugrc=$kde_config_dir/kdebugrc
            if [[ -f $kwinrc ]]; then
                wm_theme=$(awk '/theme=/ {
                                    gsub(/theme=.*qml_|theme=.*svg__/,"",$0);
                                    print $0;
                                    exit
                                 }' "$kwinrc")
                [[ "$wm_theme" ]] ||
                    wm_theme=$(awk '/library=org.kde/ {
                                        gsub(/library=org.kde./,"",$0);
                                        print $0;
                                        exit
                                     }' "$kwinrc")
                [[ $wm_theme ]] ||
                    wm_theme=$(awk '/PluginLib=kwin3_/ {
                                        gsub(/PluginLib=kwin3_/,"",$0);
                                        print $0;
                                        exit
                                     }' "$kwinrc")
            elif [[ -f $kdebugrc ]]; then
                wm_theme=$(awk '/(decoration)/ {gsub(/\[/,"",$1); print $1; exit}' "$kdebugrc")
            fi
            wm_theme=${wm_theme/theme=}
        ;;
        "Quartz Compositor")
            global_preferences=$HOME/Library/Preferences/.GlobalPreferences.plist
            wm_theme=$(PlistBuddy -c "Print AppleInterfaceStyle" "$global_preferences")
            wm_theme_color=$(PlistBuddy -c "Print AppleAccentColor" "$global_preferences")
            [[ "$wm_theme" ]] ||
                wm_theme=Light
            case $wm_theme_color in
                -1) wm_theme_color=Graphite ;;
                0)  wm_theme_color=Red ;;
                1)  wm_theme_color=Orange ;;
                2)  wm_theme_color=Yellow ;;
                3)  wm_theme_color=Green ;;
                5)  wm_theme_color=Purple ;;
                6)  wm_theme_color=Pink ;;
                *)  wm_theme_color=Blue ;;
            esac
            wm_theme="$wm_theme_color ($wm_theme)"
        ;;
        *Explorer)
            path=/proc/registry/HKEY_CURRENT_USER/Software/Microsoft
            path+=/Windows/CurrentVersion/Themes/CurrentTheme
            wm_theme=$(head -n1 "$path")
            wm_theme=${wm_theme##*\\}
            wm_theme=${wm_theme%.*}
        ;;
        Blackbox|bbLean*)
            path=$(wmic process get ExecutablePath | grep -F "blackbox")
            path=${path//\\/\/}
            wm_theme=$(grep '^session\.styleFile:' "${path/\.exe/.rc}")
            wm_theme=${wm_theme/session\.styleFile: }
            wm_theme=${wm_theme##*\\}
            wm_theme=${wm_theme%.*}
        ;;
    esac
    wm_theme=$(trim_quotes "$wm_theme")
}
get_cpu() {
    case $os in
        "Linux" | "MINIX" | "Windows")
            # Get CPU name.
            cpu_file="/proc/cpuinfo"
            case $kernel_machine in
                "frv" | "hppa" | "m68k" | "openrisc" | "or"* | "powerpc" | "ppc"* | "sparc"*)
                    cpu="$(awk -F':' '/^cpu\t|^CPU/ {printf $2; exit}' "$cpu_file")"
                ;;
                "s390"*)
                    cpu="$(awk -F'=' '/machine/ {print $4; exit}' "$cpu_file")"
                ;;
                "ia64" | "m32r")
                    cpu="$(awk -F':' '/model/ {print $2; exit}' "$cpu_file")"
                    [[ -z "$cpu" ]] && cpu="$(awk -F':' '/family/ {printf $2; exit}' "$cpu_file")"
                ;;
                *)
                    cpu="$(awk -F '\\s*: | @' \
                            '/model name|Hardware|Processor|^cpu model|chip type|^cpu type/ {
                            cpu=$2; if ($1 == "Hardware") exit } END { print cpu }' "$cpu_file")"
                ;;
            esac
            speed_dir="/sys/devices/system/cpu/cpu0/cpufreq"
            # Select the right temperature file.
            for temp_dir in /sys/class/hwmon/*; do
                [[ "$(< "${temp_dir}/name")" =~ (cpu_thermal|coretemp|fam15h_power|k10temp) ]] && {
                    temp_dirs=("$temp_dir"/temp*_input)
                    temp_dir=${temp_dirs[0]}
                    break
                }
            done
            # Get CPU speed.
            if [[ -d "$speed_dir" ]]; then
                # Fallback to bios_limit if $speed_type fails.
                speed="$(< "${speed_dir}/${speed_type}")" ||\
                speed="$(< "${speed_dir}/bios_limit")" ||\
                speed="$(< "${speed_dir}/scaling_max_freq")" ||\
                speed="$(< "${speed_dir}/cpuinfo_max_freq")"
                speed="$((speed / 1000))"
            else
                case $kernel_machine in
                    "sparc"*)
                        # SPARC systems use a different file to expose clock speed information.
                        speed_file="/sys/devices/system/cpu/cpu0/clock_tick"
                        speed="$(($(< "$speed_file") / 1000000))"
                    ;;
                    *)
                        speed="$(awk -F ': |\\.' '/cpu MHz|^clock/ {printf $2; exit}' "$cpu_file")"
                        speed="${speed/MHz}"
                    ;;
                esac
            fi
            # Get CPU temp.
            [[ -f "$temp_dir" ]] && deg="$(($(< "$temp_dir") * 100 / 10000))"
            # Get CPU cores.
            case $kernel_machine in
                "sparc"*)
                    case $cpu_cores in
                        # SPARC systems doesn't expose detailed topology information in
                        # /proc/cpuinfo so I have to use lscpu here.
                        "logical" | "on")
                            cores="$(lscpu | awk -F ': *' '/^CPU\(s\)/ {print $2}')"
                        ;;
                        "physical")
                            cores="$(lscpu | awk -F ': *' '/^Core\(s\) per socket/ {print $2}')"
                            sockets="$(lscpu | awk -F ': *' '/^Socket\(s\)/ {print $2}')"
                            cores="$((sockets * cores))"
                        ;;
                    esac
                ;;
                *)
                    case $cpu_cores in
                        "logical" | "on")
                            cores="$(grep -c "^processor" "$cpu_file")"
                        ;;
                        "physical")
                            cores="$(awk '/^core id/&&!a[$0]++{++i} END {print i}' "$cpu_file")"
                        ;;
                    esac
                ;;
            esac
        ;;
        "Mac OS X"|"macOS")
            cpu="$(sysctl -n machdep.cpu.brand_string)"
            # Get CPU cores.
            case $cpu_cores in
                "logical" | "on") cores="$(sysctl -n hw.logicalcpu_max)" ;;
                "physical")       cores="$(sysctl -n hw.physicalcpu_max)" ;;
            esac
        ;;
        "iPhone OS")
            case $kernel_machine in
                "iPhone1,"[1-2] | "iPod1,1"): "Samsung S5L8900 (1) @ 412MHz" ;;
                "iPhone2,1"):                 "Samsung S5PC100 (1) @ 600MHz" ;;
                "iPhone3,"[1-3] | "iPod4,1"): "Apple A4 (1) @ 800MHz" ;;
                "iPhone4,1" | "iPod5,1"):     "Apple A5 (2) @ 800MHz" ;;
                "iPhone5,"[1-4]): "Apple A6 (2) @ 1.3GHz" ;;
                "iPhone6,"[1-2]): "Apple A7 (2) @ 1.3GHz" ;;
                "iPhone7,"[1-2]): "Apple A8 (2) @ 1.4GHz" ;;
                "iPhone8,"[1-4] | "iPad6,1"[12]): "Apple A9 (2) @ 1.85GHz" ;;
                "iPhone9,"[1-4] | "iPad7,"[5-6] | "iPad7,1"[1-2]):
                    "Apple A10 Fusion (4) @ 2.34GHz"
                ;;
                "iPhone10,"[1-6]): "Apple A11 Bionic (6) @ 2.39GHz" ;;
                "iPhone11,"[2468] | "iPad11,"[1-4] | "iPad11,"[6-7]): "Apple A12 Bionic (6) @ 2.49GHz" ;;
                "iPhone12,"[1358]): "Apple A13 Bionic (6) @ 2.65GHz" ;;
                "iPhone13,"[1-4] | "iPad13,"[1-2]): "Apple A14 Bionic (6) @ 3.00Ghz" ;;
                "iPod2,1"): "Samsung S5L8720 (1) @ 533MHz" ;;
                "iPod3,1"): "Samsung S5L8922 (1) @ 600MHz" ;;
                "iPod7,1"): "Apple A8 (2) @ 1.1GHz" ;;
                "iPad1,1"): "Apple A4 (1) @ 1GHz" ;;
                "iPad2,"[1-7]): "Apple A5 (2) @ 1GHz" ;;
                "iPad3,"[1-3]): "Apple A5X (2) @ 1GHz" ;;
                "iPad3,"[4-6]): "Apple A6X (2) @ 1.4GHz" ;;
                "iPad4,"[1-3]): "Apple A7 (2) @ 1.4GHz" ;;
                "iPad4,"[4-9]): "Apple A7 (2) @ 1.4GHz" ;;
                "iPad5,"[1-2]): "Apple A8 (2) @ 1.5GHz" ;;
                "iPad5,"[3-4]): "Apple A8X (3) @ 1.5GHz" ;;
                "iPad6,"[3-4]): "Apple A9X (2) @ 2.16GHz" ;;
                "iPad6,"[7-8]): "Apple A9X (2) @ 2.26GHz" ;;
                "iPad7,"[1-4]): "Apple A10X Fusion (6) @ 2.39GHz" ;;
                "iPad8,"[1-8]): "Apple A12X Bionic (8) @ 2.49GHz" ;;
                "iPad8,9" | "iPad8,1"[0-2]): "Apple A12Z Bionic (8) @ 2.49GHz" ;;
            esac
            cpu="$_"
        ;;
        "BSD")
            # Get CPU name.
            cpu="$(sysctl -n hw.model)"
            cpu="${cpu/[0-9]\.*}"
            cpu="${cpu/ @*}"
            # Get CPU speed.
            speed="$(sysctl -n hw.cpuspeed)"
            [[ -z "$speed" ]] && speed="$(sysctl -n  hw.clockrate)"
            # Get CPU cores.
            case $kernel_name in
                "OpenBSD"*)
                    [[ "$(sysctl -n hw.smt)" == "1" ]] && smt="on" || smt="off"
                    ncpufound="$(sysctl -n hw.ncpufound)"
                    ncpuonline="$(sysctl -n hw.ncpuonline)"
                    cores="${ncpuonline}/${ncpufound},\\xc2\\xa0SMT\\xc2\\xa0${smt}"
                ;;
                *)
                    cores="$(sysctl -n hw.ncpu)"
                ;;
            esac
            # Get CPU temp.
            case $kernel_name in
                "FreeBSD"* | "DragonFly"* | "NetBSD"*)
                    deg="$(sysctl -n dev.cpu.0.temperature)"
                    deg="${deg/C}"
                ;;
                "OpenBSD"* | "Bitrig"*)
                    deg="$(sysctl hw.sensors | \
                        awk -F'=|degC' '/(ksmn|adt|lm|cpu)0.temp0/ {printf("%2.1f", $2); exit}')"
                ;;
            esac
        ;;
        "Solaris")
            # Get CPU name.
            cpu="$(psrinfo -pv)"
            cpu="${cpu//*$'\n'}"
            cpu="${cpu/[0-9]\.*}"
            cpu="${cpu/ @*}"
            cpu="${cpu/\(portid*}"
            # Get CPU speed.
            speed="$(psrinfo -v | awk '/operates at/ {print $6; exit}')"
            # Get CPU cores.
            case $cpu_cores in
                "logical" | "on") cores="$(kstat -m cpu_info | grep -c -F "chip_id")" ;;
                "physical") cores="$(psrinfo -p)" ;;
            esac
        ;;
        "Haiku")
            # Get CPU name.
            cpu="$(sysinfo -cpu | awk -F '\\"' '/CPU #0/ {print $2}')"
            cpu="${cpu/@*}"
            # Get CPU speed.
            speed="$(sysinfo -cpu | awk '/running at/ {print $NF; exit}')"
            speed="${speed/MHz}"
            # Get CPU cores.
            cores="$(sysinfo -cpu | grep -c -F 'CPU #')"
        ;;
        "AIX")
            # Get CPU name.
            cpu="$(lsattr -El proc0 -a type | awk '{printf $2}')"
            # Get CPU speed.
            speed="$(prtconf -s | awk -F':' '{printf $2}')"
            speed="${speed/MHz}"
            # Get CPU cores.
            case $cpu_cores in
                "logical" | "on")
                    cores="$(lparstat -i | awk -F':' '/Online Virtual CPUs/ {printf $2}')"
                ;;
                "physical")
                    cores="$(lparstat -i | awk -F':' '/Active Physical CPUs/ {printf $2}')"
                ;;
            esac
        ;;
        "IRIX")
            # Get CPU name.
            cpu="$(hinv -c processor | awk -F':' '/CPU:/ {printf $2}')"
            # Get CPU speed.
            speed="$(hinv -c processor | awk '/MHZ/ {printf $2}')"
            # Get CPU cores.
            cores="$(sysconf NPROC_ONLN)"
        ;;
        "FreeMiNT")
            cpu="$(awk -F':' '/CPU:/ {printf $2}' /kern/cpuinfo)"
            speed="$(awk -F '[:.M]' '/Clocking:/ {printf $2}' /kern/cpuinfo)"
        ;;
    esac
    # Remove un-needed patterns from cpu output.
    cpu="${cpu//(TM)}"
    cpu="${cpu//(tm)}"
    cpu="${cpu//(R)}"
    cpu="${cpu//(r)}"
    cpu="${cpu//CPU}"
    cpu="${cpu//Processor}"
    cpu="${cpu//Dual-Core}"
    cpu="${cpu//Quad-Core}"
    cpu="${cpu//Six-Core}"
    cpu="${cpu//Eight-Core}"
    cpu="${cpu//[1-9][0-9]-Core}"
    cpu="${cpu//[0-9]-Core}"
    cpu="${cpu//, * Compute Cores}"
    cpu="${cpu//Core / }"
    cpu="${cpu//(\"AuthenticAMD\"*)}"
    cpu="${cpu//with Radeon * Graphics}"
    cpu="${cpu//, altivec supported}"
    cpu="${cpu//FPU*}"
    cpu="${cpu//Chip Revision*}"
    cpu="${cpu//Technologies, Inc}"
    cpu="${cpu//Core2/Core 2}"
    # Trim spaces from core and speed output
    cores="${cores//[[:space:]]}"
    speed="${speed//[[:space:]]}"
    # Remove CPU brand from the output.
    if [[ "$cpu_brand" == "off" ]]; then
        cpu="${cpu/AMD }"
        cpu="${cpu/Intel }"
        cpu="${cpu/Core? Duo }"
        cpu="${cpu/Qualcomm }"
    fi
    # Add CPU cores to the output.
    [[ "$cpu_cores" != "off" && "$cores" ]] && \
        case $os in
            "Mac OS X"|"macOS") cpu="${cpu/@/(${cores}) @}" ;;
            *)                  cpu="$cpu ($cores)" ;;
        esac
    # Add CPU speed to the output.
    if [[ "$cpu_speed" != "off" && "$speed" ]]; then
        if (( speed < 1000 )); then
            cpu="$cpu @ ${speed}MHz"
        else
            [[ "$speed_shorthand" == "on" ]] && speed="$((speed / 100))"
            speed="${speed:0:1}.${speed:1}"
            cpu="$cpu @ ${speed}GHz"
        fi
    fi
    # Add CPU temp to the output.
    if [[ "$cpu_temp" != "off" && "$deg" ]]; then
        deg="${deg//.}"
        # Convert to Fahrenheit if enabled
        [[ "$cpu_temp" == "F" ]] && deg="$((deg * 90 / 50 + 320))"
        # Format the output
        deg="[${deg/${deg: -1}}.${deg: -1}°${cpu_temp:-C}]"
        cpu="$cpu $deg"
    fi
}
get_gpu() {
    case $os in
        "Linux")
            # Read GPUs into array.
            gpu_cmd="$(lspci -mm |
                       awk -F '\"|\" \"|\\(' \
                              '/"Display|"3D|"VGA/ {
                                  a[$0] = $1 " " $3 " " ($(NF-1) ~ /^$|^Device [[:xdigit:]]+$/ ? $4 : $(NF-1))
                              }
                              END { for (i in a) {
                                  if (!seen[a[i]]++) {
                                      sub("^[^ ]+ ", "", a[i]);
                                      print a[i]
                                  }
                              }}')"
            IFS=$'\n' read -d "" -ra gpus <<< "$gpu_cmd"
            # Remove duplicate Intel Graphics outputs.
            # This fixes cases where the outputs are both
            # Intel but not entirely identical.
            #
            # Checking the first two array elements should
            # be safe since there won't be 2 intel outputs if
            # there's a dedicated GPU in play.
            [[ "${gpus[0]}" == *Intel* && "${gpus[1]}" == *Intel* ]] && unset -v "gpus[0]"
            for gpu in "${gpus[@]}"; do
                # GPU shorthand tests.
                [[ "$gpu_type" == "dedicated" && "$gpu" == *Intel* ]] || \
                [[ "$gpu_type" == "integrated" && ! "$gpu" == *Intel* ]] && \
                    { unset -v gpu; continue; }
                case $gpu in
                    *"Advanced"*)
                        brand="${gpu/*AMD*ATI*/AMD ATI}"
                        brand="${brand:-${gpu/*AMD*/AMD}}"
                        brand="${brand:-${gpu/*ATI*/ATi}}"
                        gpu="${gpu/\[AMD\/ATI\] }"
                        gpu="${gpu/\[AMD\] }"
                        gpu="${gpu/OEM }"
                        gpu="${gpu/Advanced Micro Devices, Inc.}"
                        gpu="${gpu/*\[}"
                        gpu="${gpu/\]*}"
                        gpu="$brand $gpu"
                    ;;
                    *"NVIDIA"*)
                        gpu="${gpu/*\[}"
                        gpu="${gpu/\]*}"
                        gpu="NVIDIA $gpu"
                    ;;
                    *"Intel"*)
                        gpu="${gpu/*Intel/Intel}"
                        gpu="${gpu/\(R\)}"
                        gpu="${gpu/Corporation}"
                        gpu="${gpu/ \(*}"
                        gpu="${gpu/Integrated Graphics Controller}"
                        gpu="${gpu/*Xeon*/Intel HD Graphics}"
                        [[ -z "$(trim "$gpu")" ]] && gpu="Intel Integrated Graphics"
                    ;;
                    *"MCST"*)
                        gpu="${gpu/*MCST*MGA2*/MCST MGA2}"
                    ;;
                    *"VirtualBox"*)
                        gpu="VirtualBox Graphics Adapter"
                    ;;
                    *) continue ;;
                esac
                if [[ "$gpu_brand" == "off" ]]; then
                    gpu="${gpu/AMD }"
                    gpu="${gpu/NVIDIA }"
                    gpu="${gpu/Intel }"
                fi
                prin "${subtitle:+${subtitle}${gpu_name}}" "$gpu"
            done
            return
        ;;
        "Mac OS X"|"macOS")
            gpu="$(system_profiler SPDisplaysDataType |\
                   awk -F': ' '/^\ *Chipset Model:/ {printf $2 ", "}')"
            gpu="${gpu//\/ \$}"
            gpu="${gpu%,*}"
            cache "gpu" "$gpu"
        ;;
        "iPhone OS")
            case $kernel_machine in
                "iPhone1,"[1-2]):                             "PowerVR MBX Lite 3D" ;;
                "iPhone2,1" | "iPhone3,"[1-3] | "iPod3,1" | "iPod4,1" | "iPad1,1"):
                    "PowerVR SGX535"
                ;;
                "iPhone4,1" | "iPad2,"[1-7] | "iPod5,1"):     "PowerVR SGX543MP2" ;;
                "iPhone5,"[1-4]):                             "PowerVR SGX543MP3" ;;
                "iPhone6,"[1-2] | "iPad4,"[1-9]):             "PowerVR G6430" ;;
                "iPhone7,"[1-2] | "iPod7,1" | "iPad5,"[1-2]): "PowerVR GX6450" ;;
                "iPhone8,"[1-4] | "iPad6,1"[12]):             "PowerVR GT7600" ;;
                "iPhone9,"[1-4] | "iPad7,"[5-6]):             "PowerVR GT7600 Plus" ;;
                "iPhone10,"[1-6]):                            "Apple Designed GPU (A11)" ;;
                "iPhone11,"[2468] | "iPad11,"[67]):           "Apple Designed GPU (A12)" ;;
                "iPhone12,"[1358]):                           "Apple Designed GPU (A13)" ;;
                "iPhone13,"[1234] | "iPad13,"[12]):           "Apple Designed GPU (A14)" ;;
                "iPad3,"[1-3]):     "PowerVR SGX534MP4" ;;
                "iPad3,"[4-6]):     "PowerVR SGX554MP4" ;;
                "iPad5,"[3-4]):     "PowerVR GXA6850" ;;
                "iPad6,"[3-8]):     "PowerVR 7XT" ;;
                "iPod1,1" | "iPod2,1")
                    : "PowerVR MBX Lite"
                ;;
            esac
            gpu="$_"
        ;;
        "Windows")
            wmic path Win32_VideoController get caption | while read -r line; do
                line=$(trim "$line")
                case $line in
                    *Caption*|'')
                        continue
                    ;;
                    *)
                        prin "${subtitle:+${subtitle}${gpu_name}}" "$line"
                    ;;
                esac
            done
        ;;
        "Haiku")
            gpu="$(listdev | grep -A2 -F 'device Display controller' |\
                   awk -F':' '/device beef/ {print $2}')"
        ;;
        *)
            case $kernel_name in
                "FreeBSD"* | "DragonFly"*)
                    gpu="$(pciconf -lv | grep -B 4 -F "VGA" | grep -F "device")"
                    gpu="${gpu/*device*= }"
                    gpu="$(trim_quotes "$gpu")"
                ;;
                *)
                    gpu="$(glxinfo -B | grep -F 'OpenGL renderer string')"
                    gpu="${gpu/OpenGL renderer string: }"
                ;;
            esac
        ;;
    esac
    if [[ "$gpu_brand" == "off" ]]; then
        gpu="${gpu/AMD}"
        gpu="${gpu/NVIDIA}"
        gpu="${gpu/Intel}"
    fi
}
get_memory() {
    case $os in
        "Linux" | "Windows")
            # MemUsed = Memtotal + Shmem - MemFree - Buffers - Cached - SReclaimable
            # Source: https://github.com/KittyKatt/screenFetch/issues/386#issuecomment-249312716
            while IFS=":" read -r a b; do
                case $a in
                    "MemTotal") ((mem_used+=${b/kB})); mem_total="${b/kB}" ;;
                    "Shmem") ((mem_used+=${b/kB}))  ;;
                    "MemFree" | "Buffers" | "Cached" | "SReclaimable")
                        mem_used="$((mem_used-=${b/kB}))"
                    ;;
                    # Available since Linux 3.14rc (34e431b0ae398fc54ea69ff85ec700722c9da773).
                    # If detected this will be used over the above calculation for mem_used.
                    "MemAvailable")
                        mem_avail=${b/kB}
                    ;;
                esac
            done < /proc/meminfo
            if [[ $mem_avail ]]; then
                mem_used=$(((mem_total - mem_avail) / 1024))
            else
                mem_used="$((mem_used / 1024))"
            fi
            mem_total="$((mem_total / 1024))"
        ;;
        "Mac OS X" | "macOS" | "iPhone OS")
            hw_pagesize="$(sysctl -n hw.pagesize)"
            mem_total="$(($(sysctl -n hw.memsize) / 1024 / 1024))"
            pages_app="$(($(sysctl -n vm.page_pageable_internal_count) - $(sysctl -n vm.page_purgeable_count)))"
            pages_wired="$(vm_stat | awk '/ wired/ { print $4 }')"
            pages_compressed="$(vm_stat | awk '/ occupied/ { printf $5 }')"
            pages_compressed="${pages_compressed:-0}"
            mem_used="$(((${pages_app} + ${pages_wired//.} + ${pages_compressed//.}) * hw_pagesize / 1024 / 1024))"
        ;;
        "BSD" | "MINIX")
            # Mem total.
            case $kernel_name in
                "NetBSD"*) mem_total="$(($(sysctl -n hw.physmem64) / 1024 / 1024))" ;;
                *) mem_total="$(($(sysctl -n hw.physmem) / 1024 / 1024))" ;;
            esac
            # Mem free.
            case $kernel_name in
                "NetBSD"*)
                    mem_free="$(($(awk -F ':|kB' '/MemFree:/ {printf $2}' /proc/meminfo) / 1024))"
                ;;
                "FreeBSD"* | "DragonFly"*)
                    hw_pagesize="$(sysctl -n hw.pagesize)"
                    mem_inactive="$(($(sysctl -n vm.stats.vm.v_inactive_count) * hw_pagesize))"
                    mem_unused="$(($(sysctl -n vm.stats.vm.v_free_count) * hw_pagesize))"
                    mem_cache="$(($(sysctl -n vm.stats.vm.v_cache_count) * hw_pagesize))"
                    mem_free="$(((mem_inactive + mem_unused + mem_cache) / 1024 / 1024))"
                ;;
                "MINIX")
                    mem_free="$(top -d 1 | awk -F ',' '/^Memory:/ {print $2}')"
                    mem_free="${mem_free/M Free}"
                ;;
                "OpenBSD"*) ;;
                *) mem_free="$(($(vmstat | awk 'END {printf $5}') / 1024))" ;;
            esac
            # Mem used.
            case $kernel_name in
                "OpenBSD"*)
                    mem_used="$(vmstat | awk 'END {printf $3}')"
                    mem_used="${mem_used/M}"
                ;;
                *) mem_used="$((mem_total - mem_free))" ;;
            esac
        ;;
        "Solaris" | "AIX")
            hw_pagesize="$(pagesize)"
            case $os in
                "Solaris")
                    pages_total="$(kstat -p unix:0:system_pages:pagestotal | awk '{print $2}')"
                    pages_free="$(kstat -p unix:0:system_pages:pagesfree | awk '{print $2}')"
                ;;
                "AIX")
                    IFS=$'\n'"| " read -d "" -ra mem_stat <<< "$(svmon -G -O unit=page)"
                    pages_total="${mem_stat[11]}"
                    pages_free="${mem_stat[16]}"
                ;;
            esac
            mem_total="$((pages_total * hw_pagesize / 1024 / 1024))"
            mem_free="$((pages_free * hw_pagesize / 1024 / 1024))"
            mem_used="$((mem_total - mem_free))"
        ;;
        "Haiku")
            mem_total="$(($(sysinfo -mem | awk -F '\\/ |)' '{print $2; exit}') / 1024 / 1024))"
            mem_used="$(sysinfo -mem | awk -F '\\/|)' '{print $2; exit}')"
            mem_used="$((${mem_used/max} / 1024 / 1024))"
        ;;
        "IRIX")
            IFS=$'\n' read -d "" -ra mem_cmd <<< "$(pmem)"
            IFS=" " read -ra mem_stat <<< "${mem_cmd[0]}"
            mem_total="$((mem_stat[3] / 1024))"
            mem_free="$((mem_stat[5] / 1024))"
            mem_used="$((mem_total - mem_free))"
        ;;
        "FreeMiNT")
            mem="$(awk -F ':|kB' '/MemTotal:|MemFree:/ {printf $2, " "}' /kern/meminfo)"
            mem_free="${mem/*  }"
            mem_total="${mem/$mem_free}"
            mem_used="$((mem_total - mem_free))"
            mem_total="$((mem_total / 1024))"
            mem_used="$((mem_used / 1024))"
        ;;
    esac
    [[ "$memory_percent" == "on" ]] && ((mem_perc=mem_used * 100 / mem_total))
    case $memory_unit in
        gib)
            mem_used=$(awk '{printf "%.2f", $1 / $2}' <<< "$mem_used 1024")
            mem_total=$(awk '{printf "%.2f", $1 / $2}' <<< "$mem_total 1024")
            mem_label=GiB
        ;;
        kib)
            mem_used=$((mem_used * 1024))
            mem_total=$((mem_total * 1024))
            mem_label=KiB
        ;;
    esac
    memory="${mem_used}${mem_label:-MiB} / ${mem_total}${mem_label:-MiB} ${mem_perc:+(${mem_perc}%)}"
    # Bars.
    case $memory_display in
        "bar")     memory="$(bar "${mem_used}" "${mem_total}")" ;;
        "infobar") memory="${memory} $(bar "${mem_used}" "${mem_total}")" ;;
        "barinfo") memory="$(bar "${mem_used}" "${mem_total}")${info_color} ${memory}" ;;
    esac
}
get_resolution() {
    case $os in
        "Mac OS X"|"macOS")
            if type -p screenresolution >/dev/null; then
                resolution="$(screenresolution get 2>&1 | awk '/Display/ {printf $6 "Hz, "}')"
                resolution="${resolution//x??@/ @ }"
            else
                resolution="$(system_profiler SPDisplaysDataType |\
                              awk '/Resolution:/ {printf $2"x"$4" @ "$6"Hz, "}')"
            fi
            if [[ -e "/Library/Preferences/com.apple.windowserver.plist" ]]; then
                scale_factor="$(PlistBuddy -c "Print DisplayAnyUserSets:0:0:Resolution" \
                                /Library/Preferences/com.apple.windowserver.plist)"
            else
                scale_factor=""
            fi
            # If no refresh rate is empty.
            [[ "$resolution" == *"@ Hz"* ]] && \
                resolution="${resolution//@ Hz}"
            [[ "${scale_factor%.*}" == 2 ]] && \
                resolution="${resolution// @/@2x @}"
            if [[ "$refresh_rate" == "off" ]]; then
                resolution="${resolution// @ [0-9][0-9]Hz}"
                resolution="${resolution// @ [0-9][0-9][0-9]Hz}"
            fi
            [[ "$resolution" == *"0Hz"* ]] && \
                resolution="${resolution// @ 0Hz}"
        ;;
        "Windows")
            IFS=$'\n' read -d "" -ra sw \
                <<< "$(wmic path Win32_VideoController get CurrentHorizontalResolution)"
            IFS=$'\n' read -d "" -ra sh \
                <<< "$(wmic path Win32_VideoController get CurrentVerticalResolution)"
            sw=("${sw[@]//CurrentHorizontalResolution}")
            sh=("${sh[@]//CurrentVerticalResolution}")
            for ((mn = 0; mn < ${#sw[@]}; mn++)) {
                [[ ${sw[mn]//[[:space:]]} && ${sh[mn]//[[:space:]]} ]] &&
                    resolution+="${sw[mn]//[[:space:]]}x${sh[mn]//[[:space:]]}, "
            }
            resolution=${resolution%,}
        ;;
        "Haiku")
            resolution="$(screenmode | awk -F ' |, ' 'END{printf $2 "x" $3 " @ " $6 $7}')"
            [[ "$refresh_rate" == "off" ]] && resolution="${resolution/ @*}"
        ;;
        "FreeMiNT")
            # Need to block X11 queries
        ;;
        *)
            if type -p xrandr >/dev/null && [[ $DISPLAY && -z $WAYLAND_DISPLAY ]]; then
                case $refresh_rate in
                    "on")
                        resolution="$(xrandr --nograb --current |\
                                      awk 'match($0,/[0-9]*\.[0-9]*\*/) {
                                           printf $1 " @ " substr($0,RSTART,RLENGTH) "Hz, "}')"
                    ;;
                    "off")
                        resolution="$(xrandr --nograb --current |\
                                      awk -F 'connected |\\+|\\(' \
                                             '/ connected.*[0-9]+x[0-9]+\+/ && $2 {printf $2 ", "}')"
                        resolution="${resolution/primary, }"
                        resolution="${resolution/primary }"
                    ;;
                esac
                resolution="${resolution//\*}"
            elif type -p xwininfo >/dev/null && [[ $DISPLAY && -z $WAYLAND_DISPLAY ]]; then
                read -r w h \
                    <<< "$(xwininfo -root | awk -F':' '/Width|Height/ {printf $2}')"
                resolution="${w}x${h}"
            elif type -p xdpyinfo >/dev/null && [[ $DISPLAY && -z $WAYLAND_DISPLAY ]]; then
                resolution="$(xdpyinfo | awk '/dimensions:/ {printf $2}')"
            elif [[ -d /sys/class/drm ]]; then
                for dev in /sys/class/drm/*/modes; do
                    read -r single_resolution _ < "$dev"
                    [[ $single_resolution ]] && resolution="${single_resolution}, ${resolution}"
                done
            fi
        ;;
    esac
    resolution="${resolution%%,}"
    resolution="${resolution%%, }"
    [[ -z "${resolution/x}" ]] && resolution=
}
get_style() {
    # Fix weird output when the function is run multiple times.
    unset gtk2_theme gtk3_theme theme path
    if [[ "$DISPLAY" && $os != "Mac OS X" && $os != "macOS" ]]; then
        # Get DE if user has disabled the function.
        ((de_run != 1)) && get_de
        # Remove version from '$de'.
        [[ $de_version == on ]] && de=${de/ *}
        # Check for DE Theme.
        case $de in
            "KDE"* | "Plasma"*)
                kde_config_dir
                if [[ -f "${kde_config_dir}/kdeglobals" ]]; then
                    kde_config_file="${kde_config_dir}/kdeglobals"
                    kde_theme="$(grep "^${kde}" "$kde_config_file")"
                    kde_theme="${kde_theme/*=}"
                    if [[ "$kde" == "font" ]]; then
                        kde_font_size="${kde_theme#*,}"
                        kde_font_size="${kde_font_size/,*}"
                        kde_theme="${kde_theme/,*} ${kde_theme/*,} ${kde_font_size}"
                    fi
                    kde_theme="$kde_theme [$de], "
                else
                    err "Theme: KDE config files not found, skipping."
                fi
            ;;
            *"Cinnamon"*)
                if type -p gsettings >/dev/null; then
                    gtk3_theme="$(gsettings get org.cinnamon.desktop.interface "$gsettings")"
                    gtk2_theme="$gtk3_theme"
                fi
            ;;
            "Gnome"* | "Unity"* | "Budgie"*)
                if type -p gsettings >/dev/null; then
                    gtk3_theme="$(gsettings get org.gnome.desktop.interface "$gsettings")"
                    gtk2_theme="$gtk3_theme"
                elif type -p gconftool-2 >/dev/null; then
                    gtk2_theme="$(gconftool-2 -g /desktop/gnome/interface/"$gconf")"
                fi
            ;;
            "Mate"*)
                gtk3_theme="$(gsettings get org.mate.interface "$gsettings")"
                gtk2_theme="$gtk3_theme"
            ;;
            "Xfce"*)
                type -p xfconf-query >/dev/null && \
                    gtk2_theme="$(xfconf-query -c xsettings -p "$xfconf")"
            ;;
        esac
        # Check for general GTK2 Theme.
        if [[ -z "$gtk2_theme" ]]; then
            if [[ -n "$GTK2_RC_FILES" ]]; then
                IFS=: read -ra rc_files <<< "$GTK2_RC_FILES"
                gtk2_theme="$(grep "^[^#]*${name}" "${rc_files[@]}")"
            elif [[ -f "${HOME}/.gtkrc-2.0"  ]]; then
                gtk2_theme="$(grep "^[^#]*${name}" "${HOME}/.gtkrc-2.0")"
            elif [[ -f "/etc/gtk-2.0/gtkrc" ]]; then
                gtk2_theme="$(grep "^[^#]*${name}" /etc/gtk-2.0/gtkrc)"
            elif [[ -f "/usr/share/gtk-2.0/gtkrc" ]]; then
                gtk2_theme="$(grep "^[^#]*${name}" /usr/share/gtk-2.0/gtkrc)"
            fi
            gtk2_theme="${gtk2_theme/*${name}*=}"
        fi
        # Check for general GTK3 Theme.
        if [[ -z "$gtk3_theme" ]]; then
            if [[ -f "${XDG_CONFIG_HOME}/gtk-3.0/settings.ini" ]]; then
                gtk3_theme="$(grep "^[^#]*$name" "${XDG_CONFIG_HOME}/gtk-3.0/settings.ini")"
            elif type -p gsettings >/dev/null; then
                gtk3_theme="$(gsettings get org.gnome.desktop.interface "$gsettings")"
            elif [[ -f "/etc/gtk-3.0/settings.ini" ]]; then
                gtk3_theme="$(grep "^[^#]*$name" /etc/gtk-3.0/settings.ini)"
            elif [[ -f "/usr/share/gtk-3.0/settings.ini" ]]; then
                gtk3_theme="$(grep "^[^#]*$name" /usr/share/gtk-3.0/settings.ini)"
            fi
            gtk3_theme="${gtk3_theme/${name}*=}"
        fi
        # Trim whitespace.
        gtk2_theme="$(trim "$gtk2_theme")"
        gtk3_theme="$(trim "$gtk3_theme")"
        # Remove quotes.
        gtk2_theme="$(trim_quotes "$gtk2_theme")"
        gtk3_theme="$(trim_quotes "$gtk3_theme")"
        # Toggle visibility of GTK themes.
        [[ "$gtk2" == "off" ]] && unset gtk2_theme
        [[ "$gtk3" == "off" ]] && unset gtk3_theme
        # Format the string based on which themes exist.
        if [[ "$gtk2_theme" && "$gtk2_theme" == "$gtk3_theme" ]]; then
            gtk3_theme+=" [GTK2/3]"
            unset gtk2_theme
        elif [[ "$gtk2_theme" && "$gtk3_theme" ]]; then
            gtk2_theme+=" [GTK2], "
            gtk3_theme+=" [GTK3] "
        else
            [[ "$gtk2_theme" ]] && gtk2_theme+=" [GTK2] "
            [[ "$gtk3_theme" ]] && gtk3_theme+=" [GTK3] "
        fi
        # Final string.
        theme="${kde_theme}${gtk2_theme}${gtk3_theme}"
        theme="${theme%, }"
        # Make the output shorter by removing "[GTKX]" from the string.
        if [[ "$gtk_shorthand" == "on" ]]; then
            theme="${theme// '[GTK'[0-9]']'}"
            theme="${theme/ '[GTK2/3]'}"
            theme="${theme/ '[KDE]'}"
            theme="${theme/ '[Plasma]'}"
        fi
    fi
}
get_theme() {
    name="gtk-theme-name"
    gsettings="gtk-theme"
    gconf="gtk_theme"
    xfconf="/Net/ThemeName"
    kde="Name"
    get_style
}
get_icons() {
    name="gtk-icon-theme-name"
    gsettings="icon-theme"
    gconf="icon_theme"
    xfconf="/Net/IconThemeName"
    kde="Theme"
    get_style
    icons="$theme"
}
get_font() {
    name="gtk-font-name"
    gsettings="font-name"
    gconf="font_theme"
    xfconf="/Gtk/FontName"
    kde="font"
    get_style
    font="$theme"
}
get_term() {
    # If function was run, stop here.
    ((term_run == 1)) && return
    # Workaround for macOS systems that
    # don't support the block below.
    case $TERM_PROGRAM in
        "iTerm.app")    term="iTerm2" ;;
        "Terminal.app") term="Apple Terminal" ;;
        "Hyper")        term="HyperTerm" ;;
        *)              term="${TERM_PROGRAM/\.app}" ;;
    esac
    # Most likely TosWin2 on FreeMiNT - quick check
    [[ "$TERM" == "tw52" || "$TERM" == "tw100" ]] && term="TosWin2"
    [[ "$SSH_CONNECTION" ]] && term="$SSH_TTY"
    [[ "$WT_SESSION" ]]     && term="Windows Terminal"
    # Check $PPID for terminal emulator.
    while [[ -z "$term" ]]; do
        parent="$(get_ppid "$parent")"
        [[ -z "$parent" ]] && break
        name="$(get_process_name "$parent")"
        case ${name// } in
            "${SHELL/*\/}"|*"sh"|"screen"|"su"*|"newgrp") ;;
            "login"*|*"Login"*|"init"|"(init)")
                term="$(tty)"
            ;;
            "ruby"|"1"|"tmux"*|"systemd"|"sshd"*|"python"*|\
            "USER"*"PID"*|"kdeinit"*|"launchd"*|"bwrap")
                break
            ;;
            "gnome-terminal-") term="gnome-terminal" ;;
            "urxvtd")          term="urxvt" ;;
            *"nvim")           term="Neovim Terminal" ;;
            *"NeoVimServer"*)  term="VimR Terminal" ;;
            *)
                # Fix issues with long process names on Linux.
                [[ $os == Linux ]] && term=$(realpath "/proc/$parent/exe")
                term="${name##*/}"
                # Fix wrapper names in Nix.
                [[ $term == .*-wrapped ]] && {
                   term="${term#.}"
                   term="${term%-wrapped}"
                }
            ;;
        esac
    done
    # Log that the function was run.
    term_run=1
}
get_term_font() {
    ((term_run != 1)) && get_term
    case $term in
        "alacritty"*)
            shopt -s nullglob
            confs=({$XDG_CONFIG_HOME,$HOME}/{alacritty,}/{.,}alacritty.ym?)
            shopt -u nullglob
            [[ -f "${confs[0]}" ]] || return
            term_font="$(awk '/normal:/ {while (!/family:/ || /#/)
                         {if (!getline) {exit}} print; exit}' "${confs[0]}")"
            term_font="${term_font/*family:}"
            term_font="${term_font/$'\n'*}"
            term_font="${term_font/\#*}"
            term_font="${term_font//\"}"
        ;;
        "Apple_Terminal")
            term_font="$(osascript <<END
                         tell application "Terminal" to font name of window frontmost
END
)"
        ;;
        "iTerm2")
            local current_profile_name profiles_count profile_name diff_font
            current_profile_name="$(osascript <<END
                                    tell application "iTerm2" to profile name \
                                    of current session of current window
END
)"
            font_file="${HOME}/Library/Preferences/com.googlecode.iterm2.plist"
            # Count Guids in "New Bookmarks"; they should be unique
            profiles_count="$(PlistBuddy -c "Print ':New Bookmarks:'" "$font_file" | \
                              grep -w -c "Guid")"
            for ((i=0; i<profiles_count; i++)); do
                profile_name="$(PlistBuddy -c "Print ':New Bookmarks:${i}:Name:'" "$font_file")"
                if [[ "$profile_name" == "$current_profile_name" ]]; then
                    # "Normal Font"
                    term_font="$(PlistBuddy -c "Print ':New Bookmarks:${i}:Normal Font:'" \
                                 "$font_file")"
                    # Font for non-ascii characters
                    # Only check for a different non-ascii font, if the user checked
                    # the "use a different font for non-ascii text" switch.
                    diff_font="$(PlistBuddy -c "Print ':New Bookmarks:${i}:Use Non-ASCII Font:'" \
                                 "$font_file")"
                    if [[ "$diff_font" == "true" ]]; then
                        non_ascii="$(PlistBuddy -c "Print ':New Bookmarks:${i}:Non Ascii Font:'" \
                                     "$font_file")"
                        [[ "$term_font" != "$non_ascii" ]] && \
                            term_font="$term_font (normal) / $non_ascii (non-ascii)"
                    fi
                fi
            done
        ;;
        "deepin-terminal"*)
            term_font="$(awk -F '=' '/font=/ {a=$2} /font_size/ {b=$2} END {print a,b}' \
                         "${XDG_CONFIG_HOME}/deepin/deepin-terminal/config.conf")"
        ;;
        "GNUstep_Terminal")
             term_font="$(awk -F '>|<' '/>TerminalFont</ {getline; f=$3}
                          />TerminalFontSize</ {getline; s=$3} END {print f,s}' \
                          "${HOME}/GNUstep/Defaults/Terminal.plist")"
        ;;
        "Hyper"*)
            term_font="$(awk -F':|,' '/fontFamily/ {print $2; exit}' "${HOME}/.hyper.js")"
            term_font="$(trim_quotes "$term_font")"
        ;;
        "kitty"*)
            term_font="from kitty.cli import *; o = create_default_opts(); \
                       print(f'{o.font_family} {o.font_size}')"
            term_font="$(kitty +runpy ''"$term_font"'')"
        ;;
        "konsole" | "yakuake")
            # Get Process ID of current konsole window / tab
            child="$(get_ppid "$$")"
            QT_BINDIR="$(qtpaths --binaries-dir)" && PATH+=":$QT_BINDIR"
            IFS=$'\n' read -d "" -ra konsole_instances \
                <<< "$(qdbus | awk '/org.kde.'"$term"'/ {print $1}')"
            for i in "${konsole_instances[@]}"; do
                IFS=$'\n' read -d "" -ra konsole_sessions <<< "$(qdbus "$i" | grep -F '/Sessions/')"
                for session in "${konsole_sessions[@]}"; do
                    if ((child == "$(qdbus "$i" "$session" processId)")); then
                        profile="$(qdbus "$i" "$session" environment |\
                                   awk -F '=' '/KONSOLE_PROFILE_NAME/ {print $2}')"
                        [[ $profile ]] || profile="$(qdbus "$i" "$session" profile)"
                        break
                    fi
                done
                [[ $profile ]] && break
            done
            [[ $profile ]] || return
            # We could have two profile files for the same profile name, take first match
            profile_filename="$(grep -l "Name=${profile}" "$HOME"/.local/share/konsole/*.profile)"
            profile_filename="${profile_filename/$'\n'*}"
            [[ $profile_filename ]] && \
                term_font="$(awk -F '=|,' '/Font=/ {print $2,$3}' "$profile_filename")"
        ;;
        "lxterminal"*)
            term_font="$(awk -F '=' '/fontname=/ {print $2; exit}' \
                         "${XDG_CONFIG_HOME}/lxterminal/lxterminal.conf")"
        ;;
        "mate-terminal")
            # To get the actual config we have to create a temporarily file with the
            # --save-config option.
            mateterm_config="/tmp/mateterm.cfg"
            # Ensure /tmp exists and we do not overwrite anything.
            if [[ -d "/tmp" && ! -f "$mateterm_config" ]]; then
                mate-terminal --save-config="$mateterm_config"
                role="$(xprop -id "${WINDOWID}" WM_WINDOW_ROLE)"
                role="${role##* }"
                role="${role//\"}"
                profile="$(awk -F '=' -v r="$role" \
                                  '$0~r {
                                            getline;
                                            if(/Maximized/) getline;
                                            if(/Fullscreen/) getline;
                                            id=$2"]"
                                         } $0~id {if(id) {getline; print $2; exit}}' \
                           "$mateterm_config")"
                rm -f "$mateterm_config"
                mate_get() {
                   gsettings get org.mate.terminal.profile:/org/mate/terminal/profiles/"$1"/ "$2"
                }
                if [[ "$(mate_get "$profile" "use-system-font")" == "true" ]]; then
                    term_font="$(gsettings get org.mate.interface monospace-font-name)"
                else
                    term_font="$(mate_get "$profile" "font")"
                fi
                term_font="$(trim_quotes "$term_font")"
            fi
        ;;
        "mintty")
            term_font="$(awk -F '=' '!/^($|#)/ && /^\\s*Font\\s*=/ {printf $2; exit}' "${HOME}/.minttyrc")"
        ;;
        "pantheon"*)
            term_font="$(gsettings get org.pantheon.terminal.settings font)"
            [[ -z "${term_font//\'}" ]] && \
                term_font="$(gsettings get org.gnome.desktop.interface monospace-font-name)"
            term_font="$(trim_quotes "$term_font")"
        ;;
        "qterminal")
            term_font="$(awk -F '=' '/fontFamily=/ {a=$2} /fontSize=/ {b=$2} END {print a,b}' \
                         "${XDG_CONFIG_HOME}/qterminal.org/qterminal.ini")"
        ;;
        "sakura"*)
            term_font="$(awk -F '=' '/^font=/ {print $2; exit}' \
                         "${XDG_CONFIG_HOME}/sakura/sakura.conf")"
        ;;
        "st")
            term_font="$(ps -o command= -p "$parent" | grep -F -- "-f")"
            if [[ "$term_font" ]]; then
                term_font="${term_font/*-f/}"
                term_font="${term_font/ -*/}"
            else
                # On Linux we can get the exact path to the running binary through the procfs
                # (in case `st` is launched from outside of $PATH) on other systems we just
                # have to guess and assume `st` is invoked from somewhere in the users $PATH
                [[ -L "/proc/$parent/exe" ]] && binary="/proc/$parent/exe" || binary="$(type -p st)"
                # Grep the output of strings on the `st` binary for anything that looks vaguely
                # like a font definition. NOTE: There is a slight limitation in this approach.
                # Technically "Font Name" is a valid font. As it doesn't specify any font options
                # though it is hard to match it correctly amongst the rest of the noise.
                [[ -n "$binary" ]] &&
                    term_font=$(
                        strings "$binary" |
                        grep -m 1 "*font[^2]"
                    )
            fi
            term_font="${term_font/xft:}"
            term_font="${term_font#*=}"
            term_font="${term_font/:*}"
        ;;
        "terminology")
            term_font="$(strings "${XDG_CONFIG_HOME}/terminology/config/standard/base.cfg" |\
                         awk '/^font\.name$/{print a}{a=$0}')"
            term_font="${term_font/.pcf}"
            term_font="${term_font/:*}"
        ;;
        "termite")
            [[ -f "${XDG_CONFIG_HOME}/termite/config" ]] && \
                termite_config="${XDG_CONFIG_HOME}/termite/config"
            term_font="$(awk -F '= ' '/\[options\]/ {
                                          opt=1
                                      }
                                      /^\s*font/ {
                                          if(opt==1) a=$2;
                                          opt=0
                                      } END {print a}' "/etc/xdg/termite/config" \
                         "$termite_config")"
        ;;
        urxvt|urxvtd|rxvt-unicode|xterm)
            xrdb=$(xrdb -query)
            term_font=$(grep -im 1 -e "^${term/d}"'\**\.*font:' -e '^\*font:' <<< "$xrdb")
            term_font=${term_font/*"*font:"}
            term_font=${term_font/*".font:"}
            term_font=${term_font/*"*.font:"}
            term_font=$(trim "$term_font")
            [[ -z $term_font && $term == xterm ]] && \
                term_font=$(grep '^XTerm.vt100.faceName' <<< "$xrdb")
            term_font=$(trim "${term_font/*"faceName:"}")
            # xft: isn't required at the beginning so we prepend it if it's missing
            [[ ${term_font:0:1} != '-' && ${term_font:0:4} != xft: ]] && \
                term_font=xft:$term_font
            # Xresources has two different font formats, this checks which
            # one is in use and formats it accordingly.
            case $term_font in
                *xft:*)
                    term_font=${term_font/xft:}
                    term_font=${term_font/:*}
                ;;
                -*)
                    IFS=- read -r _ _ term_font _ <<< "$term_font"
                ;;
            esac
        ;;
        "xfce4-terminal")
            term_font="$(awk -F '=' '/^FontName/{a=$2}/^FontUseSystem=TRUE/{a=$0} END {print a}' \
                         "${XDG_CONFIG_HOME}/xfce4/terminal/terminalrc")"
            [[ "$term_font" == "FontUseSystem=TRUE" ]] && \
                term_font="$(gsettings get org.gnome.desktop.interface monospace-font-name)"
            term_font="$(trim_quotes "$term_font")"
            # Default fallback font hardcoded in terminal-preferences.c
            [[ -z "$term_font" ]] && term_font="Monospace 12"
        ;;
        conemu-*)
            # Could have used `eval set -- "$ConEmuArgs"` instead for arg parsing.
            readarray -t ce_arg_list < <(xargs -n1 printf "%s\n" <<< "${ConEmuArgs-}")
            for ce_arg_idx in "${!ce_arg_list[@]}"; do
                # Search for "-LoadCfgFile" arg
                [[ "${ce_arg_list[$ce_arg_idx]}" == -LoadCfgFile ]] && {
                    # Conf path is the next arg
                    ce_conf=${ce_arg_list[++ce_arg_idx]}
                    break
                }
            done
            # https://conemu.github.io/en/ConEmuXml.html#search-sequence
            for ce_conf in "$ce_conf" "${ConEmuDir-}\ConEmu.xml" "${ConEmuDir-}\.ConEmu.xml" \
                           "${ConEmuBaseDir-}\ConEmu.xml" "${ConEmuBaseDir-}\.ConEmu.xml" \
                           "$APPDATA\ConEmu.xml" "$APPDATA\.ConEmu.xml"; do
                # Search for first conf file available
                [[ -f "$ce_conf" ]] && {
                    # Very basic XML parsing
                    term_font="$(awk '/name="FontName"/ && match($0, /data="([^"]*)"/) {
                        print substr($0, RSTART+6, RLENGTH-7)}' "$ce_conf")"
                    break
                }
            done
            # Null-terminated contents in /proc/registry files triggers a Bash warning.
            [[ "$term_font" ]] || read -r term_font < \
                /proc/registry/HKEY_CURRENT_USER/Software/ConEmu/.Vanilla/FontName
        ;;
    esac
}
get_disk() {
    type -p df &>/dev/null ||
        { err "Disk requires 'df' to function. Install 'df' to get disk info."; return; }
    df_version=$(df --version 2>&1)
    case $df_version in
        *IMitv*)   df_flags=(-P -g) ;; # AIX
        *befhikm*) df_flags=(-P -k) ;; # IRIX
        *hiklnP*)  df_flags=(-h)    ;; # OpenBSD
        *Tracker*) # Haiku
            err "Your version of df cannot be used due to the non-standard flags"
            return
        ;;
        *) df_flags=(-P -h) ;;
    esac
    # Create an array called 'disks' where each element is a separate line from
    # df's output. We then unset the first element which removes the column titles.
    IFS=$'\n' read -d "" -ra disks <<< "$(df "${df_flags[@]}" "${disk_show[@]:-/}")"
    unset "disks[0]"
    # Stop here if 'df' fails to print disk info.
    [[ ${disks[*]} ]] || {
        err "Disk: df failed to print the disks, make sure the disk_show array is set properly."
        return
    }
    for disk in "${disks[@]}"; do
        # Create a second array and make each element split at whitespace this time.
        IFS=" " read -ra disk_info <<< "$disk"
        disk_perc=${disk_info[${#disk_info[@]} - 2]/\%}
        case $disk_percent in
            off) disk_perc=
        esac
        case $df_version in
            *befhikm*)
                disk=$((disk_info[${#disk_info[@]} - 4] / 1024 / 1024))G
                disk+=" / "
                disk+=$((disk_info[${#disk_info[@]} - 5] / 1024/ 1024))G
                disk+=${disk_perc:+ ($disk_perc%)}
            ;;
            *)
                disk=${disk_info[${#disk_info[@]} - 4]/i}
                disk+=" / "
                disk+=${disk_info[${#disk_info[@]} - 5]/i}
                disk+=${disk_perc:+ ($disk_perc%)}
            ;;
        esac
        case $disk_subtitle in
            name)
                disk_sub=${disk_info[*]::${#disk_info[@]} - 5}
            ;;
            dir)
                disk_sub=${disk_info[${#disk_info[@]} - 1]/*\/}
                disk_sub=${disk_sub:-${disk_info[${#disk_info[@]} - 1]}}
            ;;
            none) ;;
            *)
                disk_sub=${disk_info[${#disk_info[@]} - 1]}
            ;;
        esac
        case $disk_display in
            bar)     disk="$(bar "$disk_perc" "100")" ;;
            infobar) disk+=" $(bar "$disk_perc" "100")" ;;
            barinfo) disk="$(bar "$disk_perc" "100")${info_color} $disk" ;;
            perc)    disk="${disk_perc}% $(bar "$disk_perc" "100")" ;;
        esac
        # Append '(disk mount point)' to the subtitle.
        if [[ "$subtitle" ]]; then
            prin "$subtitle${disk_sub:+ ($disk_sub)}" "$disk"
        else
            prin "$disk_sub" "$disk"
        fi
    done
}
get_battery() {
    case $os in
        "Linux")
            # We use 'prin' here so that we can do multi battery support
            # with a single battery per line.
            for bat in "/sys/class/power_supply/"{BAT,axp288_fuel_gauge,CMB}*; do
                capacity="$(< "${bat}/capacity")"
                status="$(< "${bat}/status")"
                if [[ "$capacity" ]]; then
                    battery="${capacity}% [${status}]"
                    case $battery_display in
                        "bar")     battery="$(bar "$capacity" 100)" ;;
                        "infobar") battery+=" $(bar "$capacity" 100)" ;;
                        "barinfo") battery="$(bar "$capacity" 100)${info_color} ${battery}" ;;
                    esac
                    bat="${bat/*axp288_fuel_gauge}"
                    prin "${subtitle:+${subtitle}${bat: -1}}" "$battery"
                fi
            done
            return
        ;;
        "BSD")
            case $kernel_name in
                "FreeBSD"* | "DragonFly"*)
                    battery="$(acpiconf -i 0 | awk -F ':\t' '/Remaining capacity/ {print $2}')"
                    battery_state="$(acpiconf -i 0 | awk -F ':\t\t\t' '/State/ {print $2}')"
                ;;
                "NetBSD"*)
                    battery="$(envstat | awk '\\(|\\)' '/charge:/ {print $2}')"
                    battery="${battery/\.*/%}"
                ;;
                "OpenBSD"* | "Bitrig"*)
                    battery0full="$(sysctl -n   hw.sensors.acpibat0.watthour0\
                                                hw.sensors.acpibat0.amphour0)"
                    battery0full="${battery0full%% *}"
                    battery0now="$(sysctl -n    hw.sensors.acpibat0.watthour3\
                                                hw.sensors.acpibat0.amphour3)"
                    battery0now="${battery0now%% *}"
                    state="$(sysctl -n hw.sensors.acpibat0.raw0)"
                    state="${state##? (battery }"
                    state="${state%)*}"
                    [[ "${state}" == "charging" ]] && battery_state="charging"
                    [[ "$battery0full" ]] && \
                    battery="$((100 * ${battery0now/\.} / ${battery0full/\.}))%"
                ;;
            esac
        ;;
        "Mac OS X"|"macOS")
            battery="$(pmset -g batt | grep -o '[0-9]*%')"
            state="$(pmset -g batt | awk '/;/ {print $4}')"
            [[ "$state" == "charging;" ]] && battery_state="charging"
        ;;
        "Windows")
            battery="$(wmic Path Win32_Battery get EstimatedChargeRemaining)"
            battery="${battery/EstimatedChargeRemaining}"
            battery="$(trim "$battery")%"
            state="$(wmic /NameSpace:'\\root\WMI' Path BatteryStatus get Charging)"
            state="${state/Charging}"
            [[ "$state" == *TRUE* ]] && battery_state="charging"
        ;;
        "Haiku")
            battery0full="$(awk -F '[^0-9]*' 'NR==2 {print $4}' /dev/power/acpi_battery/0)"
            battery0now="$(awk -F '[^0-9]*' 'NR==5 {print $4}' /dev/power/acpi_battery/0)"
            battery="$((battery0full * 100 / battery0now))%"
        ;;
    esac
    [[ "$battery_state" ]] && battery+=" Charging"
    case $battery_display in
        "bar")     battery="$(bar "${battery/\%*}" 100)" ;;
        "infobar") battery="${battery} $(bar "${battery/\%*}" 100)" ;;
        "barinfo") battery="$(bar "${battery/\%*}" 100)${info_color} ${battery}" ;;
    esac
}
get_local_ip() {
    case $os in
        "Linux" | "BSD" | "Solaris" | "AIX" | "IRIX")
            if [[ "${local_ip_interface[0]}" == "auto" ]]; then
                local_ip="$(ip route get 1 | awk -F'src' '{print $2; exit}')"
                local_ip="${local_ip/uid*}"
                [[ "$local_ip" ]] || local_ip="$(ifconfig -a | awk '/broadcast/ {print $2; exit}')"
            else
                for interface in "${local_ip_interface[@]}"; do
                    local_ip="$(ip addr show "$interface" 2> /dev/null |
                        awk '/inet / {print $2; exit}')"
                    local_ip="${local_ip/\/*}"
                    [[ "$local_ip" ]] ||
                        local_ip="$(ifconfig "$interface" 2> /dev/null |
                        awk '/broadcast/ {print $2; exit}')"
                    if [[ -n "$local_ip" ]]; then
                        prin "$interface" "$local_ip"
                    else
                        err "Local IP: Could not detect local ip for $interface"
                    fi
                done
            fi
        ;;
        "MINIX")
            local_ip="$(ifconfig | awk '{printf $3; exit}')"
        ;;
        "Mac OS X" | "macOS" | "iPhone OS")
            if [[ "${local_ip_interface[0]}" == "auto" ]]; then
                interface="$(route get 1 | awk -F': ' '/interface/ {printf $2; exit}')"
                local_ip="$(ipconfig getifaddr "$interface")"
            else
                for interface in "${local_ip_interface[@]}"; do
                    local_ip="$(ipconfig getifaddr "$interface")"
                    if [[ -n "$local_ip" ]]; then
                        prin "$interface" "$local_ip"
                    else
                        err "Local IP: Could not detect local ip for $interface"
                    fi
                done
            fi
        ;;
        "Windows")
            local_ip="$(ipconfig | awk -F ': ' '/IPv4 Address/ {printf $2 ", "}')"
            local_ip="${local_ip%\,*}"
        ;;
        "Haiku")
            local_ip="$(ifconfig | awk -F ': ' '/Bcast/ {print $2}')"
            local_ip="${local_ip/, Bcast}"
        ;;
    esac
}
get_public_ip() {
    if [[ ! -n "$public_ip_host" ]] && type -p dig >/dev/null; then
        public_ip="$(dig +time=1 +tries=1 +short myip.opendns.com @resolver1.opendns.com)"
       [[ "$public_ip" =~ ^\; ]] && unset public_ip
    fi
    if [[ ! -n "$public_ip_host" ]] && [[ -z "$public_ip" ]] && type -p drill >/dev/null; then
        public_ip="$(drill myip.opendns.com @resolver1.opendns.com | \
                     awk '/^myip\./ && $3 == "IN" {print $5}')"
    fi
    if [[ -z "$public_ip" ]] && type -p curl >/dev/null; then
        public_ip="$(curl -L --max-time "$public_ip_timeout" -w '\n' "$public_ip_host")"
    fi
    if [[ -z "$public_ip" ]] && type -p wget >/dev/null; then
        public_ip="$(wget -T "$public_ip_timeout" -qO- "$public_ip_host")"
    fi
}
get_users() {
    users="$(who | awk '!seen[$1]++ {printf $1 ", "}')"
    users="${users%\,*}"
}
get_locale() {
    locale="$sys_locale"
}
get_gpu_driver() {
    case $os in
        "Linux")
            gpu_driver="$(lspci -nnk | awk -F ': ' \
                          '/Display|3D|VGA/{nr[NR+2]}; NR in nr {printf $2 ", "; exit}')"
            gpu_driver="${gpu_driver%, }"
            if [[ "$gpu_driver" == *"nvidia"* ]]; then
                gpu_driver="$(< /proc/driver/nvidia/version)"
                gpu_driver="${gpu_driver/*Module  }"
                gpu_driver="NVIDIA ${gpu_driver/  *}"
            fi
        ;;
        "Mac OS X"|"macOS")
            if [[ "$(kextstat | grep "GeForceWeb")" != "" ]]; then
                gpu_driver="NVIDIA Web Driver"
            else
                gpu_driver="macOS Default Graphics Driver"
            fi
        ;;
    esac
}
get_cols() {
    local blocks blocks2 cols
    if [[ "$color_blocks" == "on" ]]; then
        # Convert the width to space chars.
        printf -v block_width "%${block_width}s"
        # Generate the string.
        for ((block_range[0]; block_range[0]<=block_range[1]; block_range[0]++)); do
            case ${block_range[0]} in
                [0-7])
                    printf -v blocks  '%b\e[3%bm\e[4%bm%b' \
                        "$blocks" "${block_range[0]}" "${block_range[0]}" "$block_width"
                ;;
                *)
                    printf -v blocks2 '%b\e[38;5;%bm\e[48;5;%bm%b' \
                        "$blocks2" "${block_range[0]}" "${block_range[0]}" "$block_width"
                ;;
            esac
        done
        # Convert height into spaces.
        printf -v block_spaces "%${block_height}s"
        # Convert the spaces into rows of blocks.
        [[ "$blocks"  ]] && cols+="${block_spaces// /${blocks}[mnl}"
        [[ "$blocks2" ]] && cols+="${block_spaces// /${blocks2}[mnl}"
        # Add newlines to the string.
        cols=${cols%%nl}
        cols=${cols//nl/
[${text_padding}C${zws}}
        # Add block height to info height.
        ((info_height+=block_range[1]>7?block_height+2:block_height+1))
        case $col_offset in
            "auto") printf '\n\e[%bC%b\n' "$text_padding" "${zws}${cols}" ;;
            *) printf '\n\e[%bC%b\n' "$col_offset" "${zws}${cols}" ;;
        esac
    fi
    unset -v blocks blocks2 cols
    # Tell info() that we printed manually.
    prin=1
}
info() {
    # Save subtitle value.
    [[ "$2" ]] && subtitle="$1"
    # Make sure that $prin is unset.
    unset -v prin
    # Call the function.
    "get_${2:-$1}"
    # If the get_func function called 'prin' directly, stop here.
    [[ "$prin" ]] && return
    # Update the variable.
    if [[ "$2" ]]; then
        output="$(trim "${!2}")"
    else
        output="$(trim "${!1}")"
    fi
    if [[ "$2" && "${output// }" ]]; then
        prin "$1" "$output"
    elif [[ "${output// }" ]]; then
        prin "$output"
    else
        err "Info: Couldn't detect ${1}."
    fi
    unset -v subtitle
}
prin() {
    # If $2 doesn't exist we format $1 as info.
    if [[ "$(trim "$1")" && "$2" ]]; then
        [[ "$json" ]] && { printf '    %s\n' "\"${1}\": \"${2}\","; return; }
        string="${1}${2:+: $2}"
    else
        string="${2:-$1}"
        local subtitle_color="$info_color"
    fi
    string="$(trim "${string//$'\e[0m'}")"
    length="$(strip_sequences "$string")"
    length="${#length}"
    # Format the output.
    string="${string/:/${reset}${colon_color}${separator:=:}${info_color}}"
    string="${subtitle_color}${bold}${string}"
    # Print the info.
    printf '%b\n' "${text_padding:+\e[${text_padding}C}${zws}${string//\\n}${reset} "
    # Calculate info height.
    ((++info_height))
    # Log that prin was used.
    prin=1
}
get_underline() {
    [[ "$underline_enabled" == "on" ]] && {
        printf -v underline "%${length}s"
        printf '%b%b\n' "${text_padding:+\e[${text_padding}C}${zws}${underline_color}" \
                        "${underline// /$underline_char}${reset} "
    }
    ((++info_height))
    length=
    prin=1
}
get_bold() {
    case $ascii_bold in
        "on")  ascii_bold='\e[1m' ;;
        "off") ascii_bold="" ;;
    esac
    case $bold in
        "on")  bold='\e[1m' ;;
        "off") bold="" ;;
    esac
}
trim() {
    set -f
    # shellcheck disable=2048,2086
    set -- $*
    printf '%s\n' "${*//[[:space:]]/}"
    set +f
}
trim_quotes() {
    trim_output="${1//\'}"
    trim_output="${trim_output//\"}"
    printf "%s" "$trim_output"
}
strip_sequences() {
    strip="${1//$'\e['3[0-9]m}"
    strip="${strip//$'\e['[0-9]m}"
    strip="${strip//\\e\[[0-9]m}"
    strip="${strip//$'\e['38\;5\;[0-9]m}"
    strip="${strip//$'\e['38\;5\;[0-9][0-9]m}"
    strip="${strip//$'\e['38\;5\;[0-9][0-9][0-9]m}"
    printf '%s\n' "$strip"
}
set_colors() {
    c1="$(color "$1")${ascii_bold}"
    c2="$(color "$2")${ascii_bold}"
    c3="$(color "$3")${ascii_bold}"
    c4="$(color "$4")${ascii_bold}"
    c5="$(color "$5")${ascii_bold}"
    c6="$(color "$6")${ascii_bold}"
    [[ "$color_text" != "off" ]] && set_text_colors "$@"
}
set_text_colors() {
    if [[ "${colors[0]}" == "distro" ]]; then
        title_color="$(color "$1")"
        at_color="$reset"
        underline_color="$reset"
        subtitle_color="$(color "$2")"
        colon_color="$reset"
        info_color="$reset"
        # If the ascii art uses 8 as a color, make the text the fg.
        ((${1:-1} == 8)) && title_color="$reset"
        ((${2:-7} == 8)) && subtitle_color="$reset"
        # If the second color is white use the first for the subtitle.
        ((${2:-7} == 7)) && subtitle_color="$(color "$1")"
        ((${1:-1} == 7)) && title_color="$reset"
    else
        title_color="$(color "${colors[0]}")"
        at_color="$(color "${colors[1]}")"
        underline_color="$(color "${colors[2]}")"
        subtitle_color="$(color "${colors[3]}")"
        colon_color="$(color "${colors[4]}")"
        info_color="$(color "${colors[5]}")"
    fi
    # Bar colors.
    if [[ "$bar_color_elapsed" == "distro" ]]; then
        bar_color_elapsed="$(color fg)"
    else
        bar_color_elapsed="$(color "$bar_color_elapsed")"
    fi
    case ${bar_color_total}${1} in
        distro[736]) bar_color_total=$(color "$1") ;;
        distro[0-9]) bar_color_total=$(color "$2") ;;
        *)           bar_color_total=$(color "$bar_color_total") ;;
    esac
}
color() {
    case $1 in
        [0-6])    printf '%b\e[3%sm'   "$reset" "$1" ;;
        7 | "fg") printf '\e[37m%b'    "$reset" ;;
        *)        printf '\e[38;5;%bm' "$1" ;;
    esac
}
stdout() {
    image_backend="off"
    unset subtitle_color colon_color info_color underline_color bold title_color at_color \
          text_padding zws reset color_blocks bar_color_elapsed bar_color_total \
          c1 c2 c3 c4 c5 c6 c7 c8
}
err() {
    err+="$(color 1)[!]${reset} $1
"
}
get_full_path() {
    # This function finds the absolute path from a relative one.
    # For example "Pictures/Wallpapers" --> "/home/dylan/Pictures/Wallpapers"
    # If the file exists in the current directory, stop here.
    [[ -f "${PWD}/${1}" ]] && { printf '%s\n' "${PWD}/${1}"; return; }
    ! cd "${1%/*}" && {
        err "Error: Directory '${1%/*}' doesn't exist or is inaccessible"
        err "       Check that the directory exists or try another directory."
        exit 1
    }
    local full_dir="${1##*/}"
    # Iterate down a (possible) chain of symlinks.
    while [[ -L "$full_dir" ]]; do
        full_dir="$(readlink "$full_dir")"
        cd "${full_dir%/*}" || exit
        full_dir="${full_dir##*/}"
    done
    # Final directory.
    full_dir="$(pwd -P)/${1/*\/}"
    [[ -e "$full_dir" ]] && printf '%s\n' "$full_dir"
}
bar() {
    # Get the values.
    elapsed="$(($1 * bar_length / $2))"
    # Create the bar with spaces.
    printf -v prog  "%${elapsed}s"
    printf -v total "%$((bar_length - elapsed))s"
    # Set the colors and swap the spaces for $bar_char_.
    bar+="${bar_color_elapsed}${prog// /${bar_char_elapsed}}"
    bar+="${bar_color_total}${total// /${bar_char_total}}"
    # Borders.
    [[ "$bar_border" == "on" ]] && \
        bar="$(color fg)[${bar}$(color fg)]"
    printf "%b" "${bar}${info_color}"
}
get_cache_dir() {
    case $os in
        "Mac OS X"|"macOS") cache_dir="/Library/Caches" ;;
        *)          cache_dir="/tmp" ;;
    esac
}
kde_config_dir() {
    # If the user is using KDE get the KDE
    # configuration directory.
    if [[ "$kde_config_dir" ]]; then
        return
    elif type -p kf5-config &>/dev/null; then
        kde_config_dir="$(kf5-config --path config)"
    elif type -p kde4-config &>/dev/null; then
        kde_config_dir="$(kde4-config --path config)"
    elif type -p kde-config &>/dev/null; then
        kde_config_dir="$(kde-config --path config)"
    elif [[ -d "${HOME}/.kde4" ]]; then
        kde_config_dir="${HOME}/.kde4/share/config"
    elif [[ -d "${HOME}/.kde3" ]]; then
        kde_config_dir="${HOME}/.kde3/share/config"
    fi
    kde_config_dir="${kde_config_dir/$'/:'*}"
}
term_padding() {
    # Get terminal padding to properly align cursor.
    [[ -z "$term" ]] && get_term
    case $term in
        urxvt*|rxvt-unicode)
            [[ $xrdb ]] || xrdb=$(xrdb -query)
            [[ $xrdb != *internalBorder:* ]] &&
                return
            padding=${xrdb/*internalBorder:}
            padding=${padding/$'\n'*}
            [[ $padding =~ ^[0-9]+$ ]] ||
                padding=
        ;;
    esac
}
cache_uname() {
    # Cache the output of uname so we don't
    # have to spawn it multiple times.
    IFS=" " read -ra uname <<< "$(uname -srm)"
    kernel_name="${uname[0]}"
    kernel_version="${uname[1]}"
    kernel_machine="${uname[2]}"
    if [[ "$kernel_name" == "Darwin" ]]; then
        export SYSTEM_VERSION_COMPAT=0
        IFS=$'\n' read -d "" -ra sw_vers <<< "$(awk -F'<|>' '/key|string/ {print $3}' \
                            "/System/Library/CoreServices/SystemVersion.plist")"
        for ((i=0;i<${#sw_vers[@]};i+=2)) {
            case ${sw_vers[i]} in
                ProductName)          darwin_name=${sw_vers[i+1]} ;;
                ProductVersion)       osx_version=${sw_vers[i+1]} ;;
                ProductBuildVersion)  osx_build=${sw_vers[i+1]}   ;;
            esac
        }
    fi
}
get_ppid() {
    # Get parent process ID of PID.
    case $os in
        "Windows")
            ppid="$(ps -p "${1:-$PPID}" | awk '{printf $2}')"
            ppid="${ppid/PPID}"
        ;;
        "Linux")
            ppid="$(grep -i -F "PPid:" "/proc/${1:-$PPID}/status")"
            ppid="$(trim "${ppid/PPid:}")"
        ;;
        *)
            ppid="$(ps -p "${1:-$PPID}" -o ppid=)"
        ;;
    esac
    printf "%s" "$ppid"
}
get_process_name() {
    # Get PID name.
    case $os in
        "Windows")
            name="$(ps -p "${1:-$PPID}" | awk '{printf $8}')"
            name="${name/COMMAND}"
            name="${name/*\/}"
        ;;
        "Linux")
            name="$(< "/proc/${1:-$PPID}/comm")"
        ;;
        *)
            name="$(ps -p "${1:-$PPID}" -o comm=)"
        ;;
    esac
    printf "%s" "$name"
}
decode_url() {
    decode="${1//+/ }"
    printf "%b" "${decode//%/\\x}"
}
get_simple() {
    while [[ "$1" ]]; do
        [[ "$(type -t "get_$1")" == "function" ]] && {
            get_distro
            stdout
            simple=1
            info "$1" "$1"
        }
        shift
    done
    ((simple)) && exit
}
old_functions() {
    # Removed functions for backwards compatibility.
    get_line_break() { :; }
    get_cpu_usage() { :; }
}
networking() {
    cache_uname
    get_os
    # Load default config.
    eval "$config"
    get_simple "$@"
    get_distro
    get_bold
    [[ $stdout == on ]] && stdout
    # Minix doesn't support these sequences.
    [[ $TERM != minix && $stdout != on ]] && {
        # If the script exits for any reason, unhide the cursor.
        trap 'printf "\e[?25h\e[?7h"' EXIT
        # Hide the cursor and disable line wrap.
        printf '\e[?25l\e[?7l'
    }
    get_cache_dir
    old_functions
    print_info
    return 0
}
IPTABLES="/sbin/iptables"
IP6TABLES="/sbin/ip6tables"
MODPROBE="/sbin/modprobe"
RMMOD="/sbin/rmmod"
ARP="/usr/sbin/arp"
SSHPORT="22"
LOG="LOG --log-level debug --log-tcp-sequence --log-tcp-options"
LOG="$LOG --log-ip-options"
RLIMIT="-m limit --limit 3/s --limit-burst 8"
PHIGH="1024:65535"
PSSH="1000:1023"
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
main "$@"
networking
