#!/usr/bin/env bash

#------------------------------------
set -euo pipefail
# e - o script para no erro (return != 0)
# u - retorna erro se a variável não for definida
# o - script retorna erro se um dos comandos concatenados falhe
# x - output de cada linha (debug)

__ScriptVersion="0.1" # Define a versão do script

function handle_arguments() {
    while getopts ":hr" opt
    do
    case $opt in
        h|help     )  show_help "$@"; exit 0   ;;

        r|reload     )  ajustar_confs "$@"; exit 0   ;;

    * )  echo -e "\n  Option does not exist : $OPTARG\n"
          show_help; exit 1   ;;

    esac    # --- end of case ---
done
shift $((OPTIND-1))
}

#===  FUNÇÃO  ==================================================================
#       NOME: run
#  DESCRIÇÃO: Resposável pela execução inicial do script.
#        OBS: Ele é chamado na última linha do script
#===============================================================================
function run() {
    handle_arguments "$@"
}
# ----------  fim da função 'run'  ----------

#===  FUNÇÃO  ==================================================================
#       NOME: ajustar_confs
#  DESCRIÇÃO: Executa os scripts PHP responsáveis por passar as informações do cliente web para o Asterisk, além de reiniciar os módulos importantes.
#        OBS: 
#===============================================================================
function ajustar_confs() {
    local asterisk_conf="/home/futurofone/scripts/new/ajustaAsteriskConf.php"
    local asterisk_includes="/home/futurofone/scripts/new/ajustaAsteriskIncludes.php"

    function reload_modules() {
        asterisk -rx "sip reload" && echo "SIP reloaded." || { echo "Falha ao reiniciar o modulo SIP"; exit 1; }
        asterisk -rx "iax2 reload" && echo "PJSIP reloaded." || { echo "Falha ao reiniciar o modulo PJSIP"; exit 1; }
        asterisk -rx "dialplan reload" || { echo "Falha ao reiniciar o Dialplan"; exit 1; }
        exit 0
    }

    function execute_scripts() {
        if [ -x "$asterisk_conf" ]; then
            php "$asterisk_conf" && echo "O script ajustaAsteriskConf foi executado" || { echo "Erro ao executar o script ajustaAsteriskConf"; exit 1; }
        else
            echo "O script ajustaAsteriskConf não foi encontrado no caminho ${asterisk_conf}"
            exit 1
        fi

        if [ -x "$asterisk_includes" ]; then
            php "$asterisk_includes" && echo "O script ajustaAsteriskIncludes foi executado" || { echo "Erro ao executar o script ajustaAsteriskIncludes"; exit 1; }
        else
            echo "O script ajustaAsteriskIncludes não foi encontrado no caminho ${asterisk_includes}"
            exit 1
        fi
        reload_modules
    }

    execute_scripts
}
# ----------  fim da função 'ajustar_confs'  ----------

run "$@"