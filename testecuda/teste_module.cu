
#include <stdint.h>
#include <stdio.h>
#include <dlfcn.h>
typedef float (*func)(float);

main()
{

 void * m_handle = dlopen("module.so", RTLD_NOW);
  if(m_handle== NULL)  
      { char message[200];
        strcpy(message,"Error opening dll!! ");
      }



func (*fun)();
fun= (func(*)())dlsym( m_handle, "inc_ptr");

func pointer = fun();

void (*launch)(func);
launch= (void(*)(func))dlsym( m_handle, "launch");

launch(pointer);

}