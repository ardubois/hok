
#include <stdint.h>
#include <stdio.h>
#include <dlfcn.h>
typedef float (*func)(float);

int main()
{

 void * m_handle = dlopen("./module.so", RTLD_NOW);
  if (!m_handle) { 
   fprintf(stderr, "dlopen failure: %s\n", dlerror()); 
   exit (EXIT_FAILURE); }
char *errstr;
errstr = dlerror();
if (errstr != NULL)
printf ("A dynamic linking error occurred: (%s)\n", errstr);


func host_function_ptr;
func (*get_ptr)();
get_ptr = (func (*)())dlsym( m_handle, "get_ptr_five_times");
host_function_ptr = get_ptr();
printf("host function pointer main %p", host_function_ptr);


func host_function_ptr2;
func (*get_ptr2)();
get_ptr2 = (func (*)())dlsym( m_handle, "get_pointer");
host_function_ptr2 = get_ptr2();
printf("host function pointer main %p", host_function_ptr2);


/* void * m_handle2 = dlopen("./module.so", RTLD_NOW);
  if (!m_handle2) { 
   fprintf(stderr, "dlopen failure: %s\n", dlerror()); 
   exit (EXIT_FAILURE); }
//char *errstr;
errstr = dlerror();
if (errstr != NULL)
printf ("A dynamic linking error occurred: (%s)\n", errstr);

*/

void (*launch)(func,func);
launch= (void(*)(func,func))dlsym( m_handle, "launch");
printf("ok.\n");
if (launch==NULL) {printf("NULL\n");}
(*launch)(host_function_ptr,host_function_ptr2);

}