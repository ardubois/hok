#include <stdio.h>
#include <time.h>



__device__ static float atomic_cas(float* address, float oldv, float newv)
{
    int* address_as_i = (int*) address;
    return  __int_as_float(atomicCAS(address_as_i, __float_as_int(oldv), __float_as_int(newv)));
}



__global__
void map_2kernel(float *a1, float *a2, float *a3, int size, float (*f)(float,float))
{
int id = ((blockIdx.x * blockDim.x) + threadIdx.x);
if((id < size))
{
        a3[id] = f(a1[id], a2[id]);
}

}

__global__
void reduce_kernel(float *a, float *ref4, float (*f)(float,float), int n)
{
__shared__ float cache[256];
        int tid = (threadIdx.x + (blockIdx.x * blockDim.x));
        int cacheIndex = threadIdx.x;
        float temp = 0.0;
while((tid < n)){
        temp = f(a[tid], temp);
        tid = ((blockDim.x * gridDim.x) + tid);
}
        cache[cacheIndex] = temp;
__syncthreads();
        int i = (blockDim.x / 2);
while((i != 0)){
if((cacheIndex < i))
{
        cache[cacheIndex] = f(cache[(cacheIndex + i)], cache[cacheIndex]);
}

__syncthreads();
        i = (i / 2);
}
if((cacheIndex == 0))
{
        float current_value = ref4[0];
while((! (current_value == atomic_cas(ref4, current_value, f(cache[0], current_value))))){
        current_value = ref4[0];
}
}

}

//#############################


__device__
float anonymous_mult(float a, float b)
{
return ((a * b));
}

__device__ void* anonymous_mult_ptr = (void*) anonymous_mult;

extern "C" void* get_anonymous_mult_ptr()
{
        void* host_function_ptr;
        cudaMemcpyFromSymbol(&host_function_ptr, anonymous_mult_ptr, sizeof(void*));
        return host_function_ptr;
}


//#############################


__device__
float anonymous_sum(float a, float b)
{
return ((a + b));
}

__device__ void* anonymous_sum_ptr = (void*) anonymous_sum;

extern "C" void* get_anonymous_sum_ptr()
{
        void* host_function_ptr;
        cudaMemcpyFromSymbol(&host_function_ptr, anonymous_sum_ptr, sizeof(void*));
        return host_function_ptr;
}




int main(int argc, char *argv[])
{

    float *a, *b, *resp;
	float *dev_a, *dev_b, *dev_resp;
    cudaError_t j_error;

    int N = atoi(argv[1]);

    a = (float*)malloc(N*sizeof(float));
    b = (float*)malloc(N*sizeof(float));
    resp = (float*)malloc(N*sizeof(float));

    for(int i=0; i<N; i++) {
		a[i] = rand();
		
	}

    for(int i=0; i<N; i++) {
		b[i] = rand();
		
	}

    int threadsPerBlock = 256;
    int  numberOfBlocks = (N + threadsPerBlock - 1)/ threadsPerBlock;

    float time;
    cudaEvent_t start, stop;   
    cudaEventCreate(&start) ;
    cudaEventCreate(&stop) ;
    cudaEventRecord(start, 0) ;


	cudaMalloc((void**)&dev_a, N*sizeof(float));
    j_error = cudaGetLastError();
    if(j_error != cudaSuccess) {printf("Error: %s\n", cudaGetErrorString(j_error)); exit(1);}
	cudaMalloc((void**)&dev_b, N*sizeof(float));
    j_error = cudaGetLastError();
    if(j_error != cudaSuccess) {printf("Error: %s\n", cudaGetErrorString(j_error)); exit(1);}
	cudaMalloc((void**)&dev_resp, N*sizeof(float));
    j_error = cudaGetLastError();
    if(j_error != cudaSuccess) {printf("Error: %s\n", cudaGetErrorString(j_error)); exit(1);}
	cudaMemcpy(dev_a, a, N*sizeof(float), cudaMemcpyHostToDevice);
     j_error = cudaGetLastError();
    if(j_error != cudaSuccess) {printf("Error: %s\n", cudaGetErrorString(j_error)); exit(1);}
    cudaMemcpy(dev_b, b, N*sizeof(float), cudaMemcpyHostToDevice);
     j_error = cudaGetLastError();
    if(j_error != cudaSuccess) {printf("Error: %s\n", cudaGetErrorString(j_error)); exit(1);}

    float (*f1)(float,float) = (float (*)(float,float)) get_anonymous_mult_ptr();
    float (*f2)(float,float) = (float (*)(float,float)) get_anonymous_sum_ptr();

    float *final, *d_final;
    final = (float *)malloc(sizeof(float));
	cudaMalloc((void **) &d_final,sizeof(float));

    map_2kernel<<< numberOfBlocks, threadsPerBlock>>>(dev_a, dev_b, dev_resp, N, f1);
     j_error = cudaGetLastError();
    if(j_error != cudaSuccess) {printf("Error: %s\n", cudaGetErrorString(j_error)); exit(1);}

    reduce_kernel<<< numberOfBlocks, threadsPerBlock>>>(dev_resp, d_final, f2, N);
    j_error = cudaGetLastError();
    if(j_error != cudaSuccess) {printf("Error: %s\n", cudaGetErrorString(j_error)); exit(1);}

     cudaMemcpy( final, d_final, sizeof(float), cudaMemcpyDeviceToHost );
     j_error = cudaGetLastError();
    if(j_error != cudaSuccess) {printf("Error: %s\n", cudaGetErrorString(j_error)); exit(1);}

    
    cudaFree(dev_a);
	cudaFree(dev_b);
    cudaFree(dev_resp);
    cudaFree(d_final);
    
	cudaEventRecord(stop, 0) ;
    cudaEventSynchronize(stop) ;
    cudaEventElapsedTime(&time, start, stop) ;

    printf("CUDA\t%d\t%3.1f\n", N,time);

/*
    for(int i=0; i<10; i++) {
		printf("resp[%d] = %f;\n",i,resp[i]);
	}

*/
	//printf("\n FINAL RESULTADO: %f \n", c);

	free(a);
    free(b);
	free(resp);
    free(final);

}
