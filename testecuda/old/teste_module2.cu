
#include <stdint.h>
#include <stdio.h>
#include <dlfcn.h>
typedef float (*func)(float);

int main()
{

 void * m_handle = dlopen("./module2.so", RTLD_NOW);
  if (!m_handle) { 
   fprintf(stderr, "dlopen failure: %s\n", dlerror()); 
   exit (EXIT_FAILURE); }
char *errstr;
errstr = dlerror();
if (errstr != NULL)
printf ("A dynamic linking error occurred: (%s)\n", errstr);


func host_function_ptr;
func (*get_ptr)();
get_ptr = (func (*)())dlsym( m_handle, "get_pointer");
host_function_ptr = get_ptr();
printf("host function pointer main %p", host_function_ptr);


 void * m_handle2 = dlopen("./module2.so", RTLD_NOW);
  if (!m_handle2) { 
   fprintf(stderr, "dlopen failure: %s\n", dlerror()); 
   exit (EXIT_FAILURE); }
//char *errstr;
errstr = dlerror();
if (errstr != NULL)
printf ("A dynamic linking error occurred: (%s)\n", errstr);



void (*launch)(func);
launch= (void(*)(func))dlsym( m_handle2, "launch");
printf("ok.\n");
if (launch==NULL) {printf("NULL\n");}
(*launch)(host_function_ptr);

}