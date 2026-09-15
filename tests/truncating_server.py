"""Serves a response that promises a large body and then hangs up partway.

That is what a connection dropping mid-download looks like to curl, which is
one of the cases the installer has to survive without leaving anything behind.

Usage: python3 truncating_server.py <port>
"""

import socket
import sys
import threading

HEADERS = b"HTTP/1.1 200 OK\r\nContent-Length: 1000000\r\n\r\n"
PARTIAL_BODY = b"x" * 512


def serve(conn):
    try:
        conn.recv(4096)
        conn.sendall(HEADERS + PARTIAL_BODY)
    except OSError:
        pass
    finally:
        conn.close()


def main():
    srv = socket.socket()
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(("127.0.0.1", int(sys.argv[1])))
    srv.listen(8)

    while True:
        try:
            conn, _ = srv.accept()
        except OSError:
            break
        threading.Thread(target=serve, args=(conn,), daemon=True).start()


if __name__ == "__main__":
    main()
