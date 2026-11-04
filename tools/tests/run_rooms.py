"""Builds the RoomService lifecycle test: injects the real source into room_stub.lua and runs it with luau."""
import os
import subprocess
import sys
import tempfile

root = os.path.dirname(os.path.abspath(__file__))
stub = open(os.path.join(root, "room_stub.lua")).read()
src = open(os.path.join(root, "../../src/serverstorage/Modules/Services/RoomService.lua")).read().replace("--!strict", "")
wrapped = "local function RoomServiceFactory()\n" + src + "\nend\n"
with tempfile.TemporaryDirectory() as folder:
    path = os.path.join(folder, "rooms.luau")
    open(path, "w").write(stub.replace("--ROOMSERVICE--", wrapped))
    sys.exit(subprocess.call(["luau", path]))
