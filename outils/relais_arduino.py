#!/usr/bin/env python3
# Relais manette Arduino <-> Godot (macOS / Linux).
# Ouvre le port série de la carte (ce que GdSerial ne fait pas de façon fiable sur ce Mac)
# et transmet les octets au jeu par TCP local, via le mode "simulateur" (serial_tcp_simu.gd).
# Usage : python3 outils/relais_arduino.py [port]   puis lancer le jeu avec ARDUINO_PORT=tcp://127.0.0.1:5555
import glob, os, select, socket, sys, termios, time, tty

HOTE, PORT_TCP = "127.0.0.1", 5555

def trouver_port():
    if len(sys.argv) > 1:
        return sys.argv[1]
    for motif in ("/dev/cu.usbmodem*", "/dev/cu.usbserial*", "/dev/cu.wchusbserial*"):
        ports = sorted(glob.glob(motif))
        if ports:
            return ports[0]
    sys.exit("Aucune carte Arduino trouvée : branche-la, ou donne le port en argument.")

def ouvrir_serie(chemin):
    fd = os.open(chemin, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
    tty.setraw(fd)
    a = termios.tcgetattr(fd)
    a[2] |= termios.CLOCAL | termios.CREAD
    a[4] = a[5] = termios.B115200
    termios.tcsetattr(fd, termios.TCSANOW, a)
    return fd

def main():
    chemin = trouver_port()
    fd = ouvrir_serie(chemin)
    print(f"Carte ouverte : {chemin}. Ne touche pas au joystick pendant 2 secondes...")
    time.sleep(2)  # la carte redémarre à l'ouverture du port et mesure le centre du joystick

    serveur = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    serveur.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    serveur.bind((HOTE, PORT_TCP))
    serveur.listen(1)
    print(f"Relais prêt sur tcp://{HOTE}:{PORT_TCP}. Lance le jeu. (Ctrl+C pour arrêter)")

    client = None
    try:
        while True:
            entrees = [fd, serveur] + ([client] if client else [])
            prets, _, _ = select.select(entrees, [], [], 0.5)

            if serveur in prets:
                nouveau, _ = serveur.accept()
                if client:
                    client.close()
                client = nouveau
                print("Jeu connecté au relais.")

            if fd in prets:
                try:
                    donnees = os.read(fd, 4096)
                except BlockingIOError:
                    donnees = None
                except OSError:
                    print("La carte a été débranchée.")
                    break
                if donnees == b"":
                    print("La carte a été débranchée.")
                    break
                if donnees and client:
                    try:
                        client.sendall(donnees)
                    except OSError:
                        client.close()
                        client = None
                        print("Jeu déconnecté.")

            if client and client in prets:
                try:
                    donnees = client.recv(4096)
                except OSError:
                    donnees = b""
                if donnees:
                    os.write(fd, donnees)
                else:
                    client.close()
                    client = None
                    print("Jeu déconnecté.")
    except KeyboardInterrupt:
        print("\nArrêt du relais.")
    finally:
        if client:
            client.close()
        serveur.close()
        os.close(fd)

main()