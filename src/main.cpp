typedef void (* fun_t)( void );

static const fun_t fun = []
{
	for (;;);
};

int main( void )
{
	fun();
}
