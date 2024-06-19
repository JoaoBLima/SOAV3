#!/bin/bash

# Nome do arquivo do banco de dados RRD
RRD_DB="meu_banco_rrd.rrd"

# Verifica se o banco de dados RRD já existe; se não, cria
if [ ! -e "$RRD_DB" ]; then
    echo "Criando o banco de dados RRD $RRD_DB..."
    rrdtool create $RRD_DB \
        --start N --step 10 \
        DS:cpu_load_1min:GAUGE:100:0:100 \
        DS:mem_usage:GAUGE:100:0:100 \
        DS:disk_io:GAUGE:100:0:U \
        RRA:AVERAGE:0.5:1:600
fi

# Função para atualizar o banco de dados RRD com dados de desempenho
update_rrd() {
    local timestamp=$(date +%s)
    local cpu_load=$(uptime | grep -o "load average:.*" | awk '{print $3}' | tr -d ',' | tr ',' '.')
    local mem_usage=$(free | grep Mem | awk '{print $3/$2 * 100}' | tr ',' '.')
    local disk_io=$(iostat -d | grep sda | awk '{print $2}' | tr ',' '.')

    # Verifica se as variáveis estão vazias e define um valor padrão se necessário
    cpu_load=${cpu_load:-0}
    mem_usage=${mem_usage:-0}
    disk_io=${disk_io:-0}

    rrdtool update $RRD_DB $timestamp:$cpu_load:$mem_usage:$disk_io
}

# Função para monitorar o desempenho usando psutil
monitor_performance() {
    while true; do
        local cpu_usage=$(python3 -c "import psutil; print(psutil.cpu_percent(interval=1))" | tr ',' '.')
        local mem_usage=$(python3 -c "import psutil; print(psutil.virtual_memory().percent)" | tr ',' '.')
        local disk_io=$(iostat -d | grep sda | awk '{print $2}' | tr ',' '.')

        # Verifica se as variáveis estão vazias e define um valor padrão se necessário
        cpu_usage=${cpu_usage:-0}
        mem_usage=${mem_usage:-0}
        disk_io=${disk_io:-0}

        echo "$(date '+%Y-%m-%d %H:%M:%S'), CPU: $cpu_usage%, Memória: $mem_usage%, Disco I/O: $disk_io" >> performance.log

        # Atualiza o RRD com os dados de desempenho
        update_rrd

        sleep 10  # Intervalo de atualização (em segundos)
    done
}

# Exibe o tempo de atividade atual do sistema
echo "Tempo de atividade atual:"
uptime

# Inicia a monitoração de desempenho em segundo plano
monitor_performance &

# Executa 64 estressores de CPU por 2 minutos e atualiza o RRD
echo "Executando 64 estressores de CPU por 2 minutos:"
sudo stress-ng --cpu 64 --timeout 2m --metrics-brief
update_rrd  # Atualiza o RRD após o teste de estresse

# Exibe o tempo de atividade novamente após o primeiro teste
echo "Tempo de atividade após o primeiro teste:"
uptime

# Executa 32 estressores de CPU com método FFT por 2 minutos e atualiza o RRD
echo "Executando 32 estressores de CPU com método FFT por 2 minutos:"
sudo stress-ng --cpu 32 --cpu-method fft --timeout 2m --metrics-brief
update_rrd  # Atualiza o RRD após o teste de estresse

# Exibe o tempo de atividade novamente após o segundo teste
echo "Tempo de atividade após o segundo teste:"
uptime

# Executa 64 estressores de memória virtual com 4GB por 2 minutos e atualiza o RRD
echo "Executando 64 estressores de memória virtual (4GB) por 2 minutos:"
sudo stress-ng --vm 64 --vm-bytes 4G --timeout 2m --metrics-brief
update_rrd  # Atualiza o RRD após o teste de estresse de memória

# Exibe o tempo de atividade novamente após o terceiro teste
echo "Tempo de atividade após o terceiro teste:"
uptime

# Executa 128 estressores de CPU e 64 estressores de memória virtual com 4GB por 2 minutos e atualiza o RRD
echo "Executando 128 estressores de CPU e 64 estressores de memória virtual (4GB) por 2 minutos:"
sudo stress-ng --cpu 128 --vm 64 --vm-bytes 4G --timeout 2m --metrics-brief
update_rrd  # Atualiza o RRD após o teste de estresse

# Exibe o tempo de atividade novamente após o quarto teste
echo "Tempo de atividade após o quarto teste:"
uptime

# Aguarda a monitoração de desempenho para finalizar
echo "Aguardando finalização da monitoração de desempenho..."
sleep 10  # Tempo para garantir que a monitoração finalize

# Gerar gráfico a partir do banco de dados RRD
echo "Gerando gráfico a partir do banco de dados RRD..."
rrdtool graph grafico.png \
    --start end-1h --end now \
    DEF:cpu_load=$RRD_DB:cpu_load_1min:AVERAGE \
    DEF:mem_usage=$RRD_DB:mem_usage:AVERAGE \
    DEF:disk_io=$RRD_DB:disk_io:AVERAGE \
    LINE1:cpu_load#FF0000:"Carga da CPU (1 min)" \
    LINE1:mem_usage#00FF00:"Uso de Memória" \
    LINE1:disk_io#0000FF:"I/O do Disco"

echo "Gráfico gerado: grafico.png"

# Fim do script
echo "Script concluído."
