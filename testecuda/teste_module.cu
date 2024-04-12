
#include <stdint.h>
#include <stdio.h>
#include <dlfcn.h>
typedef float (*func)(float);

int main()
{

printf("inicio.\n");
 void * m_handle = dlopen("module.so", RTLD_NOW);
  if(m_handle== NULL)  
      { char message[200];
        strcpy(message,"Error opening dll!! ");
      }


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

void (*launch)();
launch= (void(*)())dlsym( m_handle, "launch");
printf("ok.\n");
if (launch==NULL) {printf("NULL\n");}
(*launch)();

}