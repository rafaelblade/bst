#!/usr/bin/env bash

#------------------------------------
set -euox pipefail
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

    function execute_scripts() {
        if [ -x "$asterisk_conf" ]; then
            php "$asterisk_conf" && echo "Executando o script AjustaAsteriskConf" || { echo "Erro ao executar o script AjustaAsteriskConf"; exit 1; }
        else
            echo "O script AjustaAsteriskConf não foi encontrado no caminho ${asterisk_conf}"
            exit 1
        fi

        if [ -x "$asterisk_includes" ]; then
            php "$asterisk_includes" && echo "Executando o script AjustaAsteriskIncludes" || { echo "Erro ao executar o script AjustaAsteriskIncludes"; exit 1; }
        else
            echo "O script AjustaAsteriskIncludes não foi encontrado no caminho ${asterisk_includes}"
            exit 1
        fi
    }

    function reload_modules() {
        asterisk -rx "sip reload" && echo "Modulo SIP recarregado com sucesso" || { echo "Falha ao reiniciar o modulo SIP"; exit 1; }
        asterisk -rx "iax2 reload" && echo "Modulo PJSIP recarregado com sucesso" || { echo "Falha ao reiniciar o modulo PJSIP"; exit 1; }
        asterisk -rx "dialplan reload" && echo "Dialplan recarregado com sucesso" || { echo "Falha ao reiniciar o Dialplan"; exit 1; }
    }
    execute_scripts
    reload_modules
}
# ----------  fim da função 'reload_modules'  ----------

run "$@"