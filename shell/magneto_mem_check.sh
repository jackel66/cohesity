#!/usr/bin/env python3
# Description: This script checks the memory usage of the Magneto process.
# Author : Doug Austin
# Date : 2023-10-04
# Usage: ./magneto_mem_check.py


#-- Needed Libraries ---
import subprocess
import os


process = subprocess.Popen(
    ["ps", "-ef"],
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
)

out, err = process.communicate()
out = out.decode("utf-8")

magneto_pid = None
magneto_name = None 

for line in out.split("\n"):
    if "bin/magneto_exec" in line and "cohesity" in line:
        magneto_pid = line.split()[1]
        magneto_name = line.split()[7]

if magneto_pid:
    process = subprocess.Popen(
        ["sudo", "pmap", magneto_pid],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )

    out, err = process.communicate()
    out = out.decode("utf-8")

    kb = out.split("\n")[-2].split()[1]
    mb = int(kb.rstrip("K")) // 1024

    filename = os.path.basename(magneto_name)
    magneto_exec = filename.split("_")[0]
    print("%s (%s): %d MB" % (magneto_exec, magneto_pid, mb))

else:
    print("Magneto process not found.")
