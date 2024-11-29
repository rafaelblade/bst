#!/usr/bin/env bash

#------------------------------------
set -euo pipefail
# e - o script para no erro (return != 0)
# u - retorna erro se a variável não for definida
# o - script retorna erro se um dos comandos concatenados falhe
# x - output de cada linha (debug)

__ScriptVersion="0.2.1" # Define a versão do script

#===  FUNÇÃO  ==================================================================
#       NOME: ajustar_confs
#  DESCRIÇÃO: Executa os scripts PHP responsáveis por passar as informações do cliente web para o Asterisk, além de reiniciar os módulos importantes.
#        OBS: 
#===============================================================================
function ajustar_confs() {
    local asterisk_conf="/home/futurofone/scripts/new/ajustaAsteriskConf.php"
    local asterisk_includes="/home/futurofone/scripts/new/ajustaAsteriskIncludes.php"

    function reload_modules() {
        asterisk -rx "sip reload" && echo "SIP reloaded." || { echo "Falha ao reiniciar o modulo SIP" ; exit 1; }
        asterisk -rx "iax2 reload" && echo "PJSIP reloaded." || { echo "Falha ao reiniciar o modulo PJSIP" ; exit 1; } 
        asterisk -rx "dialplan reload" || { echo "Falha ao reiniciar o dialplan" ; exit 1; }
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

#===  FUNÇÃO  ==================================================================
#       NOME: finaliza_chat
#  DESCRIÇÃO: Lista todos os chats ativo do cliente, e dá a opção de finalizar um deles
#        OBS: Inspirado no script 'remoteTunnelAutomatization' do Josimar Rocha
#===============================================================================
function finaliza_chat() {
    local lista_contatos # Variável que armazenará a lista de contatos
    mapfile -t lista_contatos < <(php /home/futurofone/web/core/test/chats/contatos.php | grep -v "^QUANTIDADE" | sed '/^$/d') # Usa o mapfile para preencher a variável 'lista_contatos' com uma array com os contatos de chat

    local count=0
    for contato in "${lista_contatos[@]}" # Loop para iterar sobre todos os contatos na lista
    do
        if [ $count -eq 0 ]; then  # Se variável count for 0, imprime o cabeçalho "OPÇÃO". Isso porque a primeira linha impressa pelo script contatos.php é um informativo sobre o valor presente na coluna
            echo "OPÇÃO |" "${contato}" 
            let count=count+1

        elif [ $count -lt 10 ]; then
            echo "[${count}]  |" "${contato}" # Caso a variável for diferente de 0, e menor que 10 (explicação abaixo), imprime um número (count) para identificar o contato
            let count=count+1
        else
            echo "[${count}] |" "${contato}" # Caso o número maior que 10, ajusta a barra para manter a formatação ;p
            let count=count+1
       fi
    done

    while true; do # Loop para checkar o STDIN informado no read
        read -p "Escolha a opção desejada (1-999): " contato_escolhido # Dá a opção do usuário escolher qual chat quer finalizar
        if [[ "$contato_escolhido" =~ ^[0-9]+$ ]] && [ "$contato_escolhido" -ge 1 ] && [ "$contato_escolhido" -le 999 ]; then # Verifica se a entrada é um número entre 1 e 999
            break  # Sai do loop se o valor for válido
        else
            echo "Por favor, insira um número válido entre 1 e 999." # Caso não, repete o loop até um valor válido seja informado
        fi
    done

    contato_escolhido_id=$(echo ${lista_contatos[contato_escolhido]} | awk $'{ print $1 }') # Manipula a informação dentro da variável contato_escolhido, e pega somente o ID do chat

    php /home/futurofone/web/core/cmd/chat/finalizarContato.php "${contato_escolhido_id}" # Finaliza o contato escolhido
}
# ----------  fim da função 'finaliza_chat'  ----------

#===  FUNÇÃO  ==================================================================
#       NOME: greppy
#  DESCRIÇÃO: Função que identifica se o arquivo de log é um arquivo zst, e utiliza o zstdcat automaticamento junto com o grep.
#        OBS:
#===============================================================================
function greppy(){
    local argumentos
    local arquivo
    argumentos=("$@")  # Armazena todos os argumentos no array 'argumentos'

    # Certifica-se de que há pelo menos 2 argumentos
    if [ "${#argumentos[@]}" -lt 2 ]; then
        echo "Argumentos insuficientes"
        return 1
    fi

    # Obtém o último argumento (o arquivo) usando o índice correto
    arquivo="${argumentos[${#argumentos[@]}-1]}"  # Último elemento do array
    unset argumentos[${#argumentos[@]}-1]        # Remove o último elemento (arquivo)

    # O primeiro argumento pode ser flags como -i ou -E, que devem ser passadas diretamente para o grep
    grep_flags=("${argumentos[@]}")  # Armazena os argumentos restantes como flags e padrões

    # Verifica se o arquivo termina com .zst
    if [[ "$arquivo" == *.zst ]]; then
        zstdcat "$arquivo" | grep "${grep_flags[@]}"  # Descomprime e aplica o grep
    else
        grep "${grep_flags[@]}" "$arquivo"  # Se não for um arquivo .zst, aplica o grep diretamente
    fi
}
# ----------  fim da função 'greppy'  ----------

function handle_arguments() {
    while getopts ":hrcvg" opt
    do
    case $opt in
        h)  mostrar_ajuda "$@"; exit 0   ;;

        v)  echo "$0 -- Version $__ScriptVersion"; exit 0   ;;

        r)  ajustar_confs "$@"; exit 0   ;;

        c)  finaliza_chat "$@"; exit 0   ;;
        
        g)  shift; greppy "$@"; exit 0   ;;
    
    * )  echo -e "\n  opção não existe : $OPTARG\n"
          mostrar_ajuda; exit 1   ;;

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

run "$@"
