#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

version="v1.0.0"

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Error: ${plain} ¡Debe utilizar el usuario root para ejecutar este script!\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}No se detecta la versión del sistema, póngase en contacto con el autor del script.${plain}\n" && exit 1
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}Utilice CentOS 7 o superior！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}Utilice Ubuntu 16 o superior！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}Utilice Debian 8 o superior！${plain}\n" && exit 1
    fi
fi

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -p "$1 [por defecto$2]: " temp
        if [[ x"${temp}" == x"" ]]; then
            temp=$2
        fi
    else
        read -p "$1 [y/n]: " temp
    fi
    if [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]]; then
        return 0
    else
        return 1
    fi
}

confirm_restart() {
    confirm "Quiere reiniciar XrayR" "y"
    if [[ $? == 0 ]]; then
        restart
    else
        show_menu
    fi
}

before_show_menu() {
    echo && echo -n -e "${yellow}Presione enter para regresar al menú principal: ${plain}" && read temp
    show_menu
}

install() {
    bash <(curl -Ls https://raw.githubusercontent.com/demianrey/XrayR-instalador/DR/install.sh)
    if [[ $? == 0 ]]; then
        if [[ $# == 0 ]]; then
            start
        else
            start 0
        fi
    fi
}

update() {
    if [[ $# == 0 ]]; then
        echo && echo -n -e "Ingrese la versión especificada (última versión predeterminada): " && read version
    else
        version=$2
    fi
#    confirm "本功能会强制重装当前最新版，数据不会丢失，是否继续?" "n"
#    if [[ $? != 0 ]]; then
#        echo -e "${red}已取消${plain}"
#        if [[ $1 != 0 ]]; then
#            before_show_menu
#        fi
#        return 0
#    fi
    bash <(curl -Ls https://raw.githubusercontent.com/demianrey/XrayR-instalador/DR/install.sh) $version
    if [[ $? == 0 ]]; then
        echo -e "${green}La actualización está completa y XrayR se ha reiniciado automáticamente, use XrayR log para ver el registro en ejecución${plain}"
        exit
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

config() {
    echo "XrayR intentará reiniciarse automáticamente después de modificar la configuración"
    vi /etc/XrayR/config.yml
    sleep 2
    check_status
    case $? in
        0)
            echo -e "Estado de XrayR: ${green}En servicio${plain}"
            ;;
        1)
            echo -e "Se detecta que no has iniciado XrayR o que XrayR no ha podido reiniciarse automáticamente ¿Quieres comprobar el registro?[Y/n]" && echo
            read -e -p "(por defecto: y):" yn
            [[ -z ${yn} ]] && yn="y"
            if [[ ${yn} == [Yy] ]]; then
               show_log
            fi
            ;;
        2)
            echo -e "Estado de XrayR: ${red}No instalado${plain}"
    esac
}

uninstall() {
    confirm "¿Estás seguro de que deseas desinstalar XrayR?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    systemctl stop XrayR
    systemctl disable XrayR
    rm /etc/systemd/system/XrayR.service -f
    systemctl daemon-reload
    systemctl reset-failed
    rm /etc/XrayR/ -rf
    rm /usr/local/XrayR/ -rf

    echo ""
    echo -e "La desinstalación es exitosa, si desea eliminar este script, salga del script y ejecute ${green}rm /usr/bin/XrayR -f${plain} para borrar"
    echo ""

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

start() {
    check_status
    if [[ $? == 0 ]]; then
        echo ""
        echo -e "${green}XrayR ya se está ejecutando, no es necesario comenzar de nuevo${plain}"
    else
        systemctl start XrayR
        sleep 2
        check_status
        if [[ $? == 0 ]]; then
            echo -e "${green}XrayR se inició correctamente, utilice XrayR log para ver el registro en ejecución${plain}"
        else
            echo -e "${red}Es posible que XrayR no se inicie, utilice XrayR log para ver la información del registro${plain}"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

stop() {
    systemctl stop XrayR
    sleep 2
    check_status
    if [[ $? == 1 ]]; then
        echo -e "${green}XrayR se detuvo con éxito${plain}"
    else
        echo -e "${red}XrayR no pudo detenerse. Puede deberse a que se detuvo durante más de dos segundos. Verifique la información de registro.${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

restart() {
    systemctl restart XrayR
    sleep 2
    check_status
    if [[ $? == 0 ]]; then
        echo -e "${green}XrayR se reinició correctamente, utilice XrayR log para ver el registro en ejecución${plain}"
    else
        echo -e "${red}Es posible que XrayR no se inicie, utilice XrayR log para ver la información del registro${plain}"
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

status() {
    systemctl status XrayR --no-pager -l
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

enable() {
    systemctl enable XrayR
    if [[ $? == 0 ]]; then
        echo -e "${green}XrayR está configurado para iniciarse correctamente después de arrancar${plain}"
    else
        echo -e "${red}La configuración de XrayR no pudo iniciarse automáticamente después del arranque${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

disable() {
    systemctl disable XrayR
    if [[ $? == 0 ]]; then
        echo -e "${green}XrayR cancela el inicio automático con éxito${plain}"
    else
        echo -e "${red}XrayR no pudo cancelar el inicio automático${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_log() {
    journalctl -u XrayR.service -e --no-pager -f
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

install_bbr() {
    bash <(curl -L -s https://raw.githubusercontent.com/chiakge/Linux-NetSpeed/master/tcp.sh)
    #if [[ $? == 0 ]]; then
    #    echo ""
    #    echo -e "${green}安装 bbr 成功，请重启服务器${plain}"
    #else
    #    echo ""
    #    echo -e "${red}下载 bbr 安装脚本失败，请检查本机能否连接 Github${plain}"
    #fi

    #before_show_menu
}

update_shell() {
    wget -O /usr/bin/XrayR -N --no-check-certificate https://raw.githubusercontent.com/demianrey/XrayR-instalador/DR/XrayR.sh
    if [[ $? != 0 ]]; then
        echo ""
        echo -e "${red}No se pudo descargar el script, verifique si esta máquina se puede conectar a Github${plain}"
        before_show_menu
    else
        chmod +x /usr/bin/XrayR
        echo -e "${green}La secuencia de comandos de actualización se realizó correctamente.${plain}" && exit 0
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /etc/systemd/system/XrayR.service ]]; then
        return 2
    fi
    temp=$(systemctl status XrayR | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

check_enabled() {
    temp=$(systemctl is-enabled XrayR)
    if [[ x"${temp}" == x"enabled" ]]; then
        return 0
    else
        return 1;
    fi
}

check_uninstall() {
    check_status
    if [[ $? != 2 ]]; then
        echo ""
        echo -e "${red}Se ha instalado XrayR, no lo instale repetidamente${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

check_install() {
    check_status
    if [[ $? == 2 ]]; then
        echo ""
        echo -e "${red}Primero instale XrayR${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

show_status() {
    check_status
    case $? in
        0)
            echo -e "Estado de XrayR: ${green}Corriendo${plain}"
            show_enable_status
            ;;
        1)
            echo -e "Estado de XrayR: ${yellow}Detenido${plain}"
            show_enable_status
            ;;
        2)
            echo -e "Estado de XrayR: ${red}No instalado${plain}"
    esac
}

show_enable_status() {
    check_enabled
    if [[ $? == 0 ]]; then
        echo -e "Inicio automático: ${green}Sí${plain}"
    else
        echo -e "Inicio automático: ${red}No${plain}"
    fi
}

show_XrayR_version() {
    echo -n "Versión XrayR:"
    /usr/local/XrayR/XrayR -version
    echo ""
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_usage() {
    echo "Cómo utilizar los scripts de administración de XrayR: "
    echo "------------------------------------------"
    echo "XrayR                    - Menú de gestión de pantalla (más funciones)"
    echo "XrayR start              - Iniciar"
    echo "XrayR stop               - Detener "
    echo "XrayR restart            - Reiniciar"
    echo "XrayR status             - Estado"
    echo "XrayR enable             - Inicio al arranque"
    echo "XrayR disable            - Deshabilitar inicio"
    echo "XrayR log                - Ver registros"
    echo "XrayR update             - Actualizar"
    echo "XrayR update x.x.x       - Actualizar versión especificada"
    echo "XrayR install            - Instalar"
    echo "XrayR uninstall          - Desinstalar"
    echo "XrayR version            - Version"
    echo "------------------------------------------"
}

show_menu() {
    echo -e "
  ${green}La secuencia de comandos de administración de back-end，${plain}${red}no aplica en docker${plain}
--- https://github.com/XrayR-project/XrayR ---
  ${green}0.${plain} Configuración
————————————————
  ${green}1.${plain} Instalar XrayR
  ${green}2.${plain} Actualizar XrayR
  ${green}3.${plain} Desinstalar XrayR
————————————————
  ${green}4.${plain} Iniciar XrayR
  ${green}5.${plain} Detener XrayR
  ${green}6.${plain} Reiniciar XrayR
  ${green}7.${plain} Estado de XrayR
  ${green}8.${plain} Registros de XrayR
————————————————
  ${green}9.${plain} Inicio al arranque XrayR
 ${green}10.${plain} Cancelar el inicio de XrayR
————————————————
 ${green}11.${plain} Instalación bbr (último kernel)
 ${green}12.${plain} Versión XrayR
 ${green}13.${plain} Actualizar el script de mantenimiento
 "
 #后续更新可加入上方字符串中
    show_status
    echo && read -p "Por favor ingrese la selección [0-13]: " num

    case "${num}" in
        0) config
        ;;
        1) check_uninstall && install
        ;;
        2) check_install && update
        ;;
        3) check_install && uninstall
        ;;
        4) check_install && start
        ;;
        5) check_install && stop
        ;;
        6) check_install && restart
        ;;
        7) check_install && status
        ;;
        8) check_install && show_log
        ;;
        9) check_install && enable
        ;;
        10) check_install && disable
        ;;
        11) install_bbr
        ;;
        12) check_install && show_XrayR_version
        ;;
        13) update_shell
        ;;
        *) echo -e "${red}Ingrese el número correcto [0-12]${plain}"
        ;;
    esac
}


if [[ $# > 0 ]]; then
    case $1 in
        "start") check_install 0 && start 0
        ;;
        "stop") check_install 0 && stop 0
        ;;
        "restart") check_install 0 && restart 0
        ;;
        "status") check_install 0 && status 0
        ;;
        "enable") check_install 0 && enable 0
        ;;
        "disable") check_install 0 && disable 0
        ;;
        "log") check_install 0 && show_log 0
        ;;
        "update") check_install 0 && update 0 $2
        ;;
        "config") config $*
        ;;
        "install") check_uninstall 0 && install 0
        ;;
        "uninstall") check_install 0 && uninstall 0
        ;;
        "version") check_install 0 && show_XrayR_version 0
        ;;
        "update_shell") update_shell
        ;;
        *) show_usage
    esac
else
    show_menu
fi
