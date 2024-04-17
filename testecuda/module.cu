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
__device__ void* dev_func_ptr = (void*) dev_func;

extern "C" void* get_pointer()
{
    void* host_function_ptr;
    // copy function pointer value from device to host
    gpuErrchk(cudaMemcpyFromSymbol(&host_function_ptr, dev_func_ptr, sizeof(void*)));
    return host_function_ptr;
   
}


__device__ float five_times(float arg) {
    return 5 * arg;
}

// create device function pointer here
__device__ void* five_times_ptr = (void*) five_times;

extern "C" void* get_ptr_five_times()
{
    void* host_function_ptr;
    // copy function pointer value from device to host
    gpuErrchk(cudaMemcpyFromSymbol(&host_function_ptr, five_times_ptr, sizeof(void*)));
    return host_function_ptr;
   
}


__global__ void ker_func(pfunc fnc,pfunc func2) {
    // call function through device function pointer
    printf("%f\n", func2(fnc(2)));
}


extern "C" void launch(pfunc myptr,pfunc myptr2)
{
    // create a host function pointer
 //   pfunc host_function_ptr;
    // copy function pointer value from device to host
   // gpuErrchk(cudaMemcpyFromSymbol(&host_function_ptr, dev_func_ptr, sizeof(pfunc)));
    // pass the copied function pointer in kernel
   // printf("my pointer %p\n", myptr);
   // printf("pointeiro %p\n", host_function_ptr);

    ker_func<<<1,1>>>(myptr,myptr2);

    gpuErrchk(cudaPeekAtLastError());
    gpuErrchk(cudaDeviceSynchronize());

 
}