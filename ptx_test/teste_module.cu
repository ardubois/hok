
#include <stdint.h>
#include <stdio.h>
#include <dlfcn.h>
#include <cuda.h>
#include <builtin_types.h>

#define checkCudaErrors(err)  __checkCudaErrors (err, __FILE__, __LINE__)

inline void __checkCudaErrors( CUresult err, const char *file, const int line )
{
    if( CUDA_SUCCESS != err) {
        fprintf(stderr,
                "CUDA Driver API error = %04d from file <%s>, line %i.\n",
                err, file, line );
        exit(-1);
    }
}  


typedef float (*func)(float);

int main()
{

CUdevice   device;
CUcontext  context;
CUmodule   module;
CUfunction function;

CUresult err = cuInit(0);

checkCudaErrors(cuDeviceGet(&device, 0));

err = cuCtxCreate(&context, 0, device);
if (err != CUDA_SUCCESS) {
        fprintf(stderr, "* Error initializing the CUDA context.\n");
        cuCtxDetach(context);
        exit(-1);
}

err = cuModuleLoad(&module, "module.ptx");
if (err != CUDA_SUCCESS) {
        fprintf(stderr, "* Error loading the module %s\n", "module.ptx");
        cuCtxDetach(context);
        exit(-1);
}

err = cuModuleGetFunction(&function, module, "simple_kernel");

if (err != CUDA_SUCCESS) {
        fprintf(stderr, "* Error getting kernel function %s\n", "simple_kernel");
        cuCtxDetach(context);
        exit(-1);
}

checkCudaErrors( cuLaunchKernel(function, 1, 1, 1,  // Nx1x1 blocks
                                    1, 1, 1,            // 1x1x1 threads
                                    0, 0, {}, 0) );


}