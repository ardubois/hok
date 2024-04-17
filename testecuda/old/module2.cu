#include <stdio.h>

#define gpuErrchk(val) \
    cudaErrorCheck(val, __FILE__, __LINE__, true)
void cudaErrorCheck(cudaError_t err, char* file, int line, bool abort)
{
    if(err != cudaSuccess)
    {
        printf("%s %s %d\n", cudaGetErrorString(err), file, line);
        if(abort) exit(-1);
    }
}

typedef float (*pfunc)(float arg);

__device__ float dev_func(float arg) {
    return arg * arg;
}

// create device function pointer here
__device__ pfunc dev_func_ptr = dev_func;

__global__ void ker_func(pfunc fnc) {
    // call function through device function pointer
    printf("%f\n", fnc(2));
}

extern "C" pfunc get_pointer()
{
    pfunc host_function_ptr;
    // copy function pointer value from device to host
    gpuErrchk(cudaMemcpyFromSymbol(&host_function_ptr, dev_func_ptr, sizeof(pfunc)));
    return host_function_ptr;
   
}


extern "C" void launch(pfunc myptr)
{
    // create a host function pointer
 //   pfunc host_function_ptr;
    // copy function pointer value from device to host
   // gpuErrchk(cudaMemcpyFromSymbol(&host_function_ptr, dev_func_ptr, sizeof(pfunc)));
    // pass the copied function pointer in kernel
   // printf("my pointer %p\n", myptr);
   // printf("pointeiro %p\n", host_function_ptr);

    ker_func<<<1,1>>>(myptr);

    gpuErrchk(cudaPeekAtLastError());
    gpuErrchk(cudaDeviceSynchronize());

 
}