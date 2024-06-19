import time
import psutil
import rrdtool
import os

def create_rrd_database(rrd_path):
    if not os.path.exists(rrd_path):
        rrdtool.create(
            rrd_path,
            "--step", "1",
            "DS:cpu:GAUGE:2:0:100",
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
        "--vertical-label=CPU Usage (%)",
        "DEF:cpu_usage={}:cpu:AVERAGE".format(rrd_path),
        "LINE1:cpu_usage#FF0000:CPU Usage"
    )

def calculate_primes(limit):
    start_time = time.time()
    primes = []
    sieve = [True] * (limit + 1)
    sieve[0] = sieve[1] = False

    for start in range(2, limit + 1):
        if sieve[start]:
            primes.append(start)
            for multiple in range(start * start, limit + 1, start):
                sieve[multiple] = False

    end_time = time.time()
    print(f"Calculated primes up to {limit} in {end_time - start_time:.2f} seconds.")

    # Imprimir os primeiros 10 números primos
    print("First 10 primes:", primes[:15])

    return primes

def stress_cpu_with_primes(limit):
    rrd_path = "cpu_usage.rrd"
    png_path = "cpu_usage.png"

    # Cria a base de dados RRD
    create_rrd_database(rrd_path)

    # Inicia o monitoramento da CPU
    cpu_usage = []
    interval = 1  # Intervalo de tempo para coleta do uso da CPU em segundos

    def monitor_cpu():
        while True:
            usage = psutil.cpu_percent(interval=interval)
            cpu_usage.append(usage)
            update_rrd_database(rrd_path, usage)
            if len(cpu_usage) > 1 and cpu_usage[-1] == 0:  # Verifica se o cálculo terminou
                break

    import threading
    monitor_thread = threading.Thread(target=monitor_cpu)
    monitor_thread.start()

    # Calcula os números primos
    primes = calculate_primes(limit)

    # Aguarda o fim do monitoramento da CPU
    monitor_thread.join()

    print(f"CPU usage during prime calculation: {cpu_usage}")

    # Gera o gráfico
    end_time = int(time.time())
    start_time = end_time - len(cpu_usage)
    generate_graph(rrd_path, png_path, start_time, end_time)

    print(f"Graph generated at {png_path}")

    return primes

# Exemplo de uso:
stress_cpu_with_primes(100000)













