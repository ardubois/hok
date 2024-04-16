
#include <stdint.h>
#include <stdio.h>
#include <dlfcn.h>
typedef float (*func)(float);

int main()
{

printf("inicio.\n");
 void * m_handle = dlopen("./module2.so", RTLD_NOW);
  if (!m_handle) { 
   fprintf(stderr, "dlopen failure: %s\n", dlerror()); 
   exit (EXIT_FAILURE); }


printf("m handle %p\n",m_handle);
char *errstr;


errstr = dlerror();
if (errstr != NULL)
printf ("A dynamic linking error occurred: (%s)\n", errstr);
//func (*fun)();
//fun= (func(*)())dlsym( m_handle, "inc_ptr");

//printf("ok1!\n");
//func pointer = fun();

//printf("ok2!\n");
func host_function_ptr;

func (*get_ptr)();

get_ptr = (func (*)())dlsym( m_handle, "get_pointer");

host_function_ptr = get_ptr();

printf("host function pointer main %p", host_function_ptr);

void (*launch)();
launch= (void(*)(fun))dlsym( m_handle, "launch");
printf("ok.\n");
if (launch==NULL) {printf("NULL\n");}
(*launch)(host_function_ptr);

}