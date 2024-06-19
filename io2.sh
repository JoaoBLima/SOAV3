#!/bin/bash

# Nome do arquivo do banco de dados RRD
RRD_DB="meu_banco_rrd_io.rrd"

# Verifica se o banco de dados RRD já existe; se não, cria
if [ ! -e "$RRD_DB" ]; then
    echo "Criando o banco de dados RRD $RRD_DB..."
    rrdtool create $RRD_DB \
        --start N --step 10 \
        DS:disk_io:GAUGE:200:0:U \
        RRA:AVERAGE:0.5:1:900
fi

# Função para atualizar o banco de dados RRD com dados de desempenho
update_rrd() {
    local timestamp=$(date +%s)
    local disk_io=$(iostat -d | grep sda | awk '{print $2}' | tr ',' '.')

    # Verifica se a variável está vazia e define um valor padrão se necessário
    disk_io=${disk_io:-0}

    rrdtool update $RRD_DB $timestamp:$disk_io
}

# Função para monitorar o desempenho usando iostat
monitor_performance() {
    while true; do
        local disk_io=$(iostat -d | grep sda | awk '{print $2}' | tr ',' '.')

        # Verifica se a variável está vazia e define um valor padrão se necessário
        disk_io=${disk_io:-0}

        echo "$(date '+%Y-%m-%d %H:%M:%S'), Disco I/O: $disk_io" >> performance.log

        # Atualiza o RRD com os dados de desempenho
        update_rrd

        sleep 5  # Intervalo de atualização (em segundos)
    done
}

# Exibe o tempo de atividade atual do sistema
echo "Tempo de atividade atual:"
uptime

# Inicia a monitoração de desempenho em segundo plano
monitor_performance &

# Função para realizar o teste de estresse de I/O com carga gradualmente crescente e decrescente
run_io_stress_tests() {
    local total_duration=900  # 15 minutos em segundos
    local stages=5  # Número de estágios de estresse
    local stage_duration=$((total_duration / (2 * stages)))

    # Carga crescente de I/O
    for i in $(seq 1 $stages); do
        local io_load=$((i * 20))
        echo "Executando $io_load% de estresse de I/O por $stage_duration segundos:"
        sudo stress-ng --hdd $io_load --timeout ${stage_duration}s --metrics-brief
        update_rrd
    done

    # Carga decrescente de I/O
    for i in $(seq $stages -1 1); do
        local io_load=$((i * 20))
        echo "Executando $io_load% de estresse de I/O por $stage_duration segundos:"
        sudo stress-ng --hdd $io_load --timeout ${stage_duration}s --metrics-brief
        update_rrd
    done
}

# Executa os testes de estresse de I/O
run_io_stress_tests

# Exibe o tempo de atividade após o teste de estresse
echo "Tempo de atividade após o teste de estresse de I/O:"
uptime

# Aguarda a monitoração de desempenho para finalizar
echo "Aguardando finalização da monitoração de desempenho..."
sleep 10  # Tempo para garantir que a monitoração finalize

# Gerar gráfico a partir do banco de dados RRD
echo "Gerando gráfico de I/O a partir do banco de dados RRD..."
rrdtool graph grafico_io.png \
    --start end-1h --end now \
    DEF:disk_io=$RRD_DB:disk_io:AVERAGE \
    LINE1:disk_io#0000FF:"I/O do Disco"

echo "Gráfico gerado: grafico_io.png"

# Fim do script
echo "Script concluído."
