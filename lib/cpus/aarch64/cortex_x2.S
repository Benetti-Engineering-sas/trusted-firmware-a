/*
 * Copyright (c) 2021, Arm Limited. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#include <arch.h>
#include <asm_macros.S>
#include <common/bl_common.h>
#include <cortex_x2.h>
#include <cpu_macros.S>
#include <plat_macros.S>

/* Hardware handled coherency */
#if HW_ASSISTED_COHERENCY == 0
#error "Cortex X2 must be compiled with HW_ASSISTED_COHERENCY enabled"
#endif

/* 64-bit only core */
#if CTX_INCLUDE_AARCH32_REGS == 1
#error "Cortex X2 supports only AArch64. Compile with CTX_INCLUDE_AARCH32_REGS=0"
#endif

	/* --------------------------------------------------
	 * Errata Workaround for Cortex X2 Errata #2002765.
	 * This applies to revisions r0p0, r1p0, and r2p0 and
	 * is open.
	 * x0: variant[4:7] and revision[0:3] of current cpu.
	 * Shall clobber: x0, x1, x17
	 * --------------------------------------------------
	 */
func errata_cortex_x2_2002765_wa
	/* Check workaround compatibility. */
	mov	x17, x30
	bl	check_errata_2002765
	cbz	x0, 1f

	ldr	x0, =0x6
	msr	S3_6_C15_C8_0, x0 /* CPUPSELR_EL3 */
	ldr	x0, =0xF3A08002
	msr	S3_6_C15_C8_2, x0 /* CPUPOR_EL3 */
	ldr	x0, =0xFFF0F7FE
	msr	S3_6_C15_C8_3, x0 /* CPUPMR_EL3 */
	ldr	x0, =0x40000001003ff
	msr	S3_6_C15_C8_1, x0 /* CPUPCR_EL3 */
	isb

1:
	ret	x17
endfunc errata_cortex_x2_2002765_wa

func check_errata_2002765
	/* Applies to r0p0 - r2p0 */
	mov	x1, #0x20
	b	cpu_rev_var_ls
endfunc check_errata_2002765

	/* --------------------------------------------------
	 * Errata Workaround for Cortex X2 Errata #2058056.
	 * This applies to revisions r0p0, r1p0, and r2p0 and
	 * is open.
	 * x0: variant[4:7] and revision[0:3] of current cpu.
	 * Shall clobber: x0, x1, x17
	 * --------------------------------------------------
	 */
func errata_cortex_x2_2058056_wa
	/* Check workaround compatibility. */
	mov	x17, x30
	bl	check_errata_2058056
	cbz	x0, 1f

	mrs	x1, CORTEX_X2_CPUECTLR2_EL1
	mov	x0, #CORTEX_X2_CPUECTLR2_EL1_PF_MODE_CNSRV
	bfi	x1, x0, #CORTEX_X2_CPUECTLR2_EL1_PF_MODE_SHIFT, #CORTEX_X2_CPUECTLR2_EL1_PF_MODE_WIDTH
	msr	CORTEX_X2_CPUECTLR2_EL1, x1

1:
	ret	x17
endfunc errata_cortex_x2_2058056_wa

func check_errata_2058056
	/* Applies to r0p0 - r2p0 */
	mov	x1, #0x20
	b	cpu_rev_var_ls
endfunc check_errata_2058056

	/* --------------------------------------------------
	 * Errata Workaround for Cortex X2 Errata #2083908.
	 * This applies to revision r2p0 and is open.
	 * x0: variant[4:7] and revision[0:3] of current cpu.
	 * Shall clobber: x0-x2, x17
	 * --------------------------------------------------
	 */
func errata_cortex_x2_2083908_wa
	/* Check workaround compatibility. */
	mov	x17, x30
	bl	check_errata_2083908
	cbz	x0, 1f

	/* Apply the workaround by setting bit 13 in CPUACTLR5_EL1. */
	mrs	x1, CORTEX_X2_CPUACTLR5_EL1
	orr	x1, x1, #BIT(13)
	msr	CORTEX_X2_CPUACTLR5_EL1, x1

1:
	ret	x17
endfunc errata_cortex_x2_2083908_wa

func check_errata_2083908
	/* Applies to r2p0 */
	mov	x1, #0x20
	mov	x2, #0x20
	b	cpu_rev_var_range
endfunc check_errata_2083908

	/* ----------------------------------------------------
	 * HW will do the cache maintenance while powering down
	 * ----------------------------------------------------
	 */
func cortex_x2_core_pwr_dwn
	/* ---------------------------------------------------
	 * Enable CPU power down bit in power control register
	 * ---------------------------------------------------
	 */
	mrs	x0, CORTEX_X2_CPUPWRCTLR_EL1
	orr	x0, x0, #CORTEX_X2_CPUPWRCTLR_EL1_CORE_PWRDN_BIT
	msr	CORTEX_X2_CPUPWRCTLR_EL1, x0
	isb
	ret
endfunc cortex_x2_core_pwr_dwn

	/*
	 * Errata printing function for Cortex X2. Must follow AAPCS.
	 */
#if REPORT_ERRATA
func cortex_x2_errata_report
	stp	x8, x30, [sp, #-16]!

	bl	cpu_get_rev_var
	mov	x8, x0

	/*
	 * Report all errata. The revision-variant information is passed to
	 * checking functions of each errata.
	 */
	report_errata ERRATA_X2_2002765, cortex_x2, 2002765
	report_errata ERRATA_X2_2058056, cortex_x2, 2058056
	report_errata ERRATA_X2_2083908, cortex_x2, 2083908

	ldp	x8, x30, [sp], #16
	ret
endfunc cortex_x2_errata_report
#endif

func cortex_x2_reset_func
	mov	x19, x30

	/* Disable speculative loads */
	msr	SSBS, xzr
	isb

	/* Get the CPU revision and stash it in x18. */
	bl	cpu_get_rev_var
	mov	x18, x0

#if ERRATA_X2_2002765
	mov	x0, x18
	bl	errata_cortex_x2_2002765_wa
#endif

#if ERRATA_X2_2058056
	mov	x0, x18
	bl	errata_cortex_x2_2058056_wa
#endif

#if ERRATA_X2_2083908
	mov	x0, x18
	bl	errata_cortex_x2_2083908_wa
#endif

	ret x19
endfunc cortex_x2_reset_func

	/* ---------------------------------------------
	 * This function provides Cortex X2 specific
	 * register information for crash reporting.
	 * It needs to return with x6 pointing to
	 * a list of register names in ascii and
	 * x8 - x15 having values of registers to be
	 * reported.
	 * ---------------------------------------------
	 */
.section .rodata.cortex_x2_regs, "aS"
cortex_x2_regs:  /* The ascii list of register names to be reported */
	.asciz	"cpuectlr_el1", ""

func cortex_x2_cpu_reg_dump
	adr	x6, cortex_x2_regs
	mrs	x8, CORTEX_X2_CPUECTLR_EL1
	ret
endfunc cortex_x2_cpu_reg_dump

declare_cpu_ops cortex_x2, CORTEX_X2_MIDR, \
	cortex_x2_reset_func, \
	cortex_x2_core_pwr_dwn
