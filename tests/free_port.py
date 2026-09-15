"""Prints a free loopback port for the fixture servers to bind."""

import socket

s = socket.socket()
s.bind(("127.0.0.1", 0))
print(s.getsockname()[1])
s.close()
