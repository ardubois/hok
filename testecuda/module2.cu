#define gpuErrchk(val) \
    cudaErrorCheck(val, __FILE__, __LINE__, true)
    
typedef float (*pfunc)(float arg);

__device__ float five_times(float arg) {
    return 5 * arg;
}

// create device function pointer here
__device__ pfunc five_times_ptr = five_times;

extern "C" pfunc get_ptr_five_times()
{
    pfunc host_function_ptr;
    // copy function pointer value from device to host
    gpuErrchk(cudaMemcpyFromSymbol(&host_function_ptr, five_times_ptr, sizeof(pfunc)));
    return host_function_ptr;
   
}

