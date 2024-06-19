
import time
import psutil
import rrdtool
import os

def create_rrd_database(rrd_path):
    if not os.path.exists(rrd_path):
        rrdtool.create(
            rrd_path,
            "--step", "1",
            "DS:io:GAUGE:2:0:U",
            "RRA:AVERAGE:0.5:1:600",
            "RRA:AVERAGE:0.5:6:700",
            "RRA:AVERAGE:0.5:24:775",
            "RRA:AVERAGE:0.5:288:797"
        )

def update_rrd_database(rrd_path, usage):
    timestamp = int(time.time())
    rrdtool.update(rrd_path, f"{timestamp}:{usage}")

def generate_graph(rrd_path, png_path, start, end):
    rrdtool.graph(
        png_path,
        "--start", str(start),
        "--end", str(end),
        "--vertical-label=IO Usage (bytes)",
        "DEF:io_usage={}:io:AVERAGE".format(rrd_path),
        "LINE1:io_usage#FF0000:IO Usage"
    )

def stress_io(duration, file_size):
    end_time = time.time() + duration
    filename = "temp_io_test_file"
    io_usage = []

    with open(filename, 'wb') as f:
        data = os.urandom(1024)
        while time.time() < end_time:
            for _ in range(file_size // 1024):
                f.write(data)
            f.flush()
            os.fsync(f.fileno())
            io_usage.append(psutil.disk_io_counters().write_bytes)
            f.seek(0)

    os.remove(filename)
    return io_usage

def monitor_io_usage(duration):
    rrd_path = "io_usage.rrd"
    png_path = "io_usage.png"

    # Cria a base de dados RRD
    create_rrd_database(rrd_path)

    # Inicia o monitoramento do IO
    io_usage = []
    interval = 1  # Intervalo de tempo para coleta do uso do IO em segundos

    def monitor_io():
        while True:
            usage = psutil.disk_io_counters().write_bytes
            io_usage.append(usage)
            update_rrd_database(rrd_path, usage)
            time.sleep(interval)
            if len(io_usage) > 1 and time.time() >= end_time:  # Verifica se o teste terminou
                break

    import threading
    monitor_thread = threading.Thread(target=monitor_io)
    monitor_thread.start()

    # Estressa o IO
    duration = 60  # duração do teste em segundos
    file_size = 1024 * 1024 * 10  # tamanho do arquivo em bytes (10 MB)
    io_usage = stress_io(duration, file_size)

    # Aguarda o fim do monitoramento do IO
    monitor_thread.join()

    print(f"IO usage during test: {io_usage}")

    # Gera o gráfico
    end_time = int(time.time())
    start_time = end_time - len(io_usage)
    generate_graph(rrd_path, png_path, start_time, end_time)

    print(f"Graph generated at {png_path}")

    return io_usage

# Exemplo de uso:
monitor_io_usage(60)
