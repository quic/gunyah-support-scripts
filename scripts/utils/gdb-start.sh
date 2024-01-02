#!/bin/bash

# © 2022 Qualcomm Innovation Center, Inc. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause

gdb-multiarch -q \
    -ex 'set arch aarch64' \
    -ex 'set confirm off' \
    -ex 'target remote localhost:1234' \
    -ex 'add-symbol-file hyp/build/qemu/gunyah-rm-qemu/debug/hyp.elf 0xffffffd5ffe00000' \
    -ex 'directory ./hyp' \
    -ex 'break rootvm_init' \
    -ex 'add-symbol-file musl-c-runtime/build/runtime 0x80481000' \
    -ex 'directory ./musl-c-runtime' \
    -ex 'break sys_exit' \
    -ex 'add-symbol-file resource-manager/build/qemu/debug/resource-manager 0x804A0000' \
    -ex 'directory ./resource-manager' \
    -ex 'tui enable' \
    -ex 'layout src' \
    -ex 'layout regs' \
    -ex 'focus cmd' \
    -ex 'p/a &hyp_log_buffer' \
    -ex 'p/a (uint32_t*)((0x8049D000-0x12000+0x1000)+(uint64_t)(&rm_log_area))' \
    -ex 'break hlos_vm_create' \
    -ex 'break vm_dt_create_hlos' \
    -ex 'break memparcel_do_accept' \
    " "

#    -ex 'break soc_qemu_handle_rootvm_init' \
#    -ex 'break hypercall_msgqueue_send' \
#    -ex 'break _start' \
#    -ex 'break hyp_smc_handler' \
#    -ex 'break smccc_handle_vcpu_trap_hvc64'
#    -ex 'break smccc_handle_vcpu_trap_smc64' \
#    -ex 'break get_current_core_id' \
#    -ex 'break main' \
#

# For symbol loading address, refer to following console logs:
#    [HYP] runtime_ipa: 0x80480000
#    [HYP] app_ipa: 0x8048c000
#
#   For runtime: (Adjust the address above in the cmd line args)
#    Symbol load address = runtime_ipa + entry point in runtime elf file
#     Sym load Address: 0x80481000  =  0x80480000  +  0x1000
#
#
#   For resource-manager: (Adjust the address above in the cmd line args)
#    Symbol load address = app_ipa + entry point in resource-manager elf file
#    0x804A0000    =   0x8048c000 + 0x14000

#
# rm log buffer is located at $2 in the following msg on gdb terminal window using above p/a:
#   $1 = 0x20d6c1 <hyp_log_buffer>
#   $2 = 0x804e34f8
#  Here : p/a (uint32_t*)((0x8049D000-0x12000+0x1000)+(uint64_t)(&rm_log_area))'
#      0x8049D000 : Address where symbol is loaded
#         0x12000 : is Entrypoint address in resource-manager elf file
#          0x1000 : accounts for elf headers overhead
#
#  Above results into the location of rm_log_area variable, which holds pointer
#   of the memory where RM logs reside, that address can be used to dump logs in
#   monitor
#
#  Some useful breakpoints to consider:
#   Hyp (EL2) :
#	rootvm_init :
#	vcpu_thread_start :
#	platform_cpu_on :
#	smccc_handle_call :
#	*(vcpu_exception_return+0x58) : Transition to a new VM entry point
#	vcpu_exception_dispatch :
#
#   Runtime (EL1 Root VM) :
#	_start : Entry point of runtime
#	*(_start+0xb0) : Transition over to Resource manager (blr x0)
#
#   Resource-manager (EL1 Root VM) :
#	main :
#	hlos_vm_create :
#	platform_vm_create :
#	vm_memory_init :
#	vm_creation_msg_handler :
#
