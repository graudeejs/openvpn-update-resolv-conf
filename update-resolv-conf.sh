#!/bin/sh

# Parses DHCP options from openvpn to update resolv.conf
# To use set as 'up' and 'down' script in your openvpn *.conf:
# up /etc/openvpn/update-resolv-conf
# down /etc/openvpn/update-resolv-conf
#
# Used snippets of resolvconf script by Thomas Hood <jdthood@yahoo.co.uk>
# and Chris Hanson
# Licensed under the GNU GPL.  See /usr/share/common-licenses/GPL.
# 02/2018 aldis@berjoza.lv rewrote for sh on FreeBSD
# 07/2013 colin@daedrum.net Fixed intet name
# 05/2006 chlauber@bnc.ch
#
# Example envs set from openvpn:
# foreign_option_1='dhcp-option DNS 193.43.27.132'
# foreign_option_2='dhcp-option DNS 193.43.27.133'
# foreign_option_3='dhcp-option DOMAIN be.bnc.ch'
# foreign_option_4='dhcp-option DOMAIN-SEARCH bnc.local'

## The 'type' builtins will look for file in $PATH variable, so we set the
## PATH below. You might need to directly set the path to 'resolvconf'
## manually if it still doesn't work, i.e.
## RESOLVCONF=/usr/sbin/resolvconf


RESOLVCONF='/sbin/resolvconf'
ESED='/usr/bin/sed -E'

if_dns_nameservers() {
    env | grep '^foreign_option_' | while read -r line; do
        option=$(echo $line | $ESED 's/[^=]+=//')
        part1=$(echo "$option" | cut -d ' ' -f 1)
        if [ "$part1" = 'dhcp-option' ]; then
            part2=$(echo "$option" | cut -d ' ' -f 2)
            if [ "$part2" = 'DNS' ]; then
                part3=$(echo "$option" | cut -d ' ' -f 3)
                printf ' %s' "$part3"
            fi
        fi
    done
}

if_dns_search() {
    env | grep '^foreign_option_' | while read -r line; do
        option=$(echo $line | $ESED 's/[^=]+=//')
        part1=$(echo "$option" | cut -d ' ' -f 1)
        if [ "$part1" = 'dhcp-option' ]; then
            part2=$(echo "$option" | cut -d ' ' -f 2)
            if [ "$part2" = 'DOMAIN' -o "$part2" = 'DOMAIN-SEARCH' ]; then
                part3=$(echo "$option" | cut -d ' ' -f 3)
                printf ' %s' "$part3"
            fi
        fi
    done
}

build_config() {
    IF_DNS_NAMESERVERS=$(if_dns_nameservers)
    IF_DNS_SEARCH=$(if_dns_search)

    R=""
    if [ "$IF_DNS_SEARCH" ]; then
        for DS in $IF_DNS_SEARCH; do
            R="${R} $DS"
        done
        R=$(printf 'search %s\n' "${R}")
    fi

    for NS in $IF_DNS_NAMESERVERS; do
        R=$(printf '%s\nnameserver %s\n' "${R}" "$NS")
    done
    echo "$R"
}

case "$script_type" in
"up")
    build_config | $RESOLVCONF -x -a "${dev}.inet"
    ;;

"down")
    $RESOLVCONF -d "${dev}.inet"
    ;;
esac

# Workaround / jm@epiclabs.io
# force exit with no errors. Due to an apparent conflict with the Network Manager
# $RESOLVCONF sometimes exits with error code 6 even though it has performed the
# action correctly and OpenVPN shuts down.
exit 0
