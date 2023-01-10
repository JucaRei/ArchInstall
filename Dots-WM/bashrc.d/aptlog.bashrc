apt() {
    case "${1}" in
    history)
        mapfile -t apt_hist < <(zgrep -A 1 "^Start-Date" /var/log/apt/history.log* | grep -v -- "^--$")
        left_col_width="$(("${COLUMNS:-$(tput cols)}" - 30))"
        # The format of this printf invocation needs to be tweaked
        printf -- "| %-${left_col_width}s | %s\\n" "Command line" "Date and time"
        printf -- '%*s\n' "${COLUMNS:-$(tput cols)}" | tr ' ' "-"

        for ((i = 0; i < "${#apt_hist[@]}"; i++)); do
            case "${apt_hist[i]}" in
            Start*)
                timestamp="${apt_hist[i]}"
                timestamp="${timestamp/Start-Date: /}"
                ((i++))
                commandline="${apt_hist[i]}"
                commandline="${commandline/Commandline: apt /}"
                commandline="${commandline/Commandline: apt-get /}"
                if (("${#commandline}" > left_col_width)); then
                    count=1
                    while read -r; do
                        if ((count == 1)); then
                            printf -- "| %-${left_col_width}s | %s\\n" "${REPLY}" "${timestamp}"
                            ((count++))
                        else
                            printf -- "| %-${left_col_width}s | %s\\n" "${REPLY}" ""
                        fi
                    done < <(fold -s -w "${left_col_width}" <<<"${commandline}")
                else
                    # The format of this printf invocation needs to be tweaked
                    printf -- "| %-${left_col_width}s | %s\\n" "${commandline}" "${timestamp}"
                fi
                ;;
            Commandline*)
                continue
                ;;
            esac
        done
        return 0
        ;;
    *)
        command apt "${@}"
        ;;
    esac
}
