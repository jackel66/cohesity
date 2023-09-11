import subprocess

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

if magneto_pid:
    process = subprocess.Popen(
        ["sudo", "pmap", magneto_pid],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )

    out, err = process.communicate()
    out = out.decode("utf-8")

    kb = out.split("\n")[-2].split()[1]
    mb = int(kb) // 1024
    print("%s (%s): %d MB" % (magneto_name, magneto_pid, mb))

else:
    print("Magneto process not found.")