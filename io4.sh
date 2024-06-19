#!/bin/bash

# Nome do arquivo do banco de dados RRD
RRD_DB="io_stress_rrd.rrd"

# Verifica se o banco de dados RRD já existe; se não, cria
if [ ! -e "$RRD_DB" ]; then
    echo "Criando o banco de dados RRD $RRD_DB..."
    rrdtool create $RRD_DB \
        --start N --step 10 \
        DS:disk_io:GAUGE:100:0:U \
        RRA:AVERAGE:0.5:1:600
fi

# Função para atualizar o banco de dados RRD com dados de desempenho de I/O
update_rrd() {
    local timestamp=$(date +%s)
    local disk_io=$(iostat -d | grep sda | awk '{print $2}' | tr ',' '.')

    # Verifica se a variável está vazia e define um valor padrão se necessário
    disk_io=${disk_io:-0}

    rrdtool update $RRD_DB $timestamp:$disk_io
}

# Função para gerar o gráfico a partir do banco de dados RRD
generate_graph() {
    echo "Gerando gráfico a partir do banco de dados RRD..."
    rrdtool graph grafico_io.png \
        --start end-1h --end now \
        DEF:disk_io=$RRD_DB:disk_io:AVERAGE \
        LINE1:disk_io#0000FF:"I/O do Disco"

    echo "Gráfico gerado: grafico_io.png"
}

# Diretório onde os arquivos temporários serão criados
TMP_DIR="/tmp/io_stress_test"

# Verifica se o diretório temporário existe; se não, cria
mkdir -p $TMP_DIR

# Função para estressar o disco de I/O
io_stress_test() {
    local file_size=$1  # Tamanho do arquivo em MB
    local iterations=$2  # Número de iterações

    echo "Iniciando teste de estresse de I/O..."

    for (( i=1; i<=$iterations; i++ )); do
        echo "Iteração $i de $iterations"

        # Cria um arquivo temporário
        echo "Criando arquivo temporário..."
        dd if=/dev/zero of=$TMP_DIR/file_$i bs=1M count=$file_size status=none

        # Lê o arquivo
        echo "Lendo arquivo temporário..."
        cat $TMP_DIR/file_$i > /dev/null

        # Apaga o arquivo temporário
        echo "Apagando arquivo temporário..."
        rm $TMP_DIR/file_$i

        # Atualiza o RRD com os dados de desempenho de I/O
        update_rrd

        sleep 10  # Intervalo de atualização do RRD (em segundos)
    done

    echo "Teste de estresse de I/O concluído."
}

# Executa o teste de estresse de I/O
io_stress_test 100 10  # Exemplo: cria arquivos de 100MB em 10 iterações

# Remove o diretório temporário ao finalizar
rm -rf $TMP_DIR

# Gera o gráfico
generate_graph

echo "Script concluído."
