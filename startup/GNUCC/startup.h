/*******************************************************************************
@file     startup.h
@author   Rajmund Szymanski
@date     24.10.2016
@brief    Startup file header for gcc compiler.
*******************************************************************************/

#pragma once

/*******************************************************************************
 Configuration of stacks
*******************************************************************************/

#if     main_stack_size > 0
char  __main_stack[main_stack] __attribute__ ((used, section(".main_stack")));
#endif

#if     proc_stack_size > 0
char  __proc_stack[proc_stack] __attribute__ ((used, section(".proc_stack")));
#endif

/*******************************************************************************
 Prototypes of external functions
*******************************************************************************/

#ifndef USE_CRT

int main( void );

#else //USE_CRT

void hardware_init_hook( void ) __attribute__ ((weak));
void software_init_hook( void ) __attribute__ ((weak));
void             _start( void ) __attribute__ ((noreturn));

#endif//USE_CRT

/*******************************************************************************
 Symbols defined in linker script
*******************************************************************************/

extern unsigned  __data_init_start[];
extern unsigned       __data_start[];
extern unsigned       __data_end  [];
extern unsigned       __data_size [];
extern unsigned        __bss_start[];
extern unsigned        __bss_end  [];
extern unsigned        __bss_size [];

extern void(*__preinit_array_start[])();
extern void(*__preinit_array_end  [])();
extern void(*   __init_array_start[])();
extern void(*   __init_array_end  [])();
extern void(*   __fini_array_start[])();
extern void(*   __fini_array_end  [])();

/*******************************************************************************
 Default reset procedures
*******************************************************************************/

static inline
void __startup_memcpy( unsigned *dst_, unsigned *end_, unsigned *src_ )
{
	while (dst_ < end_) *dst_++ = *src_++;
}

static inline
void __startup_memset( unsigned *dst_, unsigned *end_, unsigned val_ )
{
	while (dst_ < end_) *dst_++ = val_;
}

static inline
void __startup_data_init( void )
{
	/* Initialize the data segment */
	__startup_memcpy(__data_start, __data_end, __data_init_start);
	/* Zero fill the bss segment */
	__startup_memset(__bss_start, __bss_end, 0);
}

#ifndef USE_CRT

#ifndef __NOSTARTFILES

void __libc_init_array( void );
void __libc_fini_array( void );

#else //__NOSTARTFILES

static inline
void __startup_call_array( void(**dst_)(), void(**end_)() )
{
	while (dst_ < end_)(*dst_++)();
}

static inline
void __libc_init_array( void )
{
//	__startup_call_array(__preinit_array_start, __preinit_array_end);
	__startup_call_array(__init_array_start, __init_array_end);
}

static inline
void __libc_fini_array( void )
{
//	__startup_call_array(__fini_array_start, __fini_array_end);
}

#endif//__NOSTARTFILES

static inline __attribute__ ((noreturn))
void _start( void )
{
	/* Call global & static constructors */
	__libc_init_array();
	/* Call the application's entry point */
	main();
	/* Call global & static destructors */
	__libc_fini_array();
	/* Go into an infinite loop */
	for (;;);
}

#endif//USE_CRT

static inline __attribute__ ((noreturn))
void __main( void )
{
	/* Initialize data segments */
	__startup_data_init();
#ifdef USE_SEMIHOST
	void
	initialise_monitor_handles();
	initialise_monitor_handles();
#endif
	/* Call the application's entry point */
	_start();
}

/******************************************************************************/
