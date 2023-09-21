
## Debugging with QEMU and Gunyah hypervisor

Gunyah hypervisor can be debugged using either gdb-multiarch or other debug
software such as VSCode. Helpful initial scripts are provided to get started.

### Disable ASLR

The Gunyah Hypervisor standard build enables ASLR by default, and while it can
be debugged with ASLR enabled, it is easier to debug with it disabled.

With ASLR disabled, the EL2 virtual addresses used will be constant across
multiple runs, simplifying symbol relocation.

For example, the debug configuration of Gunyah defaults with ASLR enabled, it
can be disabled by un-commenting the line ```#include include/debug_no_kaslr```
in ```<share>/hyp/config/quality/debug.conf```.

E.g. change the config to:
```
include include/debug_no_kaslr
```

Re-build the hypervisor with ```build-gunyah.sh``` as per instructions above.

### The Gunyah trace buffer

It is possible to extract and decode the Gunyah trace buffer.

- In QEMU, stop the target. E.g. ```CTRL-A + c``` to enter the monitor.
- Find the symbol address in ```hyp.elf```
    + ```000000000020d190 l     O .bss   0000000000000008 trace_buffer_global```
- Make sure the current vcpu is in EL2.
    + QEMU cmd ```info registers``` - will show the current EL.
    + There is no reliable way to stop in EL2. You can try ```cont``` followed by ```stop```.
    + Or, you can try find the physical address of the buffer, and use ```pmemsave``` instead,
    + When stopped in EL2, check the PC address, and calulate the ```trace_buffer_global``` address.l
    + E.g. PC ```0xffffffd5ffe102c4```
        + Set bottom 20-bits to zero => ```0xffffffd5ffe00000```
        + Add trace_buffer_global symbol address (e.g. ``0x20d190``))=> ```0xffffffd60000d190```
        + Read the pointer: ```x /1gx 0xffffffd60000d190```. Substitute the address into memsave below.
        + Save the trace: ```memsave 0xffffffd3f6100000 33554432 trace.bin```
	+ Exit QEMU, or from another docker shell:
        + ```~/share/hyp/tools/debug/tracebuf.py --elf ~/share/hyp/build/qemu/gunyah-rm-qemu/debug/hyp.elf -o trace.txt trace.bin```

### Debug using gdb

We need two terminals for debugging with gdb.

In the Docker container shell, launch qemu with debug:

```bash
cd ~/tools/qemu
./run-qemu.sh dbg
```

Start a second shell in another host terminal and attach to the running container.

In the second terminal, run:
```bash
cd ~/gunyah/gunyah-support-scripts/scripts
./new-term.sh
```

Connect to gdb from the second Docker shell:
```bash
cd ~/share
~/utils/gdb-start.sh
```

Expected output::
```bash
(gunyah-venv) nemo@hyp-dev-env:~/share/$ ~/utils/gdb-start.sh
The target architecture is assumed to be aarch64
Remote debugging using localhost:1234
warning: No executable has been specified and target does not support
determining executable automatically.  Try using the "file" command.
0x0000000080000000 in ?? ()
add symbol table from file "hyp/build/qemu/gunyah-rm-qemu/debug/hyp.elf" at
        .text_addr = 0xffffffd5ffe00000
...
Breakpoint 4 at 0x80482a80: file src/exit.c, line 39.
add symbol table from file "resource-manager/build/qemu/debug/resource-manager" at
        .text_addr = 0x804A0000
Reading symbols from resource-manager/build/qemu/debug/resource-manager...
(gdb) continue

```

At this point, either ```run``` to continue, or place additional breakpoints.

Note: A GUI or ```tui``` frontend can be used for better debugging experience,
but it can affect the stability of the tool.

---

## Early Linux kernel debugging

The ```vmlinux``` elf file from the Linux build can be used for debugging
symbols if required.

---
