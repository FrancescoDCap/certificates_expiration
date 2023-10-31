#!/bin/bash

file="domains.txt"

# Verifica se il file esiste
if [ ! -f "$file" ]; then
  echo "Il file $file non esiste."
  exit 1
fi

is_in_expire(){
        date_expire="$1"
        if [ "$date_expire" ]; then
                date_current=$(date +%F)
                # Converte le date in timestamp Unix
                timestamp1=$(date -d "$date_expire" +%s)
                timestamp2=$(date -d "$date_current" +%s)
                timestamp3=$((timestamp2 + (20 * 86000)))

                # Confronta la differenza con 20 giorni
                if [ "$timestamp1" -gt "$timestamp3" ]; then
                        echo "OK"
                elif [ "$timestamp1" -le "$timestamp2" ]; then
                        echo "EXPIRED"
                else
                        echo "EXPIRING"
                fi
        else
                echo "NOT_AVAILABLE"
        fi

}

split_string(){
        string="$1"

        IFS='_' read -r -a array <<< "$string"

        # Ora l'array "parti" contiene le parti separate
        # Puoi accedere a ciascuna parte come "${parti[0]}", "${parti[1]}", ecc.
        echo "${array[1]}"

}

#creo il metodo get_expire_date e gli passo il parametro domain
get_expire_date(){
        domain="$1"

        # Esegui il comando openssl s_client per ottenere il certificato SSL
        output=$(openssl s_client -connect "$domain:443" < /dev/null 2>&1)

        # Estrai la data di scadenza (notAfter) dall'output
        data_scadenza=$(echo "$output" | openssl x509 -noout -dates | grep "notAfter" | awk '{print $1, $2, $4}'  | sed 's/notAfter=//')

        # Usa awk per eseguire il parsing e formattare la data
        expire_date=$(perl -MTime::Piece -E '$d = Time::Piece->strptime($ARGV[0], "%b %d %Y"); say $d->strftime("%Y-%m-%d")' "$data_scadenza")

        echo "$expire_date"
}

declare -A object_array

# Legge il file riga per riga
while IFS= read -r line; do

        expire_date=$(get_expire_date $line)
        nome=$(echo "$line")
        object_array["$nome"]=$expire_date

done < "$file"

# Ordina l'array in base alle date
sorted_keys=($(
  for nome in "${!object_array[@]}"
  do
    echo "${object_array[$nome]}_$nome"
  done | sort -k2,2
))

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

printf "%-30s %-15s %-15s\n" "DOMAIN" "DUE DATE" "STATUS"

# Stampa l'array ordinato
for nome in "${sorted_keys[@]}"
do
        domain=$(split_string $nome)
        alert=$(is_in_expire ${object_array[$domain]})
        if [ "$alert" == "EXPIRED" ]; then
                COLOR=$RED
        elif [ "$alert" == "EXPIRING" ]; then
                COLOR=$YELLOW
        else
                COLOR=$GREEN
        fi

        printf "${COLOR}%-30s %-15s %-15s\n${NC}" $domain ${object_array[$domain]} $alert
done